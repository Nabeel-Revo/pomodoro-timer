import Testing
@testable import Pomodoro

@Test func pausedTimerDoesNotCountDown() {
    let timer = PomodoroTimer(onPhaseEnd: { _ in })
    timer.tick()
    #expect(timer.remaining == PomodoroTimer.durations[.work])
}

@Test func fourWorkSessionsThenLongBreak() {
    var ended: [Phase] = []
    let timer = PomodoroTimer(onPhaseEnd: { ended.append($0) })
    for session in 1...4 {
        #expect(timer.phase == .work)
        timer.toggle()
        for _ in 0..<PomodoroTimer.durations[.work]! { timer.tick() }
        #expect(timer.phase == (session == 4 ? .longBreak : .shortBreak))
        #expect(!timer.running, "next phase waits for Start")
        #expect(timer.completedSessions == session)
        timer.skip()
    }
    #expect(ended == [.work, .work, .work, .work], "skip must not notify")
}

@Test func resetRestoresCurrentPhaseDuration() {
    let timer = PomodoroTimer(onPhaseEnd: { _ in })
    timer.toggle()
    timer.tick()
    timer.reset()
    #expect(timer.remaining == PomodoroTimer.durations[.work])
    #expect(!timer.running)
}
