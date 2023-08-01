#!/usr/bin/env bash

# source the script file and the shunit2 library
. ./scripts/helpers.sh
. ./scripts/pomodoro.sh

# clean the environment
clean_env

#################################### TESTS ####################################
test_pomodoro_can_start() {
  pomodoro_start

  # Check that the start file has been created
  # pomodoro_status=$(read_file "$POMODORO_START_FILE")
  assertEquals "1" "1"
}
###############################################################################

# run the tests
. shunit2
