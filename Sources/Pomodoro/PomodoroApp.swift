import AppKit
import Carbon.HIToolbox
import SwiftUI
import UserNotifications

@main
struct PomodoroApp: App {
    @StateObject private var timer: PomodoroTimer
    @Environment(\.openWindow) private var openWindow

    init() {
        // Menu-bar only: no Dock icon when run via `swift run` (the .app bundle also sets LSUIElement).
        NSApplication.shared.setActivationPolicy(.accessory)
        let timer = PomodoroTimer(onPhaseEnd: Notifier.shared.phaseEnded, idleSeconds: systemIdleSeconds)
        timer.onIdleReturn = { [unowned timer] since in DispatchQueue.main.async { askAboutIdle(since: since, timer: timer) } }
        _timer = StateObject(wrappedValue: timer)
        Notifier.shared.setup(timer: timer)
        // Hotkeys give no visual feedback, so confirm with a distinct sound per action.
        registerHotKeys([
            (kVK_ANSI_P, { timer.toggle(); NSSound(named: timer.running ? "Tink" : "Pop")?.play() }),
            (kVK_ANSI_K, { timer.skip(); NSSound(named: "Purr")?.play() }),
        ])
    }

    var body: some Scene {
        MenuBarExtra(timer.label) {
            Button(timer.running ? "Pause" : "Start  (⌃⌥P anywhere)") { timer.toggle() }.keyboardShortcut("s")
            Button("Reset") { timer.reset() }.keyboardShortcut("r")
            Button("Skip  (⌃⌥K anywhere)") { timer.skip() }.keyboardShortcut("k")
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

// MARK: - Idle detection

/// Seconds since the last keyboard, mouse or trackpad event anywhere on the system.
func systemIdleSeconds() -> TimeInterval {
    CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
}

func askAboutIdle(since: Date, timer: PomodoroTimer) {
    let alert = NSAlert()
    alert.messageText = "You were away for \(Int(Date().timeIntervalSince(since) / 60)) min"
    alert.informativeText = "The timer paused when input stopped. Resume from where you left off, count the away time as work, or stay paused."
    alert.addButton(withTitle: "Resume")
    alert.addButton(withTitle: "Count it as work")
    alert.addButton(withTitle: "Stay paused")
    NSApplication.shared.activate(ignoringOtherApps: true)
    switch alert.runModal() {
    case .alertFirstButtonReturn: timer.resume(afterIdleSince: since, countIt: false)
    case .alertSecondButtonReturn: timer.resume(afterIdleSince: since, countIt: true)
    default: break
    }
}

// MARK: - Global hotkeys (⌃⌥ + key)

private var hotKeyActions: [UInt32: () -> Void] = [:]

func registerHotKeys(_ keys: [(keyCode: Int, action: () -> Void)]) {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
        var id = EventHotKeyID()
        GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
        hotKeyActions[id.id]?()
        return noErr
    }, 1, &spec, nil, nil)
    for (index, key) in keys.enumerated() {
        let id = UInt32(index + 1)
        hotKeyActions[id] = key.action
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(key.keyCode), UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x504F_4D4F, id: id), GetApplicationEventTarget(), 0, &ref)
    }
}

// MARK: - Notifications

final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    private weak var timer: PomodoroTimer?
    // Notifications with buttons need an app bundle signed with a real certificate: `swift run` has no
    // bundle, and macOS denies ad-hoc signed apps outright. Fall back to osascript (no buttons) otherwise.
    private let bundled = Bundle.main.bundleIdentifier != nil
    private var authorized = false

    func setup(timer: PomodoroTimer) {
        self.timer = timer
        guard bundled else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            self.authorized = granted
            if let error { NSLog("notifications unavailable, using fallback: \(error.localizedDescription)") }
        }
        center.setNotificationCategories([UNNotificationCategory(
            identifier: "phase",
            actions: [UNNotificationAction(identifier: "start", title: "Start"), UNNotificationAction(identifier: "skip", title: "Skip")],
            intentIdentifiers: [])])
    }

    func phaseEnded(_ ended: Phase) {
        NSSound(named: "Glass")?.play()
        let message = ended == .work ? "Work session done. Take a break." : "Break over. Back to work."
        guard bundled, authorized else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "display notification \"\(message)\" with title \"Pomodoro\""]
            try? process.run()
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro"
        content.body = message
        content.categoryIdentifier = "phase"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) { error in
            if let error { NSLog("notification failed: \(error)") }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler done: @escaping () -> Void) {
        DispatchQueue.main.async {
            switch response.actionIdentifier {
            case "start": if self.timer?.running == false { self.timer?.start() }
            case "skip": self.timer?.skip()
            default: break
            }
            done()
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner])  // still show it when the app happens to be frontmost
    }
}
