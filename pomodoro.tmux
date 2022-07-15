#!/usr/bin/env bash
# ______________________________________________________________| locals |__ ;

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
POMODORO_MINS_FILE="$CURRENT_DIR/scripts/user_mins.txt";
POMODORO_BREAK_MINS_FILE="$CURRENT_DIR/scripts/user_break_mins.txt"

default_start_pomodoro="a"
start_pomodoro="@pomodoro_start"
default_cancel_pomodoro="A"
cancel_pomodoro="@pomodoro_cancel"

pomodoro_status="#($CURRENT_DIR/scripts/pomodoro.sh)"
pomodoro_status_interpolation_string="\#{pomodoro_status}"

# _____________________________________________________________| methods |__ ;

source $CURRENT_DIR/scripts/helpers.sh

set_start_binding() {
	local key_bindings=$(get_tmux_option "$start_pomodoro" "$default_start_pomodoro")
	local key
	for key in $key_bindings; do
		tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh start"
		tmux bind-key "C-$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh menu"
		tmux bind-key "M-$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh custom"
	done
}

set_cancel_binding() {
	local key_bindings=$(get_tmux_option "$cancel_pomodoro" "$default_cancel_pomodoro")
	local key
	for key in $key_bindings; do
		tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/pomodoro.sh cancel"
	done

}

sync_timers() {
	local pomodoro_mins_exists=$(tmux show-option -gqv "@pomodoro_mins")
	#at the first boot, if the user didn't set
	#@pomodoro_mins, this will be an empty string.

	if [ "$pomodoro_mins_exists" != "" ]; then
		#user provided a timer, remove any written timers.
		remove_file $POMODORO_MINS_FILE
		remove_file $POMODORO_BREAK_MINS_FILE

	elif [ -f "$POMODORO_MINS_FILE" ] &&
			 [ -f "$POMODORO_BREAK_MINS_FILE" ]; then
		#try to find written timers and set them up.
		set_tmux_option @pomodoro_mins $(read_file $POMODORO_MINS_FILE)
		set_tmux_option @pomodoro_break_mins $(read_file $POMODORO_BREAK_MINS_FILE)
	fi
}

do_interpolation() {
	local string="$1"
	local interpolated="${string/$pomodoro_status_interpolation_string/$pomodoro_status}"
	echo "$interpolated"
}

update_tmux_option() {
	local option="$1"
	local option_value="$(get_tmux_option "$option")"
	local new_option_value="$(do_interpolation "$option_value")"
	set_tmux_option "$option" "$new_option_value"
}

main() {
	sync_timers
	set_start_binding
    set_cancel_binding
	update_tmux_option "status-right"
	update_tmux_option "status-left"
}
main
