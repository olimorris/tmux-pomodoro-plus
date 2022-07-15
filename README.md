# Tmux Pomodoro Plus

<p align="center">
<img src="https://user-images.githubusercontent.com/9512444/179077304-a6c31ccb-ad8f-41d9-97f8-f09a1c4935ad.png" alt="Tmux Pomodoro Plus" />
</p>

<p align="center">
Incorporate the <a href="https://en.wikipedia.org/wiki/Pomodoro_Technique">Pomodoro technique</a> into your <a href="https://github.com/tmux/tmux">tmux</a> setup. Forked from <a href="https://github.com/alexanderjeurissen/tmux-pomodoro">Tmux Pomodoro</a>
</p>

## :book: Table of Contents

- [Features](#sparkles-features)
- [Screenshots](#camera-screenshots)
- [Installation](#package-installation)
- [Usage](#rocket-usage)
- [Configuration](#wrench-configuration)
- [How it works](#microscope-how-it-works)
- [Thanks](#clap-thanks)
- [License](#page_with_curl-license)

## :sparkles: Features
- Toggle pomodoro timer on/off and see the countdown in the status bar
- Upon completion of a pomodoro, see a break countdown in the status bar
- Desktop alerts for pomodoro and break completion (macOS and Linux only)
- Customise the pomodoro duration and break times
- Custom keybindings

## :camera: Screenshots

Pomodoro counting down:
![Image](https://user-images.githubusercontent.com/9512444/179062001-d75827f6-7142-4bc2-a494-2efd450b2e32.png)

Pomodoro on a break:
![Image](https://user-images.githubusercontent.com/9512444/179061730-6b1cc2d5-eea4-443a-b19c-80a8f6683b16.png)

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
- `<tmux-prefix> C-p` to set a custom pomodoro duration

> **Note:** The custom pomodoro duration is always `<ctrl> + [your start pomodoro key]`

## :wrench: Configuration
The default configuration is:

```bash
set -g @pomodoro_start 'p'                  # Start a Pomodoro with tmux-prefix + p
set -g @pomodoro_cancel 'P'                 # Cancel a Pomodoro with tmux-prefix key + P

set -g @pomodoro_mins 25                    # The duration of the pomodoro
set -g @pomodoro_break_mins 5               # The duration of the break after the pomodoro

set -g @pomodoro_on " 🍅"                   # The formatted output when the pomodoro is running
set -g @pomodoro_complete " ✅"             # The formatted output when the break is running

set -g @pomodoro_notifications 'off'        # Turn on/off desktop notifications from your terminal
set -g @pomodoro_sound 'off'                # Sound for desktop notifications (Run `ls /System/Library/Sounds` for a list of sounds to use on Mac)
```

### Customising the status line

The output from the plugin can be completely customised to fit in with your status line. For example:

```bash
set -g @pomodoro_on " #[fg=$text_red]🍅 "
set -g @pomodoro_complete " #[fg=$text_green]🍅 "
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

## :clap: Thanks

Thanks to the following people:

- [Wladyslaw Fedorov](https://dribbble.com/Wladza) - For the squashed tomato image
- [basaran](https://github.com/basaran) - For the awesome pull request to add the linux notifications and the custom input for the pomodoro duration

## :page_with_curl: License
[MIT](https://github.com/olimorris/tmux-pomodoro-plus/blob/master/LICENSE.md)
