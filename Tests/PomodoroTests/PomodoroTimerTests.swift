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
