#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

tmux bind-key a run-shell "$CURRENT_DIR/scripts/pomodoro.sh start"
tmux bind-key A run-shell "$CURRENT_DIR/scripts/pomodoro.sh cancel"

tmux set-option -ga status-left "#($CURRENT_DIR/scripts/pomodoro.sh status)"
