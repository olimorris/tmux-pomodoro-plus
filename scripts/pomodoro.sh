#!/usr/bin/env bash
# _______________________________________________________________| locals |__ ;
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POMODORO_DIR="/tmp"

# file to track start time of the current pomodoro
POMODORO_START_FILE="$POMODORO_DIR/pomodoro_start.txt"
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
pomodoro_ask="@pomodoro_ask"
pomodoro_ask_default=" 🕤 start?"
pomodoro_ask_break="@pomodoro_ask_break"
pomodoro_ask_break_default=" 🕤 break?"
pomodoro_complete="@pomodoro_complete"
pomodoro_complete_default=" ✅"

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

get_pomodoro_long_break() {
	get_tmux_option "$pomodoro_long_break" "25"
}

get_pomodoro_prompt() {
	get_tmux_option "$pomodoro_prompt" false
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
	pomodoro_status=""
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
	if [ "$(get_pomodoro_intervals)" == "true" ]; then
		return 0
	fi

	return 1
}

break_length() {
	if intervals_reached; then
		echo "$(minutes_to_seconds "$(get_pomodoro_long_break)")"
	else
		echo "$(minutes_to_seconds "$(get_pomodoro_break)")"
	fi
}

pomodoro_toggle() {
	if [ -f "$POMODORO_START_FILE" ]; then
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

	# Pomodoro in progress
	if [ "$pomodoro_status" == "in_progress" ] && [ $pomodoro_start_delta -lt "$pomodoro_length" ]; then
		pomodoro_time_left=$((pomodoro_length - pomodoro_start_delta))
		printf "$(get_tmux_option "$pomodoro_on" "$pomodoro_on_default")$(format_seconds $pomodoro_time_left) "
	fi

	# Pomodoro complete
	if [ "$pomodoro_status" == "in_progress" ] && [ $pomodoro_start_delta -ge "$pomodoro_length" ]; then
		if intervals_reached; then
			set_status "long_break"
		else
			set_status "break"
		fi
		send_notification "🍅 Pomodoro completed!" "Your Pomodoro has now completed"
	fi

	# Break in progress
	if [ "$pomodoro_status" == "break" ] || [ "$pomodoro_status" == "long_break" ] || [ "$pomodoro_status" == "waiting_break" ]; then
		# TODO: Prompt the user to start a break

		break_time_left=$((-(pomodoro_start_delta - pomodoro_length - $(break_length))))
		printf "$(get_tmux_option "$pomodoro_complete" "$pomodoro_complete_default")$(format_seconds $break_time_left) "
	fi

	# Break complete
	if { [ "$pomodoro_status" == "break" ] || [ "$pomodoro_status" == "long_break" ]; } && [ "$pomodoro_start_delta" -ge $((pomodoro_length + $(break_length))) ]; then
		if intervals_reached; then
			send_notification "🍅 Long break finished!" "Your long break is now over"
		else
			send_notification "🍅 Break finished!" "Your break is now over"
		fi
		set_status "break_complete"
	fi

	if [ "$pomodoro_status" == "break_complete" ]; then
		# TODO: Prompt the user to start a pomodoro
		pomodoro_start
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
