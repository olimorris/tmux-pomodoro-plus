#!/usr/bin/env bash
# ______________________________________________________________| locals |__ ;

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POMODORO_DIR="/tmp"
POMODORO_FILE="$POMODORO_DIR/pomodoro.txt"
POMODORO_STATUS_FILE="$POMODORO_DIR/pomodoro_status.txt"
POMODORO_MINS_FILE="$CURRENT_DIR/user_mins.txt";
POMODORO_BREAK_MINS_FILE="$CURRENT_DIR/user_break_mins.txt"

pomodoro_duration_minutes="@pomodoro_mins"
pomodoro_break_minutes="@pomodoro_break_mins"
pomodoro_on="@pomodoro_on"
pomodoro_complete="@pomodoro_complete"
pomodoro_notifcations="@pomodoro_notifications"
pomodoro_sound="@pomodoro_sound"
pomodoro_on_default=" 🍅"
pomodoro_complete_default=" ✅"

# _____________________________________________________________| methods |__ ;

source $CURRENT_DIR/helpers.sh

get_pomodoro_duration() {
	get_tmux_option "$pomodoro_duration_minutes" "25"
}

get_pomodoro_break() {
	get_tmux_option "$pomodoro_break_minutes" "5"
}

get_seconds() {
	date +%s
}

get_current_dir() {
	poop="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	echo $poop
}

get_notifications() {
	get_tmux_option "$pomodoro_notifcations" "off"
}

get_sound() {
	get_tmux_option "$pomodoro_sound" "off"
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
			notify-send -t 8000 "$title" "$message"
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
	tmux display-menu -y S -x R -T " Pomodoro Duration " \
		"$(get_pomodoro_duration) minutes (default)" "" "set -g @pomodoro_mins $(get_pomodoro_duration)" \
		""  \
		"15 minutes" "" "set -g @pomodoro_mins 15; run-shell 'echo 15 > $POMODORO_MINS_FILE'" \
		"20 minutes" "" "set -g @pomodoro_mins 20; run-shell 'echo 20 > $POMODORO_MINS_FILE'" \
		"25 minutes" "" "set -g @pomodoro_mins 25; run-shell 'echo 25 > $POMODORO_MINS_FILE'" \
		"30 minutes" "" "set -g @pomodoro_mins 30; run-shell 'echo 30 > $POMODORO_MINS_FILE'" \
		"40 minutes" "" "set -g @pomodoro_mins 40; run-shell 'echo 40 > $POMODORO_MINS_FILE'"

	tmux display-menu -y S -x R -T " Break " \
		"" \
		"5 minutes"  "" "set -g @pomodoro_break_mins 5 ; run-shell 'echo 5  > $POMODORO_BREAK_MINS_FILE'" \
		"10 minutes" "" "set -g @pomodoro_break_mins 10; run-shell 'echo 10 > $POMODORO_BREAK_MINS_FILE'" \
		"15 minutes" "" "set -g @pomodoro_break_mins 15; run-shell 'echo 15 > $POMODORO_BREAK_MINS_FILE'" \
		"20 minutes" "" "set -g @pomodoro_break_mins 20; run-shell 'echo 20 > $POMODORO_BREAK_MINS_FILE'" \
		"30 minutes" "" "set -g @pomodoro_break_mins 30; run-shell 'echo 30 > $POMODORO_BREAK_MINS_FILE'"

	tmux display-menu -y S -x R -T " Start New Pomodoro? " \
		"yes" "" "run-shell '$CURRENT_DIR/pomodoro.sh start'" \
		"no" "" ""
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
	elif [ "$cmd" = "menu" ]; then
		pomodoro_menu
	elif [ "$cmd" = "custom" ]; then
		pomodoro_custom
	else
		pomodoro_status
	fi
}

main $@
