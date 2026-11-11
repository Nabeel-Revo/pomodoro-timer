import Foundation

enum Phase { case work, shortBreak, longBreak }

final class PomodoroTimer: ObservableObject {
    // Edit these to change the schedule (seconds).
    static let durations: [Phase: Int] = [.work: 25 * 60, .shortBreak: 5 * 60, .longBreak: 15 * 60]
    static let sessionsBeforeLongBreak = 4

    @Published private(set) var phase: Phase = .work
    @Published private(set) var remaining = durations[.work]!
    @Published private(set) var running = false
    @Published private(set) var completedSessions = 0

    private let onPhaseEnd: (Phase) -> Void
    private var ticker: Timer?

    init(onPhaseEnd: @escaping (Phase) -> Void) {
        self.onPhaseEnd = onPhaseEnd
        // shortcut: counts wall-clock seconds via a 1s Timer, drifts a few seconds over 25 min; switch to an end Date if that matters
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    var label: String {
        String(format: "%@ %d:%02d", phase == .work ? "🍅" : "☕️", remaining / 60, remaining % 60)
    }

    func toggle() { running.toggle() }

    func reset() {
        running = false
        remaining = Self.durations[phase]!
    }

    func skip() { advance() }

    func tick() {
        guard running else { return }
        remaining -= 1
        if remaining <= 0 {
            let ended = phase
            advance()
            onPhaseEnd(ended)
        }
    }

    private func advance() {
        if phase == .work {
            completedSessions += 1
            phase = completedSessions % Self.sessionsBeforeLongBreak == 0 ? .longBreak : .shortBreak
        } else {
            phase = .work
        }
        remaining = Self.durations[phase]!
        running = false
    }
}
