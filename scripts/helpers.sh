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
		echo 0 # file exists
	else
		echo 1 # file does not exist
	fi
}

read_file() {
	local file=$1
	if [ -f "$file" ]; then
		cat "$file"
	else
		echo -1
	fi
}

remove_file() {
	local file=$1
	if [ -f "$file" ]; then
		rm "$file"
	fi
}

write_to_file() {
	local data=$1
	local file=$2
	echo "$data" >"$file"
}

debug_log() {
	# add log print into the code (debug_log "hello from tmux_pomodoro_plus)"
	# set true to enable log messages
	# follow the log using "tail -f /tmp/tmux_pomodoro_debug_log/log.txt"
	if true; then
		DIR="/tmp/tmux_pomodoro_debug_log/"
		FILE="log.txt"
		mkdir -p $DIR
		echo "$(date +%T) " "$1" >>"$DIR/$FILE"
	fi
}
