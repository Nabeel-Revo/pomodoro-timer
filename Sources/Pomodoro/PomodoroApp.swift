import AppKit
import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var timer = PomodoroTimer(onPhaseEnd: notify)

    init() {
        // Menu-bar only: no Dock icon when run via `swift run` (the .app bundle also sets LSUIElement).
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra(timer.label) {
            Button(timer.running ? "Pause" : "Start") { timer.toggle() }.keyboardShortcut("s")
            Button("Reset") { timer.reset() }.keyboardShortcut("r")
            Button("Skip") { timer.skip() }.keyboardShortcut("k")
            Divider()
            Text("Sessions completed: \(timer.completedSessions)")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        }
    }
}

func notify(_ ended: Phase) {
    NSSound(named: "Glass")?.play()
    let message = ended == .work ? "Work session done. Take a break." : "Break over. Back to work."
    // shortcut: osascript notification works unbundled and unsigned; use UNUserNotificationCenter once you ship a signed .app
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", "display notification \"\(message)\" with title \"Pomodoro\""]
    try? process.run()
}
