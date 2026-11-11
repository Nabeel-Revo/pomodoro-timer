# Pomodoro

A tiny macOS menu-bar Pomodoro timer. No Xcode project, no dependencies, nothing hosted.

25 min work → 5 min break, with a 15 min break after every 4th session. The menu bar shows the phase and time left. Start/Pause, Reset, Skip and Quit live in the menu. A sound and a notification fire when a phase ends; the next phase waits for you to press Start.

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

## Change the durations

Edit `durations` and `sessionsBeforeLongBreak` at the top of `Sources/Pomodoro/PomodoroTimer.swift`, then rebuild.

## Test

```sh
swift test
```

If `swift test` says it can't find `Testing`, your active toolchain is the Command Line Tools, which don't ship test frameworks. Point it at Xcode for that command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
