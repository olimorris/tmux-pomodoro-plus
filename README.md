<p align="center">
<img src="https://github.com/olimorris/tmux-pomodoro-plus/assets/9512444/a3e445f0-6493-4375-977e-b89013968604" alt="Tmux Pomodoro Plus" />
</p>

<h1 align="center">Tmux Pomodoro Plus</h1>

<p align="center">
<a href="https://github.com/olimorris/tmux-pomodoro-plus/stargazers"><img src="https://img.shields.io/github/stars/olimorris/tmux-pomodoro-plus?color=c678dd&logoColor=e06c75&style=for-the-badge"></a>
<a href="https://github.com/olimorris/tmux-pomodoro-plus/issues"><img src="https://img.shields.io/github/issues/olimorris/tmux-pomodoro-plus?color=%23d19a66&style=for-the-badge"></a>
<a href="https://github.com/olimorris/tmux-pomodoro-plus/blob/main/LICENSE.md"><img src="https://img.shields.io/github/license/olimorris/tmux-pomodoro-plus?style=for-the-badge"></a>
<a href="https://github.com/olimorris/tmux-pomodoro-plus/actions/workflows/test.yml"><img src="https://img.shields.io/github/actions/workflow/status/olimorris/tmux-pomodoro-plus/test.yml?branch=main&label=tests&style=for-the-badge"></a>
</p>

<p align="center">
Incorporate the <a href="https://en.wikipedia.org/wiki/Pomodoro_Technique">Pomodoro technique</a> into your <a href="https://github.com/tmux/tmux">tmux</a> setup. Forked from <a href="https://github.com/alexanderjeurissen/tmux-pomodoro">Tmux Pomodoro</a><br><br>Please subscribe to <a href="https://github.com/olimorris/tmux-pomodoro-plus/issues/29">this issue</a> to be notified of any breaking changes to the plugin
</p>

## :sparkles: Features

- Toggle a Pomodoro and see the countdown and the break in the status bar
- Skip, pause and resume a Pomodoro/break at any point
- Customise the Pomodoro duration, break times and intervals
- Restart your Pomodoros to automatically or be prompted
- Desktop alerts for Pomodoros and breaks (MacOS and Linux only)
- Custom keybindings

## :camera: Screenshots

Pomodoro counting down:
![Image](https://user-images.githubusercontent.com/9512444/218257051-1cdc4487-7e0a-4d1f-9e70-932028f47d6f.png)

Pomodoro on a break:
![Image](https://user-images.githubusercontent.com/9512444/218257106-c3f83c7e-a467-4965-adfd-8c0b9b06ad9b.png)

Pomodoro counting down in real-time:
![Image](https://user-images.githubusercontent.com/9512444/218257132-6aac32d9-6ecb-4192-926c-1c41cb4adc62.gif)

Pomodoro timer menu:
![Image](https://user-images.githubusercontent.com/9512444/179624439-c5203dd1-01a9-4bf8-93dc-3da162939a4a.gif)

## :package: Installation

1. Using [TPM](https://github.com/tmux-plugins/tpm), add the following line to your `~/.tmux.conf` file:

```bash
set -g @plugin 'olimorris/tmux-pomodoro-plus'
```

> **Note**: The above line should be _before_ `run '~/.tmux/plugins/tpm/tpm'`

2. Then press `tmux-prefix` + <kbd>I</kbd> (capital i, as in **I**nstall) to fetch the plugin as per the TPM installation instructions

## :rocket: Usage

### Default keybindings

- `<tmux-prefix> p` to toggle between starting/pausing a Pomodoro/break
- `<tmux-prefix> P` to cancel a Pomodoro/break
- `<tmux-prefix> _` to skip a Pomodoro/break
- `<tmux-prefix> e` to restart a Pomodoro
- `<tmux-prefix> C-p` to open the Pomodoro timer menu
- `<tmux-prefix> M-p` to set a custom Pomodoro timer

The Pomodoro timer menu and custom Pomodoro input are always `<ctrl>/<alt> + [your start Pomodoro key]`.

### Status bar

To incorporate into your status bar:

```bash
set -g status-right "#{pomodoro_status}"
```

## :wrench: Configuration

> **Note**: On Linux, notifications depend on `notify-send/libnotify-bin`

The default configuration:

```bash
set -g @pomodoro_toggle 'p'                    # Start/pause a Pomodoro/break
set -g @pomodoro_cancel 'P'                    # Cancel the current session
set -g @pomodoro_skip '_'                      # Skip a Pomodoro/break

set -g @pomodoro_mins 25                       # The duration of the Pomodoro
set -g @pomodoro_break_mins 5                  # The duration of the break after the Pomodoro completes
set -g @pomodoro_intervals 4                   # The number of intervals before a longer break is started
set -g @pomodoro_long_break_mins 25            # The duration of the long break
set -g @pomodoro_repeat 'off'                  # Automatically repeat the Pomodoros?
set -g @pomodoro_disable_breaks 'off'          # Turn off breaks

set -g @pomodoro_on " 🍅"                      # The formatted output when the Pomodoro is running
set -g @pomodoro_complete " ✔︎"                 # The formatted output when the break is running
set -g @pomodoro_pause " ⏸︎"                    # The formatted output when the Pomodoro/break is paused
set -g @pomodoro_prompt_break " ⏲︎ break?"      # The formatted output when waiting to start a break
set -g @pomodoro_prompt_pomodoro " ⏱︎ start?"   # The formatted output when waiting to start a Pomodoro

set -g @pomodoro_menu_position "R"             # The location of the menu relative to the screen
set -g @pomodoro_sound 'off'                   # Sound for desktop notifications (Run `ls /System/Library/Sounds` for a list of sounds to use on Mac)
set -g @pomodoro_notifications 'off'           # Enable desktop notifications from your terminal
set -g @pomodoro_granularity 'off'             # Enables MM:SS (ex: 00:10) format instead of the default (ex: 1m)
```

### Customising the status line

The output from the plugin can be customised to fit in with your statusline:

```bash
set -g @pomodoro_on "#[fg=$text_red]🍅 "
set -g @pomodoro_complete "#[fg=$text_green]🍅 "
set -g @pomodoro_pause "#[fg=$color_yellow]🍅 "
set -g @pomodoro_prompt_break "#[fg=$color_green]🕤 ? "
set -g @pomodoro_prompt_pomodoro "#[fg=$color_gray]🕤 ? "
```

The current and total number of intervals can also be displayed:

```bash
set -g @pomodoro_interval_display "[%s/%s]"
```

> **Note**: If you provide just 1 `%s` then the current interval count will be displayed only

A real-time countdown can be also be displayed:

```bash
set -g @pomodoro_granularity 'on'
set -g status-interval 1                       # Refresh the status line every second
```

## :clap: Credits

- [Wladyslaw Fedorov](https://dribbble.com/Wladza) - For the squashed tomato image

## :page_with_curl: License

[MIT](https://github.com/olimorris/tmux-pomodoro-plus/blob/master/LICENSE.md)
