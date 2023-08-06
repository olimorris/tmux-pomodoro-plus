#!/usr/bin/env bash

# source the script file and the shunit2 library
. ./scripts/helpers.sh
. ./scripts/pomodoro.sh

# clean the environment
clean_env

#################################### TESTS ####################################
test_pomodoro_can_start() {
	pomodoro_start
	assertEquals "0" "$(file_exists "$POMODORO_START_FILE")"
}

test_can_get_status_of_pomodoro() {
	pomodoro_start
	assertNotNull "$(pomodoro_status)"
}

test_pomodoro_can_be_stopped() {
	pomodoro_cancel
	assertEquals "-1" "$(file_exists "$POMODORO_START_FILE")"
}
###############################################################################

# run the tests
. shunit2
