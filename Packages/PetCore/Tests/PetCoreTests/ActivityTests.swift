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
}
