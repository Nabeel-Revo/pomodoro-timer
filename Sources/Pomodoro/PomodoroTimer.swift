import Foundation

enum Phase { case work, shortBreak, longBreak }

struct Preset: Codable, Equatable, Hashable {
    var name: String
    var work: Int       // minutes
    var shortBreak: Int
    var longBreak: Int

    static let builtIn = [
        Preset(name: "Focus", work: 25, shortBreak: 5, longBreak: 15),
        Preset(name: "Deep work", work: 50, shortBreak: 10, longBreak: 20),
    ]

    func minutes(for phase: Phase) -> Int {
        switch phase {
        case .work: work
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
    }
}

struct Settings: Codable {
    var preset = Preset.builtIn[0]
    var customPresets: [Preset] = []
    var autoStartBreaks = false
    var autoStartWork = false
    var sessionsByDay: [Date: Int] = [:]  // key: start of day
    var dailyGoal = 1  // sessions needed for a day to count toward the streak

    init() {}

    // Hand-written so settings saved by older versions (missing newer keys) still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preset = try c.decode(Preset.self, forKey: .preset)
        customPresets = try c.decode([Preset].self, forKey: .customPresets)
        autoStartBreaks = try c.decode(Bool.self, forKey: .autoStartBreaks)
        autoStartWork = try c.decode(Bool.self, forKey: .autoStartWork)
        sessionsByDay = try c.decode([Date: Int].self, forKey: .sessionsByDay)
        dailyGoal = try c.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? 1
    }
}

final class PomodoroTimer: ObservableObject {
    static let sessionsBeforeLongBreak = 4
    static let storageKey = "settings"

    @Published private(set) var phase: Phase = .work
    @Published private(set) var remaining: Int  // seconds; authoritative only while paused
    @Published private(set) var running = false
    @Published var settings: Settings {
        didSet { defaults.set(try? JSONEncoder().encode(settings), forKey: Self.storageKey) }
    }

    private var endDate: Date?
    private let onPhaseEnd: (Phase) -> Void
    private let defaults: UserDefaults
    private var ticker: Timer?

    init(onPhaseEnd: @escaping (Phase) -> Void, defaults: UserDefaults = .standard) {
        self.onPhaseEnd = onPhaseEnd
        self.defaults = defaults
        let saved = defaults.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) }
        settings = saved ?? Settings()
        remaining = (saved ?? Settings()).preset.work * 60
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    var label: String {
        String(format: "%@ %d:%02d", phase == .work ? "🍅" : "☕️", remaining / 60, remaining % 60)
    }

    var allPresets: [Preset] { Preset.builtIn + settings.customPresets }

    func sessions(today now: Date = Date()) -> Int {
        settings.sessionsByDay[Calendar.current.startOfDay(for: now)] ?? 0
    }

    func sessions(thisWeek now: Date = Date()) -> Int {
        settings.sessionsByDay
            .filter { Calendar.current.isDate($0.key, equalTo: now, toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.value }
    }

    /// Consecutive goal-met days ending today, or yesterday if today isn't done yet.
    func streak(now: Date = Date()) -> Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: now)
        if !goalMet(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while goalMet(day) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    func bestStreak() -> Int {
        let cal = Calendar.current
        let days = settings.sessionsByDay.keys.filter(goalMet)
        return days.map { start in
            var day = start, run = 0
            while goalMet(day) {
                run += 1
                day = cal.date(byAdding: .day, value: 1, to: day)!
            }
            return run
        }.max() ?? 0
    }

    private func goalMet(_ day: Date) -> Bool {
        (settings.sessionsByDay[day] ?? 0) >= settings.dailyGoal
    }

    func toggle(now: Date = Date()) { running ? pause(now: now) : start(now: now) }

    func start(now: Date = Date()) {
        endDate = now.addingTimeInterval(TimeInterval(remaining))
        running = true
    }

    func pause(now: Date = Date()) {
        tick(now: now)
        endDate = nil
        running = false
    }

    func reset() {
        endDate = nil
        running = false
        remaining = settings.preset.minutes(for: phase) * 60
    }

    func skip(now: Date = Date()) { advance(now: now) }

    func select(_ preset: Preset, now: Date = Date()) {
        settings.preset = preset
        phase = .work
        reset()
    }

    func addCustom(_ preset: Preset) {
        settings.customPresets.removeAll { $0.name == preset.name }
        settings.customPresets.append(preset)
        select(preset)
    }

    /// Recomputes `remaining` from the wall clock, so sleep/wake and timer drift don't matter.
    func tick(now: Date = Date()) {
        guard running, let endDate else { return }
        remaining = max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
        if remaining == 0 {
            let ended = phase
            advance(now: now)
            onPhaseEnd(ended)
        }
    }

    private func advance(now: Date) {
        if phase == .work {
            settings.sessionsByDay[Calendar.current.startOfDay(for: now), default: 0] += 1
            phase = sessions(today: now) % Self.sessionsBeforeLongBreak == 0 ? .longBreak : .shortBreak
        } else {
            phase = .work
        }
        reset()
        if phase == .work ? settings.autoStartWork : settings.autoStartBreaks { start(now: now) }
    }
}
