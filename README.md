# Pomodoro

A tiny macOS menu-bar Pomodoro timer. No Xcode project, no dependencies, nothing hosted.

The menu bar shows the phase and time left. The menu has Start/Pause, Reset, Skip, a Preset submenu, auto-start toggles, today's and this week's session counts, and Quit. A sound and a notification fire when a phase ends.

- **Presets**: Focus (25 / 5 / 15 min), Deep work (50 / 10 / 20 min), or Custom… to save your own work / break / long-break lengths. A long break comes after every 4th work session.
- **Auto-start breaks / work**: off by default, so the next phase waits for Start.
- **Persistence**: preset, custom timers, toggles and session history are saved in UserDefaults.
- **Streaks**: consecutive days where you hit your daily goal (1 to 4 sessions, set in the menu). Today doesn't break the streak until midnight; the menu also shows your best streak.
- **Global hotkeys**: ⌃⌥P starts or pauses, ⌃⌥K skips, from any app. A short sound confirms each: high "tink" for start, "pop" for pause, "purr" for skip.
- **Pause awareness**: after 2 minutes paused, the menu bar shows how long, e.g. `🍅 24:50 ⏸7m`.
- **Idle detection**: 5 minutes without keyboard or mouse input during a work session pauses the timer and rewinds it to when you went idle. When you return, it asks whether to resume, count the away time as work, or stay paused.
- **Notifications with buttons**: Start and Skip right from the banner. Needs a signed build (see below); otherwise you get a plain notification.
- **Wall-clock timing**: the countdown is computed from an end time, so it stays correct after sleep or under load.

## Requirements

- macOS 13 or newer
- Xcode Command Line Tools (`xcode-select --install`)

## Run from source

```sh
git clone https://github.com/Nabeel-Revo/pomodoro-timer.git
cd pomodoro-timer
swift run
```

## Build a real app

```sh
make app       # produces Pomodoro.app in this folder
make install   # copies it to /Applications
```

### Notification buttons

macOS only allows real notifications from apps signed with a certificate, not ad-hoc builds. A free one takes a minute: open Xcode → Settings → Accounts → add your Apple ID → Manage Certificates → + → Apple Development. Then `make install` picks it up automatically. First launch asks for notification permission.

To launch at login: System Settings → General → Login Items → add Pomodoro.

## Change the built-in presets

Edit `Preset.builtIn` in `Sources/Pomodoro/PomodoroTimer.swift`, then rebuild. Or just use Custom… in the app.

## Test

```sh
swift test
```

## Project layout

- `Sources/Pomodoro/PomodoroTimer.swift` — timer state machine, presets, persistence (no UI)
- `Sources/Pomodoro/PomodoroApp.swift` — menu-bar UI, custom-timer window, notifications
- `Tests/PomodoroTests/` — Swift Testing tests for the timer logic
- `Info.plist`, `Makefile` — turn the build into `Pomodoro.app`

If `swift test` says it can't find `Testing`, your active toolchain is the Command Line Tools, which don't ship test frameworks. Point it at Xcode for that command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
