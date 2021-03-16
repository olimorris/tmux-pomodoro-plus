# tmux plugin for pomodoro technique

## Install

Assuming you are using [tmux plugin manager](https://github.com/tmux-plugins/tpm), add this to your `~/.tmux.conf`:

```
set -g @plugin 'swaroopch/tmux-pomodoro'
```

NOTE: The above line should be *before* `run '~/.tmux/plugins/tpm/tpm'`

## Usage

- `C-b a` to start a pomodoro
- `C-b A` to cancel a pomodoro
