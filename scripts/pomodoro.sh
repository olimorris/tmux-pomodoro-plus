#!/usr/bin/env bash
# ______________________________________________________________| locals |__ ;
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POMODORO_DIR="/tmp"

# file to track focus time
POMODORO_START_FILE="$POMODORO_DIR/pomodoro_start.txt"
# file to track intervals
POMODORO_INTERVAL_FILE="$POMODORO_DIR/pomodoro_interval.txt"
# file to track end focus time, used only if pomodoro_auto_start_break=false
POMODORO_END_TIME_FILE="$POMODORO_DIR/pomodoro_end_time.txt"
# file to track time between a pomodoro ending and a break starting, used only if pomodoro_auto_start_break=false
POMODORO_BREAK_TIME_FILE="$POMODORO_DIR/pomodoro_break_time.txt"
# file to know pomodoro status
POMODORO_STATUS_FILE="$POMODORO_DIR/pomodoro_status.txt"
# file to store pomodoro focus time in minutes
POMODORO_MINS_FILE="$CURRENT_DIR/user_mins.txt"
# file to store break time in minutes
POMODORO_BREAK_MINS_FILE="$CURRENT_DIR/user_break_mins.txt"

pomodoro_duration_minutes="@pomodoro_mins"
pomodoro_intervals="@pomodoro_intervals"
pomodoro_long_break_minutes="@pomodoro_long_break_mins"
pomodoro_break_minutes="@pomodoro_break_mins"
pomodoro_auto_start="@pomodoro_auto_start"
pomodoro_on="@pomodoro_on"
pomodoro_ask_break="@pomodoro_ask_break"
pomodoro_complete="@pomodoro_complete"
pomodoro_notifications="@pomodoro_notifications"
pomodoro_granularity="@pomodoro_granularity"
pomodoro_sound="@pomodoro_sound"
pomodoro_on_default=" 🍅"
pomodoro_ask_break_default=" 🕤 break?"
pomodoro_complete_default=" ✅"

# _____________________________________________________________| methods |__ ;

source "$CURRENT_DIR/helpers.sh"

get_pomodoro_duration() {
	get_tmux_option "$pomodoro_duration_minutes" "25"
}

get_pomodoro_break() {
	get_tmux_option "$pomodoro_break_minutes" "5"
}

get_pomodoro_intervals() {
	get_tmux_option "$pomodoro_intervals" "0"
}

get_pomodoro_long_break() {
	get_tmux_option "$pomodoro_long_break_minutes" "25"
}

get_pomodoro_auto_start() {
	get_tmux_option "$pomodoro_auto_start" false
}

get_seconds() {
	date +%s
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

get_notifications() {
	get_tmux_option "$pomodoro_notifications" "off"
}

get_pomodoro_granularity() {
	get_tmux_option "$pomodoro_granularity" "off"
}

get_sound() {
	get_tmux_option "$pomodoro_sound" "off"
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
	remove_file "$POMODORO_END_TIME_FILE"
	remove_file "$POMODORO_BREAK_TIME_FILE"
}

pomodoro_hold_for_user() {
	write_to_file "pomodoro_hold" "$POMODORO_STATUS_FILE"
	export pomodoro_status="pomodoro_hold"
}

break_hold_for_user() {
	write_to_file "break_hold" "$POMODORO_STATUS_FILE"
	export pomodoro_status="break_hold"
}

pomodoro_toggle() {
	local pomodoro_status
	pomodoro_status=$(read_file "$POMODORO_STATUS_FILE")

	if [ "$pomodoro_status" == "break_hold" ]; then
		write_to_file "on_break" "$POMODORO_STATUS_FILE"
		write_to_file "$(get_seconds)" "$POMODORO_BREAK_TIME_FILE"
		if_inside_tmux && tmux refresh-client -S
		return 0
	elif [ "$pomodoro_status" == "pomodoro_hold" ]; then
		clean_env
		pomodoro_start
		if_inside_tmux && tmux refresh-client -S
		return 0
	elif [ -f "$POMODORO_START_FILE" ]; then
		pomodoro_cancel
		return 0
	fi

	pomodoro_start
}

pomodoro_start() {
	clean_env
	mkdir -p $POMODORO_DIR
	write_to_file "$(get_seconds)" "$POMODORO_START_FILE"

	# Log intervals
	if [ "$(get_pomodoro_intervals)" != "0" ]; then
		interval_value=$(read_file "$POMODORO_INTERVAL_FILE")

		# If intervals meet the maximum value, delete interval file
		if [ "$interval_value" -eq "$(get_pomodoro_intervals)" ]; then
			remove_file "$POMODORO_INTERVAL_FILE"
		fi

		if [ "$(file_exists "$POMODORO_INTERVAL_FILE")" = "-1" ]; then
			write_to_file "1" "$POMODORO_INTERVAL_FILE"
		else
			interval_value=$((interval_value + 1))
			write_to_file "$interval_value" "$POMODORO_INTERVAL_FILE"
		fi
	fi

	send_notification "🍅 Pomodoro started!" "Your Pomodoro is underway"
	if_inside_tmux && tmux refresh-client -S
	return 0
}

pomodoro_cancel() {
	clean_env
	remove_file "$POMODORO_INTERVAL_FILE"

	if [[ -z $1 ]]; then
		send_notification "🍅 Pomodoro cancelled!" "Your Pomodoro has been cancelled"
	fi
	if_inside_tmux && tmux refresh-client -S
	return 0
}

pomodoro_custom() {
	tmux command-prompt \
		-I "$(get_pomodoro_duration), $(get_pomodoro_break)" \
		-p 'Pomodoro duration (mins):, Break duration (mins):' \
		"set -g @pomodoro_mins %1;
		 set -g @pomodoro_break_mins %2;
		 run-shell 'echo %1 > $POMODORO_MINS_FILE';
		 run-shell 'echo %2 > $POMODORO_BREAK_MINS_FILE'
		"
}

pomodoro_menu() {
	pomodoro_menu_position=$(get_tmux_option @pomodoro_menu_position "R")
	export pomodoro_menu_position

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Pomodoro " \
		"$(get_pomodoro_duration) minutes (default)" "" "set -g @pomodoro_mins $(get_pomodoro_duration)" \
		"" \
		"15 minutes" "" "set -g @pomodoro_mins 15; run-shell 'echo 15 > $POMODORO_MINS_FILE'" \
		"20 minutes" "" "set -g @pomodoro_mins 20; run-shell 'echo 20 > $POMODORO_MINS_FILE'" \
		"25 minutes" "" "set -g @pomodoro_mins 25; run-shell 'echo 25 > $POMODORO_MINS_FILE'" \
		"30 minutes" "" "set -g @pomodoro_mins 30; run-shell 'echo 30 > $POMODORO_MINS_FILE'" \
		"40 minutes" "" "set -g @pomodoro_mins 40; run-shell 'echo 40 > $POMODORO_MINS_FILE'" \
		"50 minutes" "" "set -g @pomodoro_mins 50; run-shell 'echo 50 > $POMODORO_MINS_FILE'"

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Break " \
		"" \
		"5 minutes" "" "set -g @pomodoro_break_mins 5 ; run-shell 'echo 5  > $POMODORO_BREAK_MINS_FILE'" \
		"10 minutes" "" "set -g @pomodoro_break_mins 10; run-shell 'echo 10 > $POMODORO_BREAK_MINS_FILE'" \
		"15 minutes" "" "set -g @pomodoro_break_mins 15; run-shell 'echo 15 > $POMODORO_BREAK_MINS_FILE'" \
		"20 minutes" "" "set -g @pomodoro_break_mins 20; run-shell 'echo 20 > $POMODORO_BREAK_MINS_FILE'" \
		"30 minutes" "" "set -g @pomodoro_break_mins 30; run-shell 'echo 30 > $POMODORO_BREAK_MINS_FILE'"

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Start Pomodoro? " \
		"Yes" "" "run-shell '$CURRENT_DIR/pomodoro.sh start'" \
		"No" "" ""
}

pomodoro_status() {
	# TODO: Revise the scope of these variables
	pomodoro_start_time=$(read_file "$POMODORO_START_FILE")
	export pomodoro_start_time

	pomodoro_intervals_count=$(read_file "$POMODORO_INTERVAL_FILE")
	export pomodoro_intervals_count

	if [ "$pomodoro_intervals_count" -eq "$(get_pomodoro_intervals)" ]; then
		local intervals_reached
		intervals_reached=true
	fi

	pomodoro_end_time=$(read_file "$POMODORO_END_TIME_FILE")
	export pomodoro_end_time

	pomodoro_waiting_break=$(read_file "$POMODORO_BREAK_TIME_FILE")
	export pomodoro_waiting_break

	local pomodoro_status
	pomodoro_status=$(read_file "$POMODORO_STATUS_FILE")

	current_time=$(get_seconds)
	export current_time

	local pomodoro_auto_start
	pomodoro_auto_start=$(get_pomodoro_auto_start)

	local pomodoro_duration
	pomodoro_duration="$(minutes_to_seconds "$(get_pomodoro_duration)")"

	local break_duration
	break_duration="$(minutes_to_seconds "$(get_pomodoro_break)")"

	local long_break_duration
	long_break_duration="$(minutes_to_seconds "$(get_pomodoro_long_break)")"

	if [ "$pomodoro_end_time" != -1 ]; then
		# Waiting for the user to start a break
		local elaps_from_start=$((current_time - pomodoro_start_time - (pomodoro_waiting_break - pomodoro_end_time)))
	else
		# Pomodoro in progress
		local elaps_from_start=$((current_time - pomodoro_start_time))
	fi

	##### Pomodoro not started ############################################
	if [ "$pomodoro_start_time" -eq -1 ]; then
		return 0
	##### Pomodoro break completed ########################################
	elif { [ "$pomodoro_status" == "on_break" ] && [ "$elaps_from_start" -ge $((pomodoro_duration + break_duration)) ]; } ||
		{ [ "$pomodoro_status" == "on_long_break" ] && [ "$elaps_from_start" -ge $((pomodoro_duration + long_break_duration)) ]; }; then

		send_notification "🍅 Break finished!" "Your Pomodoro break is now over"
		write_to_file "break_complete" "$POMODORO_STATUS_FILE"

		if [ "$pomodoro_auto_start" = true ]; then
			pomodoro_start
		else
			pomodoro_hold_for_user
			send_notification "🍅 Break completed!" "Start a new Pomodoro?"
		fi

		pomodoro_start_time=-1
	##### Pomodoro completed ##############################################
	elif [ $elaps_from_start -ge "$pomodoro_duration" ]; then
		if [ "$pomodoro_status" -eq -1 ]; then
			send_notification "🍅 Pomodoro completed!" "Your Pomodoro has now completed"

			if [ "$pomodoro_auto_start" = true ]; then

				# Start the break
				if [ "$intervals_reached" = true ]; then
					# Long break
					write_to_file "on_long_break" "$POMODORO_STATUS_FILE"
					pomodoro_status="on_long_break"
					send_notification "🍅 Starting a long break!" "Enjoy your rest"
				else
					# Regular break
					write_to_file "on_break" "$POMODORO_STATUS_FILE"
					pomodoro_status="on_break"
				fi

			else
				# Wait for the user to manually start the break
				pomodoro_end_time_file_exist=$(read_file "$POMODORO_END_TIME_FILE")
				if [ "$pomodoro_end_time_file_exist" -ne 0 ]; then
					write_to_file "$(get_seconds)" "$POMODORO_END_TIME_FILE"
				fi

				break_hold_for_user
				send_notification "🍅 Pomodoro completed!" "Start a break?"
			fi
		fi

		# Update the break timer in the statusbar
		if [ "$pomodoro_status" == "on_break" ] || [ "$pomodoro_status" == "on_long_break" ]; then
			if [ "$pomodoro_status" == "on_break" ]; then
				time_left_seconds=$((-(elaps_from_start - pomodoro_duration - break_duration)))
			else
				time_left_seconds=$((-(elaps_from_start - pomodoro_duration - long_break_duration)))
			fi

			time_left_formatted=$(format_seconds $time_left_seconds)
			printf "$(get_tmux_option "$pomodoro_complete" "$pomodoro_complete_default")$time_left_formatted "
		else
			write_to_file "$(get_seconds)" "$POMODORO_BREAK_TIME_FILE"
			printf "$(get_tmux_option "$pomodoro_ask_break" "$pomodoro_ask_break_default") "
		fi

	##### Pomodoro in progress ############################################
	else
		pomodoro_duration_secs=$(minutes_to_seconds "$(get_pomodoro_duration)")
		time_left_formatted=$(format_seconds $((pomodoro_duration_secs - elaps_from_start)))
		printf "$(get_tmux_option "$pomodoro_on" "$pomodoro_on_default")$time_left_formatted "
	fi
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
