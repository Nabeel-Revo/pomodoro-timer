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
