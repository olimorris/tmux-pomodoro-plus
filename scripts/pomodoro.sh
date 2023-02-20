#!/usr/bin/env bash
# ______________________________________________________________| locals |__ ;
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POMODORO_DIR="/tmp"
POMODORO_FILE="$POMODORO_DIR/pomodoro.txt"
POMODORO_STATUS_FILE="$POMODORO_DIR/pomodoro_status.txt"
POMODORO_MINS_FILE="$CURRENT_DIR/user_mins.txt"
POMODORO_BREAK_MINS_FILE="$CURRENT_DIR/user_break_mins.txt"

pomodoro_duration_minutes="@pomodoro_mins"
pomodoro_break_minutes="@pomodoro_break_mins"
pomodoro_auto_restart="@pomodoro_auto_restart"
pomodoro_on="@pomodoro_on"
pomodoro_complete="@pomodoro_complete"
pomodoro_notifications="@pomodoro_notifications"
pomodoro_granularity="@pomodoro_granularity"
pomodoro_sound="@pomodoro_sound"
pomodoro_on_default=" 🍅"
pomodoro_complete_default=" ✅"

# _____________________________________________________________| methods |__ ;

source "$CURRENT_DIR/helpers.sh"

get_pomodoro_duration() {
	get_tmux_option "$pomodoro_duration_minutes" "25"
}

get_pomodoro_break() {
	get_tmux_option "$pomodoro_break_minutes" "5"
}

get_pomodoro_auto_restart() {
	get_tmux_option "$pomodoro_auto_restart" false
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
	remove_file "$POMODORO_FILE"
	remove_file "$POMODORO_STATUS_FILE"
}

pomodoro_toggle() {
	if [ -f "$POMODORO_FILE" ]; then
		pomodoro_cancel
		return 0
	fi

	pomodoro_start
}

pomodoro_start() {
	clean_env
	mkdir -p $POMODORO_DIR
	write_to_file "$(get_seconds)" "$POMODORO_FILE"

	send_notification "🍅 Pomodoro started!" "Your Pomodoro is underway"
	if_inside_tmux && tmux refresh-client -S
	return 0
}

pomodoro_cancel() {
	clean_env
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

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Pomodoro Duration " \
		"$(get_pomodoro_duration) minutes (default)" "" "set -g @pomodoro_mins $(get_pomodoro_duration)" \
		"" \
		"15 minutes" "" "set -g @pomodoro_mins 15; run-shell 'echo 15 > $POMODORO_MINS_FILE'" \
		"20 minutes" "" "set -g @pomodoro_mins 20; run-shell 'echo 20 > $POMODORO_MINS_FILE'" \
		"25 minutes" "" "set -g @pomodoro_mins 25; run-shell 'echo 25 > $POMODORO_MINS_FILE'" \
		"30 minutes" "" "set -g @pomodoro_mins 30; run-shell 'echo 30 > $POMODORO_MINS_FILE'" \
		"40 minutes" "" "set -g @pomodoro_mins 40; run-shell 'echo 40 > $POMODORO_MINS_FILE'"

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Break " \
		"" \
		"5 minutes" "" "set -g @pomodoro_break_mins 5 ; run-shell 'echo 5  > $POMODORO_BREAK_MINS_FILE'" \
		"10 minutes" "" "set -g @pomodoro_break_mins 10; run-shell 'echo 10 > $POMODORO_BREAK_MINS_FILE'" \
		"15 minutes" "" "set -g @pomodoro_break_mins 15; run-shell 'echo 15 > $POMODORO_BREAK_MINS_FILE'" \
		"20 minutes" "" "set -g @pomodoro_break_mins 20; run-shell 'echo 20 > $POMODORO_BREAK_MINS_FILE'" \
		"30 minutes" "" "set -g @pomodoro_break_mins 30; run-shell 'echo 30 > $POMODORO_BREAK_MINS_FILE'"

	tmux display-menu -y S -x "$pomodoro_menu_position" -T " Start New Pomodoro? " \
		"yes" "" "run-shell '$CURRENT_DIR/pomodoro.sh start'" \
		"no" "" ""
}

pomodoro_status() {
	pomodoro_start_time=$(read_file "$POMODORO_FILE")
	export pomodoro_start_time

	pomodoro_status=$(read_file "$POMODORO_STATUS_FILE")
	export pomodoro_status

	current_time=$(get_seconds)
	export current_time

	pomodoro_auto_restart=$(get_pomodoro_auto_restart)
	export pomodoro_auto_restart

	local difference=$((current_time - pomodoro_start_time))

	if [ "$pomodoro_start_time" -eq -1 ]; then
		echo ""
	elif [ $difference -ge "$(minutes_to_seconds $(($(get_pomodoro_duration) + $(get_pomodoro_break))))" ]; then
		pomodoro_start_time=-1
		echo ""
		if [ "$pomodoro_status" == 'on_break' ]; then
			send_notification "🍅 Break finished!" "Your Pomodoro break is now over"
			write_to_file "break_complete" "$POMODORO_STATUS_FILE"
			if [ "$pomodoro_auto_restart" = true ]; then
				pomodoro_start
			else
				# Cancel the pomodoro and silence any notifications
				pomodoro_cancel true
			fi
		fi
	elif [ $difference -ge "$(minutes_to_seconds "$(get_pomodoro_duration)")" ]; then
		if [ "$pomodoro_status" -eq -1 ]; then
			send_notification "🍅 Pomodoro completed!" "Your Pomodoro has now completed"
			write_to_file "on_break" "$POMODORO_STATUS_FILE"
		fi

		pomodoro_duration_secs=$(minutes_to_seconds "$(get_pomodoro_duration)")
		break_duration_seconds=$(minutes_to_seconds "$(get_pomodoro_break)")
		time_left_seconds=$((-(difference - pomodoro_duration_secs - break_duration_seconds)))
		time_left_formatted=$(format_seconds $time_left_seconds)

		printf "$(get_tmux_option "$pomodoro_complete" "$pomodoro_complete_default")$time_left_formatted "
	else
		pomodoro_duration_secs=$(minutes_to_seconds "$(get_pomodoro_duration)")
		time_left_formatted=$(format_seconds $((pomodoro_duration_secs - difference)))
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
