#!/usr/bin/env bash

get_tmux_option() {
	local option="$1"
	local default_value="$2"

	option_value=$(tmux show-option -gqv "$option")

	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

set_tmux_option() {
	local option="$1"
	local value="$2"

	tmux set-option -gq "$option" "$value"
}

file_exists() {
	local file="$1"
	if [ -f "$file" ]; then
		return 0 # file exists
	fi

	return 1 # file does not exist
}

read_file() {
	local file="$1"
	if [ -f "$file" ]; then
		cat "$file"
	else
		echo 1
	fi
}

remove_file() {
	local file="$1"
	if [ -f "$file" ]; then
		rm "$file"
	fi
}

write_to_file() {
	local data="$1"
	local file="$2"
	echo "$data" >"$file"
}

if_inside_tmux() {
	test -n "${TMUX}"
}

refresh_statusline() {
	if_inside_tmux && tmux refresh-client -S
}

minutes_to_seconds() {
	local minutes=$1
	echo $((minutes * 60))
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

debug_log() {
	# add log print into the code (debug_log "hello from tmux_pomodoro_plus)"
	# set true to enable log messages
	# follow the log using "tail -f /tmp/pomodoro/pomodoro.log"
	if true; then
		DIR="/tmp/pomodoro"
		FILE="pomodoro.log"
		mkdir -p $DIR
		echo "$(date +%T) " "$1" >>"$DIR/$FILE"
	fi
}
