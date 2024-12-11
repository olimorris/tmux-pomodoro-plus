#!/usr/bin/env bash
# _______________________________________________________________| locals |__ ;

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

POMODORO_USER_MINS_FILE="$CURRENT_DIR/scripts/user_mins.txt"
POMODORO_USER_INTERVAL_FILE="$CURRENT_DIR/scripts/user_interval.txt"
POMODORO_USER_BREAK_MINS_FILE="$CURRENT_DIR/scripts/user_break_mins.txt"
POMODORO_USER_LONG_BREAK_MINS_FILE="$CURRENT_DIR/scripts/user_long_break_mins.txt"

default_toggle_pomodoro="p"
toggle_pomodoro="@pomodoro_toggle"
default_restart_pomodoro="e"
restart_pomodoro="@pomodoro_restart"
default_skip_pomodoro="_"
skip_pomodoro="@pomodoro_skip"
default_cancel_pomodoro="P"
cancel_pomodoro="@pomodoro_cancel"

pomodoro_status="#($CURRENT_DIR/scripts/pomodoro.sh)"
pomodoro_status_interpolation_string="\#{pomodoro_status}"

# ______________________________________________________________| methods |__ ;

source "$CURRENT_DIR/scripts/helpers.sh"

load_custom_timings() {
	pomodoro_mins_exists=$(tmux show-option -gqv "@pomodoro_mins")

	if [ "$pomodoro_mins_exists" != "" ]; then
		remove_file "$POMODORO_USER_MINS_FILE"
		remove_file "$POMODORO_USER_INTERVAL_FILE"
		remove_file "$POMODORO_USER_BREAK_MINS_FILE"
		remove_file "$POMODORO_USER_LONG_BREAK_MINS_FILE"
		return 0
	fi

	if file_exists "$POMODORO_USER_MINS_FILE"; then
		set_tmux_option "@pomodoro_mins $(read_file "$POMODORO_USER_MINS_FILE")"
	fi
	if file_exists "$POMODORO_USER_INTERVAL_FILE"; then
		set_tmux_option "@pomodoro_intervals $(read_file "$POMODORO_USER_INTERVAL_FILE")"
	fi
	if file_exists "$POMODORO_USER_BREAK_MINS_FILE"; then
		set_tmux_option "@pomodoro_break_mins $(read_file "$POMODORO_USER_BREAK_MINS_FILE")"
	fi
	if file_exists "$POMODORO_USER_LONG_BREAK_MINS_FILE"; then
		set_tmux_option "@pomodoro_long_break_mins $(read_file "$POMODORO_USER_LONG_BREAK_MINS_FILE")"
	fi
}

set_keybindings() {
	toggle_binding=$(get_tmux_option "$toggle_pomodoro" "$default_toggle_pomodoro")
	for key in $toggle_binding; do
		tmux bind-key -N "Toggle between starting/pausing a Pomodoro/break" "$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh toggle"
		tmux bind-key -N "Open the Pomodoro timer menu" "C-$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh menu"
		tmux bind-key -N "Set a custom Pomodoro timer" "M-$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh custom"
	done

	skip_binding=$(get_tmux_option "$skip_pomodoro" "$default_skip_pomodoro")
	for key in $skip_binding; do
		tmux bind-key -N "Skip a Pomodoro/break" "$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh skip"
	done

	restart_binding=$(get_tmux_option "$restart_pomodoro" "$default_restart_pomodoro")
	for key in $restart_binding; do
		tmux bind-key -N "Restart a Pomodoro" "$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh restart"
	done

	cancel_binding=$(get_tmux_option "$cancel_pomodoro" "$default_cancel_pomodoro")
	for key in $cancel_binding; do
		tmux bind-key -N "Cancel a Pomodoro/break" "$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh cancel"
	done
}

do_interpolation() {
	local string="$1"
	local interpolated="${string//$pomodoro_status_interpolation_string/$pomodoro_status}"
	echo "$interpolated"
}

update_tmux_option() {
	local option="$1"

	option_value="$(get_tmux_option "$option")"
	new_option_value="$(do_interpolation "$option_value")"

	set_tmux_option "$option" "$new_option_value"
}

main() {
	load_custom_timings
	set_keybindings
	update_tmux_option "status-right"
	update_tmux_option "status-left"

	local lines=$(get_tmux_option "status")
	if [[ "$lines" =~ ^[0-9]+$ ]] && [ "$lines" -ge 2 ]; then
	 	for (( i = 1; i < lines; i++ )); do
			update_tmux_option "status-format[$i]"
		done
	fi
}

main
