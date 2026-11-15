import AppKit
import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var timer = PomodoroTimer(onPhaseEnd: notify)
    @Environment(\.openWindow) private var openWindow

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
            Menu("Preset: \(timer.settings.preset.name)") {
                ForEach(timer.allPresets, id: \.self) { preset in
                    Toggle(
                        "\(preset.name)  \(preset.work) / \(preset.shortBreak) / \(preset.longBreak) min",
                        isOn: Binding(get: { timer.settings.preset == preset }, set: { _ in timer.select(preset) })
                    )
                }
                Divider()
                Button("Custom…") {
                    openWindow(id: "custom")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
            Toggle("Auto-start breaks", isOn: $timer.settings.autoStartBreaks)
            Toggle("Auto-start work", isOn: $timer.settings.autoStartWork)
            Divider()
            Text("Today: \(timer.sessions(today: Date()))  ·  This week: \(timer.sessions(thisWeek: Date()))")
            Text("🔥 Streak: \(timer.streak()) days  ·  Best: \(timer.bestStreak())")
            Menu("Daily goal: \(timer.settings.dailyGoal)") {
                ForEach(1...4, id: \.self) { n in
                    Toggle(
                        "\(n) session\(n == 1 ? "" : "s") a day",
                        isOn: Binding(get: { timer.settings.dailyGoal == n }, set: { _ in timer.settings.dailyGoal = n })
                    )
                }
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        }
        Window("Custom Timer", id: "custom") {
            CustomTimerView().environmentObject(timer)
        }
        .windowResizability(.contentSize)
    }
}

final class Draft: ObservableObject {
    @Published var name = "Custom"
    @Published var work = 30
    @Published var shortBreak = 5
    @Published var longBreak = 15
}

struct CustomTimerView: View {
    @EnvironmentObject private var timer: PomodoroTimer
    @Environment(\.dismiss) private var dismiss
    // shortcut: @State is a macro the Command Line Tools can't expand on macOS 26; drop this class once it can
    @StateObject private var draft = Draft()

    var body: some View {
        Form {
            TextField("Name", text: $draft.name)
            Stepper("Work: \(draft.work) min", value: $draft.work, in: 1...180)
            Stepper("Break: \(draft.shortBreak) min", value: $draft.shortBreak, in: 1...60)
            Stepper("Long break: \(draft.longBreak) min", value: $draft.longBreak, in: 1...120)
            HStack {
                Spacer()
                Button("Save & Use") {
                    timer.addCustom(Preset(name: draft.name.trimmingCharacters(in: .whitespaces), work: draft.work, shortBreak: draft.shortBreak, longBreak: draft.longBreak))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
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
