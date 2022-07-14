#!/usr/bin/env bash

################################# SET VARIABLES ################################

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pomodoro_duration_minutes="@pomodoro_mins"
pomodoro_break_minutes="@pomodoro_break_mins"

pomodoro_on="@pomodoro_on"
pomodoro_complete="@pomodoro_complete"
pomodoro_notifcations="@pomodoro_notifications"
pomodoro_sound="@pomodoro_sound"
pomodoro_on_default="P:"
pomodoro_complete_default="✅"

POMODORO_DIR="/tmp"
POMODORO_FILE="$POMODORO_DIR/pomodoro.txt"
POMODORO_STATUS_FILE="$POMODORO_DIR/pomodoro_status.txt"
POMODORO_MINS_FILE="$CURRENT_DIR/user_mins.txt";
POMODORO_BREAK_MINS_FILE="$CURRENT_DIR/user_break_mins.txt"

source $CURRENT_DIR/helpers.sh

################################# FUNCTIONALITY ################################

get_pomodoro_duration() {
	get_tmux_option "$pomodoro_duration_minutes" "25"
}

get_pomodoro_break() {
	get_tmux_option "$pomodoro_break_minutes" "5"
}

get_seconds() {
	date +%s
}

get_notifications() {
	get_tmux_option "$pomodoro_notifcations" "off"
}

get_sound() {
	get_tmux_option "$pomodoro_sound" "off"
}

write_to_file() {
	local data=$1
	local file=$2
	echo "$data" >"$file"
}

read_file() {
	local file=$1
	if [ -f $1 ]; then
		cat $1
	else
		echo -1
	fi
}

remove_file() {
	local file=$1
	if [ -f $file ]; then
		rm $file
	fi
}

if_inside_tmux() {
	test -n "${TMUX}"
}

send_notification() {
	if [ $(get_notifications) == 'on' ]; then
		local title=$1
		local message=$2
		local sound=$(get_sound)

		if [[ "$OSTYPE" == "linux-gnu"* ]]; then
			notify-send -t 5000 "$title" "$message"

		elif [[ "$OSTYPE" == "darwin"* ]]; then
			if [[ sound == "on" ]]; then
				osascript -e 'display notification "'"$message"'" with title "'"$title"'" sound name "'"$sound"'"'
			else
				osascript -e 'display notification "'"$message"'" with title "'"$title"'"'
			fi
		fi

	fi
}

clean_env() {
	remove_file "$POMODORO_FILE"
	remove_file "$POMODORO_STATUS_FILE"
}

pomodoro_start() {
	clean_env
	mkdir -p $POMODORO_DIR
	write_to_file $(get_seconds) $POMODORO_FILE

	if [ -f "$POMODORO_MINS_FILE" ] && [ -f "$POMODORO_BREAK_MINS_FILE" ]; then
		user_pomodoro_mins=$(read_file "$POMODORO_MINS_FILE")
		user_pomodoro_break_mins=$(read_file "$POMODORO_BREAK_MINS_FILE")
		set_tmux_option @pomodoro_mins $user_pomodoro_mins
		set_tmux_option @pomodoro_break_mins $user_pomodoro_break_mins
	else
		pomodoro_manual
	fi

	send_notification "🍅 Pomodoro started!" "Your Pomodoro is underway"
	if_inside_tmux && tmux refresh-client -S
	return 0
}

pomodoro_cancel() {
	clean_env
	send_notification "🍅 Pomodoro cancelled!" "Your Pomodoro was cancelled"
	if_inside_tmux && tmux refresh-client -S
	return 0
}

pomodoro_manual() {
	tmux command-prompt \
		-I "$(get_pomodoro_duration), $(get_pomodoro_break)" \
		-p 'Pomodoro duration (mins):, Break duration (mins):' 'set -g @pomodoro_mins %1; set -g @pomodoro_break_mins %2'
	write_to_file $(get_pomodoro_duration) "$POMODORO_MINS_FILE"
	write_to_file $(get_pomodoro_break) "$POMODORO_BREAK_MINS_FILE"
}

pomodoro_status() {
	local pomodoro_start_time=$(read_file "$POMODORO_FILE")
	local pomodoro_status=$(read_file "$POMODORO_STATUS_FILE")
	local current_time=$(get_seconds)
	local difference=$((($current_time - $pomodoro_start_time) / 60))

	if [ $pomodoro_start_time -eq -1 ]; then
		echo ""
	elif [ $difference -ge $(($(get_pomodoro_duration) + $(get_pomodoro_break))) ]; then
		pomodoro_start_time=-1
		echo ""
		if [ $pomodoro_status == 'on_break' ]; then
			send_notification "🍅 Break finished!" "Your Pomodoro break is now over"
			write_to_file "break_complete" "$POMODORO_STATUS_FILE"
		fi
	elif [ $difference -ge $(get_pomodoro_duration) ]; then
		if [ $pomodoro_status -eq -1 ]; then
			send_notification "🍅 Pomodoro completed!" "Your Pomodoro has now completed"
			write_to_file "on_break" "$POMODORO_STATUS_FILE"
		fi
		printf "$(get_tmux_option "$pomodoro_complete" "$pomodoro_complete_default")$((-($difference - $(get_pomodoro_duration) - $(get_pomodoro_break))))m "
	else
		printf "$(get_tmux_option "$pomodoro_on" "$pomodoro_on_default")$(($(get_pomodoro_duration) - $difference))m "
	fi
}

main() {
	cmd=$1
	shift

	if [ "$cmd" = "start" ]; then
		pomodoro_start
	elif [ "$cmd" = "cancel" ]; then
		pomodoro_cancel
	elif [ "$cmd" = "manual" ]; then
		pomodoro_manual
	else
		pomodoro_status
	fi
}

main $@
