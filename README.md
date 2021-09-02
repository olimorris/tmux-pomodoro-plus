# Tmux Pomodoro Plus
Incorporate the [Pomodoro technique](https://en.wikipedia.org/wiki/Pomodoro_Technique) into your tmux setup.

## Features
- Toggle Pomodoro timer on/off and see the countdown in the status bar
- Upon completion of an interval, see a break countdown in the status bar

This plugin also adds additional functionality on top of `swaroopch/tmux-pomodoro`:
- Ability to specify the Pomodoro duration and break times
- Ability to choose where to place the Pomodoro status within your status bar
- Ability to choose the icons for the Pomodoro status
- Ability to format the Pomodoro status
- Ability to set custom keybindings to toggle on and off

## Installation

1. Using [TPM](https://github.com/tmux-plugins/tpm), add the following line to your `~/.tmux.conf` file:

```bash
set -g @plugin 'olimorris/tmux-pomodoro-plus'
```

> Note: The above line should be *before* `run '~/.tmux/plugins/tpm/tpm'`

2. Then press `prefix` + <kbd>I</kbd> (capital i, as in **I**nstall) to fetch the plugin as per the TPM installation instructions.

## Usage

To incorporate into your status bar:

```bash
set -g status-right "#{pomodoro_status}"
```

### Default keybindings
- `C-b p` to start a pomodoro
- `C-b P` to cancel a pomodoro

Where `C-b` is your Tmux bind-key.

### Config
Some possible options for configuration are:

```bash
# Options
set -g @pomodoro_mins 25
set -g @pomodoro_break_mins 5
set -g @pomodoro_on " #[fg=$text_red]🍅 "
set -g @pomodoro_complete " #[fg=$text_green]🍅 "

# Keybindings
set -g @pomodoro_start 'a'
set -g @pomodoro_cancel 'A'
```

## How it works
- Starting a Pomodoro
    - Uses `date +%s` to get current timestamp and write to `/tmp/pomodoro.txt`
    - This enables you to reset the countdown
- Cancelling a Pomodoro
    - Deletes `/tmp/pomodoro.txt`
- Getting the status of a Pomodoro
    - Countdown: Compares current timestamp (via `date +%s`) with the start timestamp in `/tmp/pomodoro.txt`
    - Break: Compares the current timestamp with the start timestamp and adds on the break duration

## Screenshots

### Animation
![Plugin animation](https://user-images.githubusercontent.com/9512444/131862952-fdf5e343-6d0e-4d3f-ad71-057d0cf44819.png "Plugin animation")
> Note: <kbd>Ctrl</kbd> + <kbd>a</kbd> is the tmux key-bind in this video

### Default status bar
- Pomodoro on
![Pomodoro on](https://user-images.githubusercontent.com/9512444/131863201-e9023f9b-3967-4ba1-bd36-0fab803dedc5.png "Pomodoro on")

- Pomodoro interval complete, break countdown
![Pomodoro break](https://user-images.githubusercontent.com/9512444/131863083-427021ec-4d46-4366-b7dc-27415fadc78e.png "Pomodoro break")

### Example: Customised status bar
- Pomodoro on
![Pomodoro on](https://user-images.githubusercontent.com/9512444/131863235-4409401e-8957-4f7e-9783-08e657b0eab7.png "Pomodoro on")

- Pomodoro interval complete, break countdown
![Pomodoro break](https://user-images.githubusercontent.com/9512444/131863103-86c07439-5bf1-40bb-8b32-afaf8e97a4b7.png "Pomodoro break")

> Note: Using custom Nerdfont icons in the above screenshots

## License
[MIT](https://github.com/olimorris/tmux-pomodoro-plus/blob/master/LICENSE.md)
