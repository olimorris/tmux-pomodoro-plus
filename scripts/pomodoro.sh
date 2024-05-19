#!/usr/bin/env bash
# _______________________________________________________________| locals |__ ;

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POMODORO_DIR="/tmp/pomodoro"
POMODORO_USER="${HOME}/.cache/tmux_pomodoro_plus"

START_FILE="$POMODORO_DIR/start_time.txt"                # Stores the start time of the Pomodoro/break
PAUSED_FILE="$POMODORO_DIR/paused_time.txt"              # Stores the time when the Pomodoro/break was paused
SKIPPED_FILE="$POMODORO_DIR/skipped.txt"                 # Stores whether a Pomodoro or break was skipped
TIME_PAUSED_FOR_FILE="$POMODORO_DIR/time_paused_for.txt" # Stores the time when the Pomodoro/break was resumed
FROZEN_DISPLAY_FILE="$POMODORO_DIR/frozen_display.txt"   # Stores the countdown when the Pomodoro/break was paused
INTERVAL_FILE="$POMODORO_DIR/interval_count.txt"         # Stores the current increment count
STATUS_FILE="$POMODORO_DIR/current_status.txt"           # Stores the current status of the Pomodoro/break

# Store the user's custom timings
mkdir -p $POMODORO_USER
POMODORO_USER_MINS_FILE="$POMODORO_USER/user_mins.txt"
POMODORO_USER_INTERVAL_FILE="$POMODORO_USER/user_interval.txt"
POMODORO_USER_BREAK_MINS_FILE="$POMODORO_USER/user_break_mins.txt"
POMODORO_USER_LONG_BREAK_MINS_FILE="$POMODORO_USER/user_long_break_mins.txt"

# Map tmux options to variables
pomodoro_mins="@pomodoro_mins"
pomodoro_break="@pomodoro_break_mins"
pomodoro_intervals="@pomodoro_intervals"
pomodoro_long_break="@pomodoro_long_break_mins"
pomodoro_repeat="@pomodoro_repeat"

pomodoro_on="@pomodoro_on"
pomodoro_on_default=" 🍅"
pomodoro_complete="@pomodoro_complete"
pomodoro_complete_default=" ✔︎"
pomodoro_pause="@pomodoro_pause"
pomodoro_pause_default=" ⏸︎"
pomodoro_prompt_break="@pomodoro_prompt_break"
pomodoro_prompt_break_default=" ⏲︎ break?"
pomodoro_prompt_pomodoro="@pomodoro_prompt_pomodoro"
pomodoro_prompt_pomodoro_default=" ⏱︎ start?"
pomodoro_interval_display="@pomodoro_interval_display"

pomodoro_sound="@pomodoro_sound"
pomodoro_notifications="@pomodoro_notifications"
pomodoro_granularity="@pomodoro_granularity"
pomodoro_disable_breaks="@pomodoro_disable_breaks"

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

get_pomodoro_repeat() {
	get_tmux_option "$pomodoro_repeat" "off"
}

get_pomodoro_disable_breaks() {
	get_tmux_option "$pomodoro_disable_breaks" "off"
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

clean_env() {
	remove_file "$SKIPPED_FILE"
	remove_file "$START_FILE"
	remove_file "$PAUSED_FILE"
	remove_file "$FROZEN_DISPLAY_FILE"
	remove_file "$TIME_PAUSED_FOR_FILE"
	remove_file "$STATUS_FILE"
}

set_status() {
	local message="$1"
	write_to_file "$message" "$STATUS_FILE"
}

read_status() {
	read_file "$STATUS_FILE"
}

intervals_reached() {
	interval_value=$(read_file "$INTERVAL_FILE")

	# If intervals meet the maximum value, delete interval file
	if [ "$interval_value" -eq "$(get_pomodoro_intervals)" ]; then
		return 0
	fi
	return 1
}

prompt_user() {
	if [ "$(get_pomodoro_repeat)" == "off" ]; then
		return 0
	fi
	return 1
}

is_being_prompted() {
	if [ "$(read_status)" == "waiting_for_break" ] || [ "$(read_status)" == "waiting_for_pomodoro" ]; then
		return 0
	fi
	return 1
}

skipped_pomodoro() {
	if [ "$(read_file "$SKIPPED_FILE")" == "pomodoro" ]; then
		return 0
	fi
	return 1
}

skipped_break() {
	if [ "$(read_file "$SKIPPED_FILE")" == "break" ]; then
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
	count=$(echo "$show_intervals" | grep -o "%s" | wc -l)

	if [ "$count" -eq 1 ]; then
		printf "$show_intervals" "$(read_file "$INTERVAL_FILE")"
	fi
	if [ "$count" -eq 2 ]; then
		printf "$show_intervals" "$(read_file "$INTERVAL_FILE")" "$(get_pomodoro_intervals)"
	fi
}

is_paused() {
	if file_exists "$PAUSED_FILE"; then
		return 0
	fi
	return 1
}

pomodoro_toggle() {
	if [ "$(read_status)" == "waiting_for_break" ]; then
		pomodoro_status="break"
		if intervals_reached; then
			pomodoro_status="long_break"
		fi
		set_status "$pomodoro_status"

		break_start
		refresh_statusline
		return 0
	fi

	if ! is_being_prompted && file_exists "$START_FILE" && ! is_paused; then
		pomodoro_pause
		refresh_statusline
		return 0
	fi

	if ! is_being_prompted && is_paused; then
		pomodoro_resume
		refresh_statusline
		return 0
	fi

	pomodoro_start
}

pomodoro_pause() {
	write_to_file "$(get_seconds)" "$PAUSED_FILE"
	send_notification "🍅 Pomodoro paused!" "Your Pomodoro has been paused"
}

pomodoro_resume() {
	# Keep a running total of the time paused for
	time_paused_for="$(($(get_seconds) - $(read_file "$PAUSED_FILE") + $(read_file "$TIME_PAUSED_FOR_FILE")))"
	write_to_file "$time_paused_for" "$TIME_PAUSED_FOR_FILE"

	remove_file "$PAUSED_FILE"
	remove_file "$FROZEN_DISPLAY_FILE"
	send_notification "🍅 Pomodoro resuming!" "Your Pomodoro has resumed"
}

time_paused_for() {
	if file_exists "$TIME_PAUSED_FOR_FILE"; then
		read_file "$TIME_PAUSED_FOR_FILE"
	else
		echo "0"
	fi
}

remove_time_paused_file() {
	remove_file "$TIME_PAUSED_FOR_FILE"
}

increment_interval() {
	if [ "$(get_pomodoro_intervals)" != "0" ]; then
		if intervals_reached; then
			remove_file "$INTERVAL_FILE"
		fi

		if file_exists "$INTERVAL_FILE"; then
			increment=$(($(read_file "$INTERVAL_FILE") + 1))
			write_to_file "$increment" "$INTERVAL_FILE"
		else
			write_to_file "1" "$INTERVAL_FILE"
		fi
	fi
}

pomodoro_start() {
	local verb=${1:-start}

	clean_env
	mkdir -p $POMODORO_DIR
	write_to_file "$(get_seconds)" "$START_FILE"

	set_status "in_progress"

	if [ "$verb" = start ]; then
		increment_interval
	fi

	refresh_statusline
	send_notification "🍅 Pomodoro ${verb}ed!" "Your Pomodoro is underway"
	return 0
}

pomodoro_restart() {
	pomodoro_start restart
}

break_start() {
	write_to_file "$(get_seconds)" "$START_FILE"

	refresh_statusline
	send_notification "🍅 Break started!" "Your break is underway"
	return 0
}

pomodoro_cancel() {
	local notification="$1"

	clean_env
	remove_file "$INTERVAL_FILE"

	if [ "$notification" = true ]; then
		send_notification "🍅 Pomodoro cancelled!" "Your Pomodoro has been cancelled"
	fi

	refresh_statusline
	return 0
}

pomodoro_skip() {
	remove_file "$PAUSED_FILE"
	pomodoro_status="$(read_status)"

	if [ "$pomodoro_status" = "in_progress" ]; then
		write_to_file "pomodoro" "$SKIPPED_FILE"
		refresh_statusline
		return 0
	fi

	if [ "$pomodoro_status" = "break" ] || [ "$pomodoro_status" = "long_break" ]; then
		write_to_file "break" "$SKIPPED_FILE"
		refresh_statusline
		return 0
	fi
}

pomodoro_custom() {
	tmux command-prompt \
		-I "$(get_pomodoro_duration),$(get_pomodoro_break),$(get_pomodoro_intervals),$(get_pomodoro_long_break)" \
		-p 'Pomodoro (mins):,Break (mins):,Intervals:,Long Break (mins):' \
		"set -g @pomodoro_mins %1;
		 set -g @pomodoro_break_mins %2;
		 set -g @pomodoro_intervals %3;
		 set -g @pomodoro_long_break_mins %4;
		 run-shell 'echo %1 > $POMODORO_USER_MINS_FILE';
		 run-shell 'echo %2 > $POMODORO_USER_BREAK_MINS_FILE'
		 run-shell 'echo %3 > $POMODORO_USER_INTERVAL_FILE'
		 run-shell 'echo %4 > $POMODORO_USER_LONG_BREAK_MINS_FILE'
		"
}

pomodoro_menu() {
	pomodoro_menu_position=$(get_tmux_option @pomodoro_menu_position "R")

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

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Intervals " \
		"" \
		"2 intervals" "" "set -g @pomodoro_intervals 2; run-shell 'echo 2 > $POMODORO_USER_INTERVAL_FILE'" \
		"3 intervals" "" "set -g @pomodoro_intervals 3; run-shell 'echo 3 > $POMODORO_USER_INTERVAL_FILE'" \
		"4 intervals" "" "set -g @pomodoro_intervals 4; run-shell 'echo 4 > $POMODORO_USER_INTERVAL_FILE'" \
		"5 intervals" "" "set -g @pomodoro_intervals 5; run-shell 'echo 5 > $POMODORO_USER_INTERVAL_FILE'" \
		"6 intervals" "" "set -g @pomodoro_intervals 6; run-shell 'echo 6 > $POMODORO_USER_INTERVAL_FILE'"

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Long break " \
		"" \
		"5 minutes" "" "set -g @pomodoro_long_break_mins 5 ; run-shell 'echo 5  > $POMODORO_USER_LONG_BREAK_MINS_FILE'" \
		"10 minutes" "" "set -g @pomodoro_long_break_mins 10; run-shell 'echo 10 > $POMODORO_USER_LONG_BREAK_MINS_FILE'" \
		"15 minutes" "" "set -g @pomodoro_long_break_mins 15; run-shell 'echo 15 > $POMODORO_USER_LONG_BREAK_MINS_FILE'" \
		"20 minutes" "" "set -g @pomodoro_long_break_mins 20; run-shell 'echo 20 > $POMODORO_USER_LONG_BREAK_MINS_FILE'" \
		"30 minutes" "" "set -g @pomodoro_long_break_mins 30; run-shell 'echo 30 > $POMODORO_USER_LONG_BREAK_MINS_FILE'"

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Start Pomodoro? " \
		"Yes" "" "run-shell '$CURRENT_DIR/pomodoro.sh start'" \
		"No" "" ""
}

pomodoro_status() {
	# ________________________________________________| set variables |__ ;

	current_time=$(get_seconds)
	pomodoro_status="$(read_status)"
	time_paused_for="$(time_paused_for)"
	start_time=$(read_file "$START_FILE")
	elapsed_time=$((current_time - start_time - time_paused_for))
	pomodoro_duration="$(minutes_to_seconds "$(get_pomodoro_duration)")"
	disable_breaks=$(get_pomodoro_disable_breaks)

	# ___________________________________________________| statusline |__ ;

	# Don't display anything if the Pomodoro isn't in progress
	if [ "$start_time" -eq 1 ]; then
		return 0
	fi

	# Display the frozen countdown to the user
	if is_paused && file_exists "$FROZEN_DISPLAY_FILE"; then
		printf "%s%s" "$(get_tmux_option "$pomodoro_pause" "$pomodoro_pause_default")" "$(read_file "$FROZEN_DISPLAY_FILE")"
		show_intervals
		return 0
	fi

	# Display the waiting prompts to the user
	if [ "$pomodoro_status" == "waiting_for_pomodoro" ]; then
		printf "%s" "$(get_tmux_option "$pomodoro_prompt_pomodoro" "$pomodoro_prompt_pomodoro_default")"
		show_intervals
		return 0
	fi
	if [ "$pomodoro_status" == "waiting_for_break" ]; then
		printf "%s" "$(get_tmux_option "$pomodoro_prompt_break" "$pomodoro_prompt_break_default")"
		show_intervals
		return 0
	fi

	# _____________________________________________________| pomodoro |__ ;
	{ [ $elapsed_time -ge "$pomodoro_duration" ] || skipped_pomodoro; } && pomodoro_completed=true || pomodoro_completed=false

	# Pomodoro in progress
	if [ "$pomodoro_completed" = false ] && [ "$pomodoro_status" == "in_progress" ]; then
		time_left="$((pomodoro_duration - elapsed_time))"

		# Write the current countdown to disk if we're paused
		if is_paused; then
			if ! file_exists "$FROZEN_DISPLAY_FILE"; then
				write_to_file "$(format_seconds $time_left)" "$FROZEN_DISPLAY_FILE"
			fi
			printf "%s%s" "$(get_tmux_option "$pomodoro_pause" "$pomodoro_pause_default")" "$(format_seconds $time_left)"
		else
			printf "%s%s" "$(get_tmux_option "$pomodoro_on" "$pomodoro_on_default")" "$(format_seconds $time_left)"
		fi

		show_intervals
		return 0
	fi

	# ________________________________________________________| break |__ ;

	# Pomodoro completed, starting the break
	if [ "$pomodoro_completed" = true ] && [ "$pomodoro_status" == "in_progress" ] && [ "$disable_breaks" != "on" ]; then
		pomodoro_status="break"
		remove_time_paused_file

		if prompt_user; then
			pomodoro_status="waiting_for_break"
			set_status "$pomodoro_status"
			send_notification "🍅 Pomodoro completed!" "Start the break now?"
			return 0
		fi

		if intervals_reached; then
			pomodoro_status="long_break"
		fi

		set_status "$pomodoro_status"
		break_start
		return 0
	fi

	# Breaks are disabled
	if [ "$pomodoro_completed" = true ] && [ "$pomodoro_status" == "in_progress" ] && [ "$disable_breaks" == "on" ]; then
		remove_time_paused_file

		if prompt_user; then
			set_status "waiting_for_pomodoro"
			send_notification "🍅 Pomodo completed!" "Start a new Pomodoro?"
			return 0
		fi

		pomodoro_start
		return 0
	fi

	# Has the break completed or been skipped?
	{ [ "$elapsed_time" -ge "$(break_length)" ] || skipped_break; } && break_complete=true || break_complete=false

	# Break in progress
	if [ "$break_complete" = false ] && { [ "$pomodoro_status" == "break" ] || [ "$pomodoro_status" == "long_break" ]; }; then
		time_left="$(($(break_length) - elapsed_time))"

		if is_paused; then
			if ! file_exists "$FROZEN_DISPLAY_FILE"; then
				write_to_file "$(format_seconds $time_left)" "$FROZEN_DISPLAY_FILE"
			fi
			printf "%s%s" "$(get_tmux_option "$pomodoro_pause" "$pomodoro_pause_default")" "$(format_seconds $time_left)"
		else
			printf "%s%s" "$(get_tmux_option "$pomodoro_complete" "$pomodoro_complete_default")" "$(format_seconds $time_left)"
		fi

		show_intervals
		return 0
	fi

	# Break complete
	if [ "$break_complete" = true ] && { [ "$pomodoro_status" == "break" ] || [ "$pomodoro_status" == "long_break" ]; }; then
		remove_time_paused_file

		if prompt_user; then
			set_status "waiting_for_pomodoro"
			send_notification "🍅 Break completed!" "Start the Pomodoro?"
			return 0
		fi

		pomodoro_start
	fi
}

main() {
	cmd="$1"
	shift

	if [ "$cmd" = "toggle" ]; then
		pomodoro_toggle
	elif [ "$cmd" = "start" ]; then
		pomodoro_start
	elif [ "$cmd" = "restart" ]; then
		pomodoro_restart
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
