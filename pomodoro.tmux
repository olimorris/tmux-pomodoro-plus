#!/usr/bin/env bash
# ______________________________________________________________| locals |__ ;

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POMODORO_MINS_FILE="$CURRENT_DIR/scripts/user_mins.txt"
POMODORO_BREAK_MINS_FILE="$CURRENT_DIR/scripts/user_break_mins.txt"

default_start_pomodoro="p"
start_pomodoro="@pomodoro_start"
default_cancel_pomodoro="P"
cancel_pomodoro="@pomodoro_cancel"

pomodoro_status="#($CURRENT_DIR/scripts/pomodoro.sh)"
pomodoro_status_interpolation_string="\#{pomodoro_status}"

# _____________________________________________________________| methods |__ ;

source "$CURRENT_DIR/scripts/helpers.sh"

sync_timers() {
	pomodoro_mins_exists=$(tmux show-option -gqv "@pomodoro_mins")
	export pomodoro_mins_exists

	if [ "$pomodoro_mins_exists" != "" ]; then
		remove_file "$POMODORO_MINS_FILE"
		remove_file "$POMODORO_BREAK_MINS_FILE"

	elif [ -f "$POMODORO_MINS_FILE" ] &&
		[ -f "$POMODORO_BREAK_MINS_FILE" ]; then
		set_tmux_option "@pomodoro_mins $(read_file "$POMODORO_MINS_FILE")"
		set_tmux_option "@pomodoro_break_mins $(read_file "$POMODORO_BREAK_MINS_FILE")"
	fi
}

set_bindings() {
	start_binding=$(get_tmux_option "$start_pomodoro" "$default_start_pomodoro")
	export start_binding

	for key in $start_binding; do
		tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh toggle"
		tmux bind-key "C-$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh menu"
		tmux bind-key "M-$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh custom"
	done

	cancel_binding=$(get_tmux_option "$cancel_pomodoro" "$default_cancel_pomodoro")
	export cancel_binding

	for key in $cancel_binding; do
		tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh toggle"
	done
}

do_interpolation() {
	local string="$1"
	local interpolated="${string/$pomodoro_status_interpolation_string/$pomodoro_status}"
	echo "$interpolated"
}

update_tmux_option() {
	local option="$1"

	option_value="$(get_tmux_option "$option")"
	export option_value

	new_option_value="$(do_interpolation "$option_value")"
	export new_option_value

	set_tmux_option "$option" "$new_option_value"
}

main() {
	sync_timers
	set_bindings
	update_tmux_option "status-right"
	update_tmux_option "status-left"
}
main
