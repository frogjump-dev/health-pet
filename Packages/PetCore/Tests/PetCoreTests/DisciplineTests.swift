import XCTest
@testable import PetCore

final class DisciplineTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2 // Monday
        return c
    }()
    private lazy var tracker = DisciplineTracker(bedtime: Bedtime(hour: 23), calendar: calendar)

    /// Monday 2026-10-26, 00:00 UTC.
    private let monday = Date(timeIntervalSince1970: 1_792_972_800)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: monday)!
    }

    /// Asleep at `hour:minute` on the evening before `day(offset)` (hours < 12 = after midnight).
    private func onset(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let base = hour >= 12 ? day(offset - 1) : day(offset)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    private func snapshot(_ offset: Int, steps: Int? = nil, workout: Double? = nil, asleep: Date? = nil) -> HealthSnapshot {
        HealthSnapshot(day: day(offset), source: .healthKit, steps: steps, sleepOnset: asleep, workoutMinutes: workout)
    }

    func testWorkoutIsTwentyMinutesOrTenThousandSteps() {
        XCTAssertTrue(tracker.countsAsWorkout(snapshot(0, workout: 20)))
        XCTAssertFalse(tracker.countsAsWorkout(snapshot(0, steps: 9_999, workout: 19)))
        XCTAssertTrue(tracker.countsAsWorkout(snapshot(0, steps: 10_000)))
    }

    func testOnTimeIsNoLaterThanBedtimePlusThirtyMinutes() {
        XCTAssertEqual(tracker.isOnTimeNight(snapshot(1, asleep: onset(1, 23, 30))), true)
        XCTAssertEqual(tracker.isOnTimeNight(snapshot(1, asleep: onset(1, 23, 31))), false)
        XCTAssertEqual(tracker.isOnTimeNight(snapshot(1, asleep: onset(1, 21, 0))), true, "early is always fine")
        XCTAssertEqual(tracker.isOnTimeNight(snapshot(1, asleep: onset(1, 0, 40))), false)
        XCTAssertNil(tracker.isOnTimeNight(snapshot(1)))
    }

    func testAfterMidnightBedtime() {
        let late = DisciplineTracker(bedtime: Bedtime(hour: 0, minute: 30), calendar: calendar)
        XCTAssertEqual(late.isOnTimeNight(snapshot(1, asleep: onset(1, 0, 55))), true)
        XCTAssertEqual(late.isOnTimeNight(snapshot(1, asleep: onset(1, 1, 5))), false)
    }

    func testWeekNeedsThreeWorkoutsAndFiveNights() {
        var days = (0..<7).map { snapshot($0, asleep: onset($0, 22, 50)) }
        days[0].workoutMinutes = 30
        days[2].steps = 12_000
        var week = tracker.week(containing: day(3), snapshots: days)
        XCTAssertEqual(week.workouts, 2)
        XCTAssertEqual(week.onTimeNights, 7)
        XCTAssertFalse(week.isDisciplined)

        days[4].workoutMinutes = 45
        week = tracker.week(containing: day(3), snapshots: days)
        XCTAssertTrue(week.isDisciplined)
        XCTAssertEqual(week.weekStart, monday)
    }

    func testOneLeaveDayCountsAsOnTimeNight() {
        var days = (0..<7).map { snapshot($0, workout: 25) }
        for i in 0..<4 { days[i].sleepOnset = onset(i, 23) }
        let leave: Set<Date> = [day(5), day(6)]
        let week = tracker.week(containing: day(0), snapshots: days, leaveDays: leave)
        XCTAssertEqual(week.onTimeNights, 5, "only one leave day a week counts")
        XCTAssertTrue(week.isDisciplined)
    }

    func testStreakAndFinishedWeeks() {
        let lastWeek = (-7..<0).map { snapshot($0, workout: 30, asleep: onset($0, 23)) }
        var thisWeek = (0..<3).map { snapshot($0, asleep: onset($0, 23)) }
        thisWeek[0].sleepOnset = onset(0, 1)
        let all = lastWeek + thisWeek

        XCTAssertEqual(tracker.onTimeStreak(all), 2)
        XCTAssertEqual(tracker.disciplinedWeeks(in: all, before: day(2)), [day(-7)])
    }
}
