#!/usr/bin/env bash
# _______________________________________________________________| locals |__ ;

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POMODORO_DIR="/tmp/pomodoro"

# File which records the start time of the Pomodoro
POMODORO_START_FILE="$POMODORO_DIR/pomodoro_start.txt"
# File which records what the user skipped
POMODORO_SKIP_FILE="$POMODORO_DIR/pomodoro_skip.txt"
# Files to track the time left for a Pomodoro/break and to check when a pause was initiated
POMODORO_PAUSED_FILE="$POMODORO_DIR/pomodoro_paused.txt"
POMODORO_RESUMED_FILE="$POMODORO_DIR/pomodoro_resumed.txt"
# File which records the start time of the current break
POMODORO_PROMPT_BREAK_FILE="$POMODORO_DIR/pomodoro_break_start.txt"
# File which tracks Pomodoro intervals
POMODORO_INTERVAL_FILE="$POMODORO_DIR/pomodoro_interval.txt"
# File which stores the current status of the Pomodoro/break
POMODORO_STATUS_FILE="$POMODORO_DIR/pomodoro_status.txt"

# File which stores the users custom Pomodoro time
POMODORO_USER_MINS_FILE="$CURRENT_DIR/user_mins.txt"
# File which stores the users custom break time
POMODORO_USER_BREAK_MINS_FILE="$CURRENT_DIR/user_break_mins.txt"

pomodoro_mins="@pomodoro_mins"
pomodoro_intervals="@pomodoro_intervals"
pomodoro_long_break="@pomodoro_long_break_mins"
pomodoro_break="@pomodoro_break_mins"
pomodoro_prompt="@pomodoro_prompt_me"

pomodoro_on="@pomodoro_on"
pomodoro_on_default=" 🍅"
pomodoro_pause="@pomodoro_pause"
pomodoro_pause_default=" ⏸︎"
pomodoro_complete="@pomodoro_complete"
pomodoro_complete_default=" ✔︎"
pomodoro_prompt_pomodoro="@pomodoro_prompt_pomodoro"
pomodoro_prompt_pomodoro_default=" ⏱︎ start?"
pomodoro_prompt_break="@pomodoro_prompt_break"
pomodoro_prompt_break_default=" ⏲︎ break?"
pomodoro_interval_display="@pomodoro_interval_display"

pomodoro_notifications="@pomodoro_notifications"
pomodoro_granularity="@pomodoro_granularity"
pomodoro_sound="@pomodoro_sound"

# ______________________________________________________________| methods |__ ;

source "$CURRENT_DIR/helpers.sh"

get_pomodoro_duration() {
	get_tmux_option "$pomodoro_mins" "25"
}

get_pomodoro_break() {
	get_tmux_option "$pomodoro_break" "5"
}

get_pomodoro_intervals() {
	get_tmux_option "$pomodoro_intervals" "4"
}

show_pomodoro_intervals() {
	get_tmux_option "$pomodoro_interval_display" "0"
}

get_pomodoro_long_break() {
	get_tmux_option "$pomodoro_long_break" "25"
}

get_pomodoro_prompt() {
	get_tmux_option "$pomodoro_prompt" "on"
}

get_seconds() {
	date +%s
}

get_notifications() {
	get_tmux_option "$pomodoro_notifications" "off"
}

get_pomodoro_granularity() {
	get_tmux_option "$pomodoro_granularity" "off"
}

get_sound() {
	get_tmux_option "$pomodoro_sound" "off"
}

format_seconds() {
	local total_seconds=$1
	local minutes=$((total_seconds / 60))
	local seconds=$((total_seconds % 60))

	if [ "$(get_pomodoro_granularity)" == 'on' ]; then
		# Pad minutes and seconds with zeros if necessary
		# Formats seconds to MM:SS format
		# Example 1: 0  sec => 00:00
		# Example 2: 59 sec => 00:59
		# Example 3: 60 sec => 01:00
		printf "%02d:%02d\n" $minutes $seconds
	else
		local minutes_rounded=$(((total_seconds + 59) / 60))
		# Shows minutes only
		# Example 1: 0  sec => 0m
		# Example 2: 59 sec => 1m
		# Example 3: 60 sec => 1m
		printf "%sm" "$((minutes_rounded))"
	fi
}

minutes_to_seconds() {
	local minutes=$1
	echo $((minutes * 60))
}

if_inside_tmux() {
	test -n "${TMUX}"
}

refresh_statusline() {
	if_inside_tmux && tmux refresh-client -S
}

send_notification() {
	if [ "$(get_notifications)" == 'on' ]; then
		local title=$1
		local message=$2
		sound=$(get_sound)
		export sound
		case "$OSTYPE" in
		linux* | *bsd*)
			notify-send -t 8000 "$title" "$message"
			if [[ "$sound" == "on" ]]; then
				beep -D 1500
			fi
			;;
		darwin*)
			if [[ "$sound" == "off" ]]; then
				osascript -e 'display notification "'"$message"'" with title "'"$title"'"'
			else
				osascript -e 'display notification "'"$message"'" with title "'"$title"'" sound name "'"$sound"'"'
			fi
			;;
		esac
	fi
}

clean_env() {
	remove_file "$POMODORO_SKIP_FILE"
	remove_file "$POMODORO_START_FILE"
	remove_file "$POMODORO_PAUSED_FILE"
	remove_file "$POMODORO_RESUMED_FILE"
	remove_file "$POMODORO_STATUS_FILE"
	remove_file "$POMODORO_PROMPT_BREAK_FILE"
}

set_status() {
	local message="$1"
	write_to_file "$message" "$POMODORO_STATUS_FILE"
}

read_status() {
	read_file "$POMODORO_STATUS_FILE"
}

intervals_reached() {
	interval_value=$(read_file "$POMODORO_INTERVAL_FILE")

	# If intervals meet the maximum value, delete interval file
	if [ "$interval_value" -eq "$(get_pomodoro_intervals)" ]; then
		return 0
	fi
	return 1
}

prompt_user() {
	if [ "$(get_pomodoro_prompt)" == "on" ]; then
		return 0
	fi
	return 1
}

is_being_prompted() {
	if [ "$(read_status)" == "waiting_break" ] || [ "$(read_status)" == "waiting_pomodoro" ]; then
		return 0
	fi
	return 1
}

skipped_pomodoro() {
	if [ "$(read_file "$POMODORO_SKIP_FILE")" == "pomodoro" ]; then
		return 0
	fi
	return 1
}
skipped_break() {
	if [ "$(read_file "$POMODORO_SKIP_FILE")" == "break" ]; then
		return 0
	fi
	return 1
}

break_length() {
	if intervals_reached; then
		minutes_to_seconds "$(get_pomodoro_long_break)"
	else
		minutes_to_seconds "$(get_pomodoro_break)"
	fi
}

show_intervals() {
	show_intervals="$(show_pomodoro_intervals)"
	if [ "$show_intervals" != "0" ]; then
		printf " $show_intervals" "$(read_file "$POMODORO_INTERVAL_FILE")" "$(get_pomodoro_intervals)"
	fi
}

pomodoro_toggle() {
	if [ "$(read_status)" == "waiting_break" ]; then
		write_to_file "$(get_seconds)" "$POMODORO_PROMPT_BREAK_FILE"
		set_status "initiating_break"
		refresh_statusline
		return 0
	fi

	if ! is_being_prompted && file_exists "$POMODORO_START_FILE" && ! file_exists "$POMODORO_PAUSED_FILE"; then
		pomodoro_pause
		refresh_statusline
		return 0
	fi

	if ! is_being_prompted && file_exists "$POMODORO_PAUSED_FILE"; then
		pomodoro_resume
		refresh_statusline
		return 0
	fi

	pomodoro_start
}

pomodoro_pause() {
	write_to_file "$(get_seconds)" "$POMODORO_PAUSED_FILE"
	send_notification "🍅 Pomodoro paused!" "Your Pomodoro has been paused"
}

pomodoro_paused() {
	if file_exists "$POMODORO_PAUSED_FILE"; then
		return 0
	fi
	return 1
}

pomodoro_resume() {
	# Keep a running total of the time paused for
	time_paused_for="$(($(get_seconds) - $(read_file "$POMODORO_PAUSED_FILE") + $(read_file "$POMODORO_RESUMED_FILE")))"
	write_to_file "$time_paused_for" "$POMODORO_RESUMED_FILE"

	remove_file "$POMODORO_PAUSED_FILE"
	send_notification "🍅 Pomodoro resuming!" "Your Pomodoro has resumed"
}

time_paused_for() {
	if file_exists "$POMODORO_RESUMED_FILE"; then
		read_file "$POMODORO_RESUMED_FILE"
	else
		echo "0"
	fi
}

remove_time_paused_file() {
	remove_file "$POMODORO_RESUMED_FILE"
}

log_intervals() {
	if [ "$(get_pomodoro_intervals)" != "0" ]; then
		if intervals_reached; then
			remove_file "$POMODORO_INTERVAL_FILE"
		fi

		if file_exists "$POMODORO_INTERVAL_FILE"; then
			increment=$(($(read_file "$POMODORO_INTERVAL_FILE") + 1))
			write_to_file "$increment" "$POMODORO_INTERVAL_FILE"
		else
			write_to_file "1" "$POMODORO_INTERVAL_FILE"
		fi
	fi
}

pomodoro_start() {
	clean_env
	mkdir -p $POMODORO_DIR
	write_to_file "$(get_seconds)" "$POMODORO_START_FILE"

	set_status "in_progress"
	log_intervals

	send_notification "🍅 Pomodoro started!" "Your Pomodoro is underway"
	refresh_statusline
	return 0
}

pomodoro_cancel() {
	local notification="$1"

	clean_env
	remove_file "$POMODORO_INTERVAL_FILE"

	if [ "$notification" = true ]; then
		send_notification "🍅 Pomodoro cancelled!" "Your Pomodoro has been cancelled"
	fi

	refresh_statusline
	return 0
}

pomodoro_skip() {
	pomodoro_status="$(read_status)"

	if [ "$pomodoro_status" = "in_progress" ]; then
		write_to_file "pomodoro" "$POMODORO_SKIP_FILE"
		refresh_statusline
		return 0
	fi

	if [ "$pomodoro_status" = "break" ] || [ "$pomodoro_status" = "long_break" ]; then
		write_to_file "break" "$POMODORO_SKIP_FILE"
		refresh_statusline
		return 0
	fi
}

pomodoro_custom() {
	tmux command-prompt \
		-I "$(get_pomodoro_duration), $(get_pomodoro_break)" \
		-p 'Pomodoro duration (mins):, Break duration (mins):' \
		"set -g @pomodoro_mins %1;
		 set -g @pomodoro_break_mins %2;
		 run-shell 'echo %1 > $POMODORO_USER_MINS_FILE';
		 run-shell 'echo %2 > $POMODORO_USER_BREAK_MINS_FILE'
		"
}

pomodoro_menu() {
	pomodoro_menu_position=$(get_tmux_option @pomodoro_menu_position "R")
	export pomodoro_menu_position

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Pomodoro " \
		"$(get_pomodoro_duration) minutes (default)" "" "set -g @pomodoro_mins $(get_pomodoro_duration)" \
		"" \
		"15 minutes" "" "set -g @pomodoro_mins 15; run-shell 'echo 15 > $POMODORO_USER_MINS_FILE'" \
		"20 minutes" "" "set -g @pomodoro_mins 20; run-shell 'echo 20 > $POMODORO_USER_MINS_FILE'" \
		"25 minutes" "" "set -g @pomodoro_mins 25; run-shell 'echo 25 > $POMODORO_USER_MINS_FILE'" \
		"30 minutes" "" "set -g @pomodoro_mins 30; run-shell 'echo 30 > $POMODORO_USER_MINS_FILE'" \
		"40 minutes" "" "set -g @pomodoro_mins 40; run-shell 'echo 40 > $POMODORO_USER_MINS_FILE'" \
		"50 minutes" "" "set -g @pomodoro_mins 50; run-shell 'echo 50 > $POMODORO_USER_MINS_FILE'"

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Break " \
		"" \
		"5 minutes" "" "set -g @pomodoro_break_mins 5 ; run-shell 'echo 5  > $POMODORO_USER_BREAK_MINS_FILE'" \
		"10 minutes" "" "set -g @pomodoro_break_mins 10; run-shell 'echo 10 > $POMODORO_USER_BREAK_MINS_FILE'" \
		"15 minutes" "" "set -g @pomodoro_break_mins 15; run-shell 'echo 15 > $POMODORO_USER_BREAK_MINS_FILE'" \
		"20 minutes" "" "set -g @pomodoro_break_mins 20; run-shell 'echo 20 > $POMODORO_USER_BREAK_MINS_FILE'" \
		"30 minutes" "" "set -g @pomodoro_break_mins 30; run-shell 'echo 30 > $POMODORO_USER_BREAK_MINS_FILE'"

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Start Pomodoro? " \
		"Yes" "" "run-shell '$CURRENT_DIR/pomodoro.sh start'" \
		"No" "" ""
}

pomodoro_status() {
	# ________________________________________________| set variables |__ ;

	current_time=$(get_seconds)
	pomodoro_status="$(read_status)"
	time_paused_for="$(time_paused_for)"
	pomodoro_start_time=$(read_file "$POMODORO_START_FILE")
	pomodoro_duration="$(minutes_to_seconds "$(get_pomodoro_duration)")"

	elapsed_time=$((current_time - pomodoro_start_time - time_paused_for))

	# _____________________________________________| statusline logic |__ ;

	# Don't display anything if the pomodoro isn't in progress
	if [ "$pomodoro_start_time" -eq 1 ]; then
		return 0
	fi

	if pomodoro_paused; then
		printf "%s" "$(get_tmux_option "$pomodoro_pause" "$pomodoro_pause_default")"
		show_intervals
		return
	fi

	# Display the waiting prompts to the user
	if [ "$pomodoro_status" == "waiting_pomodoro" ]; then
		printf "%s" "$(get_tmux_option "$pomodoro_prompt_pomodoro" "$pomodoro_prompt_pomodoro_default")"
		show_intervals
		return
	fi
	if [ "$pomodoro_status" == "waiting_break" ]; then
		printf "%s" "$(get_tmux_option "$pomodoro_prompt_break" "$pomodoro_prompt_break_default")"
		show_intervals
		return
	fi

	# Pomodoro in progress
	if [ "$pomodoro_status" == "in_progress" ] && [ $elapsed_time -lt "$pomodoro_duration" ]; then
		time_left="$((pomodoro_duration - elapsed_time))"
		printf "%s%s" "$(get_tmux_option "$pomodoro_on" "$pomodoro_on_default")" "$(format_seconds $time_left)"
	fi

	# Has the Pomodoro completed or been skipped?
	{ [ $elapsed_time -ge "$pomodoro_duration" ] || skipped_pomodoro; } && completed=true || completed=false

	# Pomodoro completed
	if [ "$completed" = true ] && [ "$pomodoro_status" == "in_progress" ]; then
		remove_time_paused_file

		# Pomodoro completed, notifying the user
		if ! prompt_user; then
			send_notification "🍅 Pomodoro completed!" "Starting the break"
		fi

		# Pomodoro completed, starting the prompt
		if prompt_user; then
			pomodoro_status="waiting_break"
			set_status "$pomodoro_status"
			send_notification "🍅 Pomodoro completed!" "Start the break?"
		fi
	fi

	# Pomodoro completed, waiting for the user to respond to the prompt
	if file_exists "$POMODORO_PROMPT_BREAK_FILE" && prompt_user; then
		break_start_time=$(read_file "$POMODORO_PROMPT_BREAK_FILE")
		elapsed_time=$((current_time - break_start_time - time_paused_for))
	fi

	# Pomodoro completed, starting the break
	if [ "$completed" = true ] && { [ "$pomodoro_status" == "in_progress" ] || [ "$pomodoro_status" == "initiating_break" ]; }; then
		pomodoro_status="break"

		if intervals_reached; then
			pomodoro_status="long_break"
		fi

		set_status "$pomodoro_status"
	fi

	# Break in progress
	if [ "$pomodoro_status" == "break" ] || [ "$pomodoro_status" == "long_break" ]; then
		break_time_left=$((-(elapsed_time - pomodoro_duration - $(break_length))))

		if prompt_user; then
			break_time_left=$((-(current_time - break_start_time - $(break_length) - time_paused_for)))
		fi

		break_time_left=$((break_time_left))
		printf "%s%s" "$(get_tmux_option "$pomodoro_complete" "$pomodoro_complete_default")" "$(format_seconds $break_time_left)"
	fi

	# Break in progress, might be complete
	if [ "$pomodoro_status" == "break" ] || [ "$pomodoro_status" == "long_break" ]; then
		{ [ "$elapsed_time" -ge $((pomodoro_duration + $(break_length))) ] || skipped_break; } && break_complete=true || break_complete=false

		if prompt_user; then
			{ [ $((current_time - break_start_time - time_paused_for)) -ge "$(break_length)" ] || skipped_break; } && break_complete=true || break_complete=false
		fi
	fi

	# Break complete
	if [ "$break_complete" = true ] && { [ "$pomodoro_status" == "break" ] || [ "$pomodoro_status" == "long_break" ] || [ "$pomodoro_status" == "break_complete" ]; }; then
		remove_time_paused_file
		pomodoro_status="break_complete"

		break_message="🍅 Break completed!"
		long_break_message="🍅 Long break completed!"
		standard_message="Starting the Pomodoro"
		prompt_message="Start the Pomodoro?"

		primary_message="$break_message"

		if intervals_reached; then
			primary_message="$long_break_message"
		fi

		if prompt_user; then
			send_notification "$primary_message" "$prompt_message"
			pomodoro_status="waiting_pomodoro"
		else
			send_notification "$primary_message" "$standard_message"
			pomodoro_start
		fi

		set_status "$pomodoro_status"
	fi

	# Display interval count last in the statusline
	show_intervals
}

main() {
	cmd=$1
	shift

	if [ "$cmd" = "toggle" ]; then
		pomodoro_toggle
	elif [ "$cmd" = "skip" ]; then
		pomodoro_skip
	elif [ "$cmd" = "cancel" ]; then
		pomodoro_cancel true
	elif [ "$cmd" = "menu" ]; then
		pomodoro_menu
	elif [ "$cmd" = "custom" ]; then
		pomodoro_custom
	else
		pomodoro_status
	fi
}

main "$@"
