# :tomato: Tmux Pomodoro Plus
<i>Incorporate the <a href="https://en.wikipedia.org/wiki/Pomodoro_Technique">Pomodoro technique</a> into your tmux setup</i>

## :book: Table of Contents

- [Features](#sparkles-features)
- [Installation](#package-installation)
- [Usage](#rocket-usage)
- [Configuration](#wrench-configuration)
- [How it works](#microscope-how-it-works)
- [Screenshots](#camera-screenshots)
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

## :package: Installation

1. Using [TPM](https://github.com/tmux-plugins/tpm), add the following line to your `~/.tmux.conf` file:

```bash
set -g @plugin 'olimorris/tmux-pomodoro-plus'
```

> Note: The above line should be *before* `run '~/.tmux/plugins/tpm/tpm'`

2. Then press `prefix` + <kbd>I</kbd> (capital i, as in **I**nstall) to fetch the plugin as per the TPM installation instructions.

## :rocket: Usage

To incorporate into your status bar:

```bash
set -g status-right "#{pomodoro_status}"
```

### Default keybindings
- `C-b p` to start a pomodoro
- `C-b P` to cancel a pomodoro

Where `C-b` is your Tmux bind-key.

## :wrench: Configuration
Some possible options for configuration are:

```bash
# Options
set -g @pomodoro_start 'p'                          # Start a Pomodoro with bind key + p
set -g @pomodoro_cancel 'P'                         # Cancel a Pomodoro with bind key + P

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

## :camera: Screenshots

### Animation
![Plugin animation](https://user-images.githubusercontent.com/9512444/132001146-c0b175bb-d555-4576-ae23-459dcce1606f.gif "Plugin animation")
> Note: <kbd>Ctrl</kbd> + <kbd>a</kbd> is the tmux key-bind in this video

### Default status bar
- Pomodoro on
![Pomodoro on](https://user-images.githubusercontent.com/9512444/132001545-990ecf87-2632-4279-ba76-0302eae00e81.png "Pomodoro on")

- Pomodoro interval complete, break countdown
![Pomodoro break](https://user-images.githubusercontent.com/9512444/132001492-d11d8491-f17e-400a-95b2-df21f4846ae4.png "Pomodoro break")

### Example: Customised status bar
- Pomodoro on
![Pomodoro on](https://user-images.githubusercontent.com/9512444/132001344-0d37ba38-ce9d-4b9f-b0c1-af1c82a4fc0e.png "Pomodoro on")

- Pomodoro interval complete, break countdown
![Pomodoro break](https://user-images.githubusercontent.com/9512444/132001439-cd6b3acd-1cba-42b5-82a6-a351f47d8e98.png "Pomodoro break")

> Note: I'm using custom Nerdfont icons in the above screenshots

## :page_with_curl: License
[MIT](https://github.com/olimorris/tmux-pomodoro-plus/blob/master/LICENSE.md)
