import Foundation
import Testing
@testable import Pomodoro

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)  // a Wednesday

private func makeTimer(onPhaseEnd: @escaping (Phase) -> Void = { _ in }) -> (PomodoroTimer, UserDefaults) {
    let defaults = UserDefaults(suiteName: "PomodoroTests-\(UUID())")!
    return (PomodoroTimer(onPhaseEnd: onPhaseEnd, defaults: defaults), defaults)
}

@Test func pausedTimerDoesNotCountDown() {
    let (timer, _) = makeTimer()
    timer.tick(now: t0.addingTimeInterval(60))
    #expect(timer.remaining == 25 * 60)
}

@Test func countsDownFromWallClockAndPauseFreezes() {
    let (timer, _) = makeTimer()
    timer.start(now: t0)
    timer.tick(now: t0.addingTimeInterval(10))
    #expect(timer.remaining == 25 * 60 - 10)
    timer.pause(now: t0.addingTimeInterval(12))
    timer.tick(now: t0.addingTimeInterval(500))
    #expect(timer.remaining == 25 * 60 - 12)
    #expect(!timer.running)
}

@Test func fourWorkSessionsThenLongBreak() {
    var ended: [Phase] = []
    let (timer, _) = makeTimer { ended.append($0) }
    for session in 1...4 {
        #expect(timer.phase == .work)
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(25 * 60))
        #expect(timer.phase == (session == 4 ? .longBreak : .shortBreak))
        #expect(!timer.running, "next phase waits for Start")
        #expect(timer.sessions(today: t0) == session)
        timer.skip(now: t0)
    }
    #expect(ended == [.work, .work, .work, .work], "skip must not notify")
    #expect(timer.sessions(thisWeek: t0) == 4)
    #expect(timer.sessions(today: t0.addingTimeInterval(86_400 * 10)) == 0)
}

@Test func autoStartBreaksStartsNextPhase() {
    let (timer, _) = makeTimer()
    timer.settings.autoStartBreaks = true
    timer.start(now: t0)
    timer.tick(now: t0.addingTimeInterval(25 * 60))
    #expect(timer.phase == .shortBreak)
    #expect(timer.running)
    timer.tick(now: t0.addingTimeInterval(25 * 60 + 60))
    #expect(timer.remaining == 4 * 60)
}

@Test func presetsAndSettingsPersist() {
    let (timer, defaults) = makeTimer()
    timer.addCustom(Preset(name: "Sprint", work: 15, shortBreak: 3, longBreak: 10))
    #expect(timer.remaining == 15 * 60)
    timer.addCustom(Preset(name: "Sprint", work: 20, shortBreak: 3, longBreak: 10))
    #expect(timer.allPresets.count == Preset.builtIn.count + 1, "same name replaces")

    let reloaded = PomodoroTimer(onPhaseEnd: { _ in }, defaults: defaults)
    #expect(reloaded.settings.preset.name == "Sprint")
    #expect(reloaded.remaining == 20 * 60)
    reloaded.select(Preset.builtIn[1])
    #expect(reloaded.remaining == 50 * 60)
}

@Test func resetRestoresCurrentPhaseDuration() {
    let (timer, _) = makeTimer()
    timer.start(now: t0)
    timer.tick(now: t0.addingTimeInterval(5))
    timer.reset()
    #expect(timer.remaining == 25 * 60)
    #expect(!timer.running)
}

private func day(_ offset: Int, from base: Date = t0) -> Date {
    Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: offset, to: base)!)
}

@Test func streakCountsConsecutiveGoalDaysAndForgivesToday() {
    let (timer, _) = makeTimer()
    timer.settings.sessionsByDay = [day(-1): 1, day(-2): 2, day(-3): 1, day(-5): 3]
    #expect(timer.streak(now: t0) == 3, "today not done yet, yesterday's run still counts")
    timer.settings.sessionsByDay[day(0)] = 1
    #expect(timer.streak(now: t0) == 4)
    #expect(timer.bestStreak() == 4)
    timer.settings.dailyGoal = 2
    #expect(timer.streak(now: t0) == 0)
    #expect(timer.bestStreak() == 1)
    #expect(timer.streak(now: day(2)) == 0, "a missed day breaks it")
}

@Test func settingsSavedByOlderVersionStillLoad() throws {
    let (timer, defaults) = makeTimer()
    timer.settings.sessionsByDay = [day(0): 2]
    var json = try #require(try JSONSerialization.jsonObject(with: defaults.data(forKey: PomodoroTimer.storageKey)!) as? [String: Any])
    json.removeValue(forKey: "dailyGoal")
    defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: PomodoroTimer.storageKey)
    let reloaded = PomodoroTimer(onPhaseEnd: { _ in }, defaults: defaults)
    #expect(reloaded.settings.dailyGoal == 1)
    #expect(reloaded.sessions(today: t0) == 2, "history survives the upgrade")
}

@Test func labelWarnsAfterLongPause() {
    let (timer, _) = makeTimer()
    timer.start(now: t0)
    timer.pause(now: t0.addingTimeInterval(10))
    #expect(timer.label(now: t0.addingTimeInterval(60)) == "🍅 24:50")
    #expect(timer.label(now: t0.addingTimeInterval(10 + 7 * 60)) == "🍅 24:50 ⏸7m")
    timer.start(now: t0.addingTimeInterval(500))
    #expect(timer.label(now: t0.addingTimeInterval(500)) == "🍅 24:50")
}

@Test func idlePausesRewindsAndAsksOnReturn() {
    var idle: TimeInterval = 0
    var returned: [Date] = []
    let defaults = UserDefaults(suiteName: "PomodoroTests-\(UUID())")!
    let timer = PomodoroTimer(onPhaseEnd: { _ in }, idleSeconds: { idle }, defaults: defaults)
    timer.onIdleReturn = { returned.append($0) }
    let min = 60.0

    timer.start(now: t0)
    idle = 4 * min
    timer.tick(now: t0 + 8 * min)
    #expect(timer.running, "under the threshold")
    idle = 6 * min
    timer.tick(now: t0 + 10 * min)
    #expect(!timer.running)
    #expect(timer.idleSince == t0 + 4 * min)
    #expect(timer.remaining == 21 * 60, "rewound to when idleness began")
    #expect(timer.label(now: t0 + 10 * min) == "🍅 21:00 ⏸6m")

    idle = 0
    timer.tick(now: t0 + 12 * min)
    #expect(returned == [t0 + 4 * min])
    #expect(timer.idleSince == nil)
    timer.tick(now: t0 + 12 * min)
    #expect(returned.count == 1, "asks once")

    timer.resume(afterIdleSince: t0 + 4 * min, countIt: true, now: t0 + 12 * min)
    #expect(timer.running)
    #expect(timer.remaining == 13 * 60, "8 idle minutes counted as work")
}

@Test func idleDuringBreakIsIgnored() {
    var idle: TimeInterval = 10 * 60
    let defaults = UserDefaults(suiteName: "PomodoroTests-\(UUID())")!
    let timer = PomodoroTimer(onPhaseEnd: { _ in }, idleSeconds: { idle }, defaults: defaults)
    timer.skip(now: t0)
    #expect(timer.phase == .shortBreak)
    timer.start(now: t0)
    timer.tick(now: t0 + 60)
    #expect(timer.running)
    #expect(timer.remaining == 4 * 60)
    _ = idle
}

@Test func skippingWorkDoesNotCountAsASession() {
    let (timer, _) = makeTimer()
    timer.start(now: t0)
    timer.tick(now: t0 + 600)
    timer.skip(now: t0 + 600)
    #expect(timer.phase == .shortBreak)
    #expect(timer.sessions(today: t0) == 0)
    timer.skip(now: t0 + 600)
    #expect(timer.phase == .work)
    #expect(timer.sessions(today: t0) == 0)
}
