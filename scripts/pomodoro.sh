#!/usr/bin/env bash
# _______________________________________________________________| locals |__ ;

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POMODORO_DIR="/tmp"

# file to track start time of the current pomodoro
POMODORO_START_FILE="$POMODORO_DIR/pomodoro_start.txt"
# file to track start time of the current break
POMODORO_PROMPT_BREAK_FILE="$POMODORO_DIR/pomodoro_break_start.txt"
# file to track pomodoro intervals
POMODORO_INTERVAL_FILE="$POMODORO_DIR/pomodoro_interval.txt"
# file to store the pomodoro status
POMODORO_STATUS_FILE="$POMODORO_DIR/pomodoro_status.txt"

# file to store the users custom pomodoro time
POMODORO_USER_MINS_FILE="$CURRENT_DIR/user_mins.txt"
# file to store the users custom break time
POMODORO_USER_BREAK_MINS_FILE="$CURRENT_DIR/user_break_mins.txt"

pomodoro_mins="@pomodoro_mins"
pomodoro_intervals="@pomodoro_intervals"
pomodoro_long_break="@pomodoro_long_break_mins"
pomodoro_break="@pomodoro_break_mins"
pomodoro_prompt="@pomodoro_prompt_me"

pomodoro_on="@pomodoro_on"
pomodoro_on_default=" 🍅"
pomodoro_complete="@pomodoro_complete"
pomodoro_complete_default=" ✅"
pomodoro_prompt_pomodoro="@pomodoro_prompt_pomodoro"
pomodoro_prompt_pomodoro_default=" 🕤 start?"
pomodoro_prompt_break="@pomodoro_prompt_break"
pomodoro_prompt_break_default=" 🕤 break?"
pomodoro_show_intervals="@pomodoro_show_intervals"

pomodoro_notifications="@pomodoro_notifications"
pomodoro_granularity="@pomodoro_granularity"
pomodoro_sound="@pomodoro_sound"

# ______________________________________________________________| methods |__ ;

source "$CURRENT_DIR/helpers.sh"

get_pomodoro_length() {
	get_tmux_option "$pomodoro_mins" "25"
}

get_pomodoro_break() {
	get_tmux_option "$pomodoro_break" "5"
}

get_pomodoro_intervals() {
	get_tmux_option "$pomodoro_intervals" "0"
}

show_pomodoro_intervals() {
	get_tmux_option "$pomodoro_show_intervals" "0"
}

get_pomodoro_long_break() {
	get_tmux_option "$pomodoro_long_break" "25"
}

get_pomodoro_prompt() {
	get_tmux_option "$pomodoro_prompt" "off"
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
	remove_file "$POMODORO_START_FILE"
	remove_file "$POMODORO_STATUS_FILE"
	remove_file "$POMODORO_PROMPT_BREAK_FILE"

	pomodoro_status=""
	export pomodoro_status
}

set_status() {
	local message="$1"
	write_to_file "$message" "$POMODORO_STATUS_FILE"

	pomodoro_status="$message"
	export pomodoro_status
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
		interval_value=$(read_file "$POMODORO_INTERVAL_FILE")
		formatted_str="${show_intervals/\{I\}/$interval_value}"
		formatted_str="${formatted_str/\{T\}/$(get_pomodoro_intervals)}"
		printf "%s " "$formatted_str"
	fi
}

pomodoro_toggle() {
	if [ "$(read_status)" == "waiting_break" ]; then
		write_to_file "$(get_seconds)" "$POMODORO_PROMPT_BREAK_FILE"
		set_status "initiating_break"
		if_inside_tmux && tmux refresh-client -S
		return 0
	fi

	if [ -f "$POMODORO_START_FILE" ] && [ "$(read_status)" != "waiting_pomodoro" ]; then
		pomodoro_cancel true
		return 0
	fi

	pomodoro_start
}

pomodoro_start() {
	clean_env
	mkdir -p $POMODORO_DIR
	write_to_file "$(get_seconds)" "$POMODORO_START_FILE"

	set_status "in_progress"

	# Log intervals
	if [ "$(get_pomodoro_intervals)" != "0" ]; then
		if intervals_reached; then
			remove_file "$POMODORO_INTERVAL_FILE"
		fi

		if file_exists "$POMODORO_INTERVAL_FILE"; then
			interval_value=$(($(read_file "$POMODORO_INTERVAL_FILE") + 1))
			write_to_file "$interval_value" "$POMODORO_INTERVAL_FILE"
		else
			write_to_file "1" "$POMODORO_INTERVAL_FILE"
		fi
	fi

	send_notification "🍅 Pomodoro started!" "Your Pomodoro is underway"
	if_inside_tmux && tmux refresh-client -S
	return 0
}

pomodoro_cancel() {
	local notification="$1"

	clean_env
	remove_file "$POMODORO_INTERVAL_FILE"

	if [ "$notification" = true ]; then
		send_notification "🍅 Pomodoro cancelled!" "Your Pomodoro has been cancelled"
	fi

	if_inside_tmux && tmux refresh-client -S
	return 0
}

pomodoro_custom() {
	tmux command-prompt \
		-I "$(get_pomodoro_length), $(get_pomodoro_break)" \
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
		"$(get_pomodoro_length) minutes (default)" "" "set -g @pomodoro_mins $(get_pomodoro_length)" \
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
	pomodoro_start_time=$(read_file "$POMODORO_START_FILE")
	pomodoro_start_delta=$((current_time - pomodoro_start_time))
	pomodoro_length="$(minutes_to_seconds "$(get_pomodoro_length)")"

	# _____________________________________________| statusline logic |__ ;

	# Don't display anything if the pomodoro isn't in progress
	if [ "$pomodoro_start_time" -eq 1 ]; then
		return 0
	fi

	# Display the waiting prompts to the user
	if [ "$pomodoro_status" == "waiting_pomodoro" ]; then
		printf "%s" "$(get_tmux_option "$pomodoro_prompt_pomodoro" "$pomodoro_prompt_pomodoro_default")"
	fi
	if [ "$pomodoro_status" == "waiting_break" ]; then
		printf "%s" "$(get_tmux_option "$pomodoro_prompt_break" "$pomodoro_prompt_break_default")"
	fi

	# Check if the pomodoro has completed
	[ $pomodoro_start_delta -ge "$pomodoro_length" ] && completed=true || completed=false

	# Pomodoro in progress
	if [ "$pomodoro_status" == "in_progress" ] && [ $pomodoro_start_delta -lt "$pomodoro_length" ]; then
		pomodoro_time_left="$((pomodoro_length - pomodoro_start_delta))"
		printf "%s%s" "$(get_tmux_option "$pomodoro_on" "$pomodoro_on_default")" "$(format_seconds $pomodoro_time_left)"
	fi

	# Pomodoro completed, notifying the user
	if [ "$completed" = true ] && [ "$pomodoro_status" == "in_progress" ] && ! prompt_user; then
		send_notification "🍅 Pomodoro completed!" "Starting the break"
	fi

	# Pomodoro complete, starting the prompt
	if [ "$completed" = true ] && [ "$pomodoro_status" == "in_progress" ] && prompt_user; then
		set_status "waiting_break"
		send_notification "🍅 Pomodoro completed!" "Start the break?"
	fi

	# Pomodoro complete, waiting for the user to respond to the prompt
	if [ -f "$POMODORO_PROMPT_BREAK_FILE" ] && prompt_user; then
		break_start_time=$(read_file "$POMODORO_PROMPT_BREAK_FILE")
		pomodoro_start_delta=$((current_time - break_start_time))
	fi

	# Pomodoro complete, starting the break
	if [ "$completed" = true ] && { [ "$pomodoro_status" == "in_progress" ] || [ "$pomodoro_status" == "initiating_break" ]; }; then
		if intervals_reached; then
			set_status "long_break"
		else
			set_status "break"
		fi
	fi

	# Break in progress
	if [ "$pomodoro_status" == "break" ] || [ "$pomodoro_status" == "long_break" ]; then
		if prompt_user; then
			break_time_left=$((-(current_time - break_start_time - $(break_length))))
		else
			break_time_left=$((-(pomodoro_start_delta - pomodoro_length - $(break_length))))
		fi

		printf "%s%s" "$(get_tmux_option "$pomodoro_complete" "$pomodoro_complete_default")" "$(format_seconds $break_time_left)"
	fi

	# Break in progress, might be complete
	if [ "$pomodoro_status" == "break" ] || [ "$pomodoro_status" == "long_break" ]; then
		if prompt_user; then
			[ $((current_time - break_start_time)) -ge "$(break_length)" ] && break_complete=true || break_complete=false
		else
			[ "$pomodoro_start_delta" -ge $((pomodoro_length + $(break_length))) ] && break_complete=true || break_complete=false
		fi
	fi

	# Break complete
	if [ "$break_complete" = true ] && { [ "$pomodoro_status" == "break" ] || [ "$pomodoro_status" == "long_break" ]; }; then
		set_status "break_complete"

		break_message="🍅 Break completed!"
		long_break_message="🍅 Long break completed!"
		standard_message="Starting the Pomodoro"
		prompt_message="Start the Pomodoro?"

		if intervals_reached; then
			primary_message="$long_break_message"
		else
			primary_message="$break_message"
		fi

		if prompt_user; then
			send_notification "$primary_message" "$prompt_message"
			set_status "waiting_pomodoro"
		else
			send_notification "$primary_message" "$standard_message"
			pomodoro_start
		fi
	fi

	# Display interval count last in the statusline
	show_intervals
}

main() {
	cmd=$1
	shift

	if [ "$cmd" = "toggle" ]; then
		pomodoro_toggle
	elif [ "$cmd" = "start" ]; then
		pomodoro_start
	elif [ "$cmd" = "menu" ]; then
		pomodoro_menu
	elif [ "$cmd" = "custom" ]; then
		pomodoro_custom
	else
		pomodoro_status
	fi
}

main "$@"
