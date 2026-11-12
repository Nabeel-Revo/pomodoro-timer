# Pomodoro

A tiny macOS menu-bar Pomodoro timer. No Xcode project, no dependencies, nothing hosted.

The menu bar shows the phase and time left. The menu has Start/Pause, Reset, Skip, a Preset submenu, auto-start toggles, today's and this week's session counts, and Quit. A sound and a notification fire when a phase ends.

- **Presets**: Focus (25 / 5 / 15 min), Deep work (50 / 10 / 20 min), or Custom… to save your own work / break / long-break lengths. A long break comes after every 4th work session.
- **Auto-start breaks / work**: off by default, so the next phase waits for Start.
- **Persistence**: preset, custom timers, toggles and session history are saved in UserDefaults.
- **Wall-clock timing**: the countdown is computed from an end time, so it stays correct after sleep or under load.

## Requirements

- macOS 13 or newer
- Xcode Command Line Tools (`xcode-select --install`)

## Run from source

```sh
git clone <this repo>
cd pomodoro-timer
swift run
```

## Build a real app

```sh
make app       # produces Pomodoro.app in this folder
make install   # copies it to /Applications
```

To launch at login: System Settings → General → Login Items → add Pomodoro.

## Change the built-in presets

Edit `Preset.builtIn` in `Sources/Pomodoro/PomodoroTimer.swift`, then rebuild. Or just use Custom… in the app.

## Test

```sh
swift test
```

If `swift test` says it can't find `Testing`, your active toolchain is the Command Line Tools, which don't ship test frameworks. Point it at Xcode for that command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
