import XCTest
@testable import PetCore

final class ActivityTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2 // Monday
        return c
    }()
    private lazy var tracker = ActivityTracker(
        discipline: DisciplineTracker(bedtime: Bedtime(hour: 23), calendar: calendar),
        wakeTarget: WakeTime(hour: 7))

    /// Monday 2026-10-26, 00:00 UTC.
    private let monday = Date(timeIntervalSince1970: 1_792_972_800)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: monday)!
    }

    private func at(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(offset))!
    }

    func testLevelsAreTriangular() {
        XCTAssertEqual(PetLevel.level(forExperience: 0), 0)
        XCTAssertEqual(PetLevel.level(forExperience: 1), 1)
        XCTAssertEqual(PetLevel.level(forExperience: 2), 1)
        XCTAssertEqual(PetLevel.level(forExperience: 3), 2)
        XCTAssertEqual(PetLevel.level(forExperience: 15), 5)
        XCTAssertEqual(PetLevel.level(forExperience: 55), 10)
        XCTAssertEqual(PetLevel.level(forExperience: 209), 19)
        XCTAssertEqual(PetLevel.level(forExperience: 210), 20)
    }

    func testWorkoutNamesMapToActivities() {
        XCTAssertEqual(Activity(workoutName: "Run"), .running)
        XCTAssertEqual(Activity(workoutName: "Ride"), .cycling)
        XCTAssertEqual(Activity(workoutName: "Tennis"), .ballSports)
        XCTAssertEqual(Activity(workoutName: "Elliptical"), .other)
    }

    func testDayCountsForEachActivityOnce() {
        let snapshot = HealthSnapshot(
            day: day(1), source: .healthKit, steps: 10_500,
            sleepOnset: at(0, 22, 50),
            workouts: [.init(name: "Run", minutes: 25), .init(name: "Run", minutes: 30),
                       .init(name: "Yoga", minutes: 15), .init(name: "Mind", minutes: 10)],
            wakeTime: at(1, 6, 55), mindfulMinutes: 4)
        XCTAssertEqual(tracker.activities(on: snapshot),
                       [.walking, .onTimeSleep, .earlyRise, .running, .mindfulness],
                       "yoga under 20 min doesn't count")
    }

    func testOldSnapshotsUseTheLongestWorkout() {
        let old = HealthSnapshot(day: day(0), source: .healthKit, workoutMinutes: 40, workoutType: "Swim")
        XCTAssertEqual(tracker.activities(on: old), [.swimming])
    }

    func testLateWakeIsNotEarly() {
        let late = HealthSnapshot(day: day(0), source: .healthKit, wakeTime: at(0, 7, 1))
        XCTAssertFalse(tracker.activities(on: late).contains(.earlyRise))
    }

    func testDisciplinedWeeksDoubleExperience() {
        let log: [Date: Set<Activity>] = [
            day(-6): [.running],   // last week, a 自律周
            day(0): [.running],
            day(2): [.running, .yoga],
        ]
        let weekStart = { (d: Date) in self.calendar.dateInterval(of: .weekOfYear, for: d)!.start }
        let progress = ActivityProgress.all(log: log, disciplinedWeeks: [day(-7)], weekStart: weekStart)

        XCTAssertEqual(progress[.running]?.sessions, 3)
        XCTAssertEqual(progress[.running]?.experience, 4)
        XCTAssertEqual(progress[.running]?.level, 2)
        XCTAssertEqual(progress[.running]?.unlockedOn, day(-6))
        XCTAssertEqual(progress[.yoga]?.level, 1)
        XCTAssertFalse(progress[.swimming]!.isUnlocked)
        XCTAssertEqual(progress[.swimming]?.level, 0)
    }

    func testWhoopSleepNeed() {
        let full = HealthSnapshot(day: day(0), source: .whoop, strain: 14.2, sleepPerformance: 85)
        XCTAssertTrue(tracker.activities(on: full).contains(.sleepNeedMet))
        let short = HealthSnapshot(day: day(0), source: .whoop, strain: 13.9, sleepPerformance: 84)
        XCTAssertFalse(tracker.activities(on: short).contains(.sleepNeedMet))
    }

    func testAHardDayAloneIsNoLongerAProteinBar() {
        let hard = HealthSnapshot(day: day(0), source: .whoop, vendorRecovery: 20, strain: 18)
        XCTAssertFalse(tracker.activities(on: hard).contains(.balancedStreak))
    }

    func testTwoBalancedDaysInARowCountOnce() {
        // a run of 5 balanced days (Mon-Fri), a gap, then 1 more (Sun): pairs end on Tue and Thu
        var log: [Date: Set<Activity>] = [:]
        for offset in [0, 1, 2, 3, 4, 6] { log[day(offset)] = [.recoveryMatch] }
        log[day(5)] = [.running]
        let streaks = tracker.withBalancedStreaks(log)
        let pairs = streaks.filter { $0.value.contains(.balancedStreak) }.keys.sorted()
        XCTAssertEqual(pairs, [day(1), day(3)])
        XCTAssertEqual(streaks[day(5)], [.running])
        XCTAssertNil(tracker.log([], today: day(0))[day(0)])
    }

    func testWeekendWakeTarget() {
        var weekend = tracker
        weekend.weekendWakeTarget = WakeTime(hour: 9)
        let saturdayLieIn = HealthSnapshot(day: day(5), source: .healthKit, wakeTime: at(5, 8, 30))
        XCTAssertTrue(weekend.activities(on: saturdayLieIn).contains(.earlyRise))
        XCTAssertFalse(tracker.activities(on: saturdayLieIn).contains(.earlyRise))
        let mondayLate = HealthSnapshot(day: day(0), source: .healthKit, wakeTime: at(0, 8, 30))
        XCTAssertFalse(weekend.activities(on: mondayLate).contains(.earlyRise))
    }

    func testStrainMustFitRecovery() {
        XCTAssertTrue(tracker.strainMatchesRecovery(recovery: 80, strain: 12))
        XCTAssertFalse(tracker.strainMatchesRecovery(recovery: 80, strain: 6))
        XCTAssertTrue(tracker.strainMatchesRecovery(recovery: 50, strain: 8))
        XCTAssertFalse(tracker.strainMatchesRecovery(recovery: 50, strain: 15))
        XCTAssertTrue(tracker.strainMatchesRecovery(recovery: 20, strain: 6), "resting on a red day counts")
        XCTAssertFalse(tracker.strainMatchesRecovery(recovery: 20, strain: 12))
    }

    func testRecoveryMatchWaitsForTheDayToEnd() {
        let red = HealthSnapshot(day: day(2), source: .whoop, vendorRecovery: 20, strain: 4)
        XCTAssertNil(tracker.log([red], today: day(2))[day(2)])
        XCTAssertEqual(tracker.log([red], today: day(3))[day(2)], [.recoveryMatch])
    }

    func testWhoopActivitiesAreFlagged() {
        XCTAssertEqual(Activity.allCases.filter(\.isWhoopOnly), [.recoveryMatch, .sleepNeedMet, .balancedStreak])
        XCTAssertFalse(Activity.allCases.contains { $0.isWhoopOnly && $0.isWorkout })
        XCTAssertFalse(Activity.onTimeSleep.isWorkout)
        XCTAssertTrue(Activity.walking.isWorkout)
    }
}
