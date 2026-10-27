import XCTest
@testable import PetCore

final class PetStateEngineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let engine = PetStateEngine()

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: Date(timeIntervalSince1970: 1_790_000_000))!
    }

    /// 14 ordinary days: 7.5h sleep, HRV 50 (SDNN), RHR 60, 8k steps.
    private func normalHistory() -> [HealthSnapshot] {
        (1...14).map {
            HealthSnapshot(day: day(-$0), source: .healthKit, steps: 8_000, sleepHours: 7.5,
                           hrvMs: 50, hrvMethod: .sdnn, restingHeartRate: 60)
        }
    }

    func testNormalDayIsGolden() {
        let today = HealthSnapshot(day: day(0), source: .healthKit, steps: 8_000, sleepHours: 7.5,
                                   hrvMs: 50, hrvMethod: .sdnn, restingHeartRate: 60)
        let state = engine.evaluate(today: today, history: normalHistory())
        XCTAssertEqual(state.mood, .golden)
        XCTAssertEqual(state.activity, 1, accuracy: 0.001)
    }

    func testShortSleepIsBurnt() {
        var history = normalHistory()
        history[0].sleepHours = 5
        history[1].sleepHours = 5
        let today = HealthSnapshot(day: day(0), source: .healthKit, sleepHours: 5,
                                   hrvMs: 50, hrvMethod: .sdnn, restingHeartRate: 60)
        let state = engine.evaluate(today: today, history: history)
        XCTAssertEqual(state.mood, .burnt)
        XCTAssertGreaterThan(state.sleepDebt, 0.25)
    }

    func testLowHRVIsSoggy() {
        let today = HealthSnapshot(day: day(0), source: .healthKit, sleepHours: 7.5,
                                   hrvMs: 30, hrvMethod: .sdnn, restingHeartRate: 68)
        XCTAssertEqual(engine.evaluate(today: today, history: normalHistory()).mood, .soggy)
    }

    func testHighHRVIsFresh() {
        let today = HealthSnapshot(day: day(0), source: .healthKit, sleepHours: 8,
                                   hrvMs: 68, hrvMethod: .sdnn, restingHeartRate: 55)
        XCTAssertEqual(engine.evaluate(today: today, history: normalHistory()).mood, .fresh)
    }

    func testWhoopRecoveryIsUsedDirectly() {
        let today = HealthSnapshot(day: day(0), source: .whoop, sleepHours: 7.5, vendorRecovery: 90)
        let state = engine.evaluate(today: today, history: normalHistory())
        XCTAssertEqual(state.energy, 0.9, accuracy: 0.001)
        XCTAssertEqual(state.mood, .fresh)
    }

    func testBaselineDoesNotMixHRVMethods() {
        let baseline = PersonalBaseline.from(history: normalHistory(), before: day(0), hrvMethod: .rmssd)
        XCTAssertNil(baseline.hrvMs)
    }

    func testStepsOnlyUserStillGetsAState() {
        let today = HealthSnapshot(day: day(0), source: .healthKit, steps: 3_000)
        let state = engine.evaluate(today: today, history: [])
        XCTAssertEqual(state.mood, .golden)
        XCTAssertEqual(state.activity, 0.5, accuracy: 0.001)
    }

    func testFirstTwentyKStepsMemoryOnlyOnce() {
        let today = HealthSnapshot(day: day(0), source: .healthKit, steps: 21_000)
        let rule = FirstTwentyKStepsRule()
        let first = rule.check(today: today, history: [], adoptedOn: day(-3), existing: [])
        XCTAssertNotNil(first)
        XCTAssertNil(rule.check(today: today, history: [], adoptedOn: day(-3), existing: [first!]))
    }

    func testThirtyDayAnniversary() {
        let rule = AnniversaryRule(calendar: calendar)
        let today = HealthSnapshot(day: day(0), source: .healthKit)
        XCTAssertEqual(rule.check(today: today, history: [], adoptedOn: day(-30), existing: [])?.kind, .anniversary)
        XCTAssertNil(rule.check(today: today, history: [], adoptedOn: day(-29), existing: []))
    }
}
