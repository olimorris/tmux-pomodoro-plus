# :tomato: Tmux Pomodoro Plus
Incorporate the <a href="https://en.wikipedia.org/wiki/Pomodoro_Technique">Pomodoro technique</a> into your [tmux](https://github.com/tmux/tmux) setup. Forked from [Tmux Pomodoro](https://github.com/alexanderjeurissen/tmux-pomodoro).

## :book: Table of Contents

- [Features](#sparkles-features)
- [Screenshots](#camera-screenshots)
- [Installation](#package-installation)
- [Usage](#rocket-usage)
- [Configuration](#wrench-configuration)
- [How it works](#microscope-how-it-works)
- [License](#page_with_curl-license)

## :sparkles: Features
- Toggle Pomodoro timer on/off and see the countdown in the status bar
- Upon completion of an interval, see a break countdown in the status bar

This plugin also adds additional functionality on top of `swaroopch/tmux-pomodoro`:
- Ability to specify the Pomodoro duration and break times
- Ability to choose where to place the Pomodoro status within your status bar
- Ability to choose the icons for the Pomodoro status
- Ability to format the Pomodoro status
- Ability to set custom keybindings to toggle on and off
- Ability to have desktop alerts (with sound) for pomodoro and break completion (macOS only)

## :camera: Screenshots

Pomodoro being toggled on and off:
![Image](https://user-images.githubusercontent.com/9512444/162638577-6f20e382-6974-4d55-8a3e-878b07926693.gif)

Pomodoro transitioning to a break:
![Image](https://user-images.githubusercontent.com/9512444/162638799-0b041e4e-c7c6-4692-9e4c-c0ed835bda30.gif)

## :package: Installation

1. Using [TPM](https://github.com/tmux-plugins/tpm), add the following line to your `~/.tmux.conf` file:

```bash
set -g @plugin 'olimorris/tmux-pomodoro-plus'
```

> Note: The above line should be *before* `run '~/.tmux/plugins/tpm/tpm'`

2. Then press `prefix` + <kbd>I</kbd> (capital i, as in **I**nstall) to fetch the plugin as per the TPM installation instructions

## :rocket: Usage

To incorporate into your status bar:

```bash
set -g status-right "#{pomodoro_status}"
```

### Default keybindings
- `<tmux-prefix> p` to start a pomodoro
- `<tmux-prefix> P` to cancel a pomodoro

## :wrench: Configuration
Some possible options for configuration are:

```bash
# Options
set -g @pomodoro_start 'p'                          # Start a Pomodoro with tmux-prefix + p
set -g @pomodoro_cancel 'P'                         # Cancel a Pomodoro with tmux-prefix key + P

set -g @pomodoro_mins 25                            # The duration of the pomodoro
set -g @pomodoro_break_mins 5                       # The duration of the break after the pomodoro

set -g @pomodoro_on " #[fg=$text_red]🍅 "           # The formatted output when the pomodoro is running
set -g @pomodoro_complete " #[fg=$text_green]🍅 "   # The formatted output when the break is running

set -g @pomodoro_notifications 'on'                 # Turn on/off desktop notifications
set -g @pomodoro_sound 'Pop'                        # Sound for desktop notifications (Run `ls /System/Library/Sounds` for a list of sounds to use)
```

## :microscope: How it works
- Starting a Pomodoro
    - Uses `date +%s` to get the current timestamp and write to `/tmp/pomodoro.txt`
    - This allows the app to keep track of the elapsed time
- Completing a Pomodoro
    - Writes the status of the pomodoro to `/tmp/pomodoro_status.txt`
    - This allows the app to know what type of notification to send
- Cancelling a Pomodoro
    - Deletes `/tmp/pomodoro.txt`
    - Deletes `/tmp/pomodoro_status.txt`
- Getting the status of a Pomodoro
    - Countdown: Compares current timestamp (via `date +%s`) with the start timestamp in `/tmp/pomodoro.txt`
    - Break: Compares the current timestamp with the start timestamp and adds on the break duration

## :page_with_curl: License
[MIT](https://github.com/olimorris/tmux-pomodoro-plus/blob/master/LICENSE.md)
