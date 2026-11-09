import XCTest
@testable import PetCore

/// 点击 = 入账 (PRD v0.2 §4.4): pending credits, the 04:00 auto-booking, and how the week and
/// the pets only see what was booked.
final class CreditsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2 // Monday
        return c
    }()
    private lazy var tracker = DisciplineTracker(bedtime: Bedtime(hour: 23), calendar: calendar)
    private lazy var rules = CreditRules(discipline: tracker)

    /// Monday 2026-10-26, 00:00 UTC.
    private let monday = Date(timeIntervalSince1970: 1_792_972_800)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: monday)!
    }

    private func at(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(offset))!
    }

    private func snapshot(_ offset: Int, steps: Int? = nil, workouts: [WorkoutSession] = [], asleep: Date? = nil,
                          strain: Double? = nil) -> HealthSnapshot {
        let longest = workouts.max { $0.minutes < $1.minutes }
        return HealthSnapshot(day: day(offset), source: .healthKit, steps: steps, sleepOnset: asleep,
                              workoutMinutes: longest?.minutes, workoutType: longest?.name, workouts: workouts,
                              wakeTime: asleep.map { $0.addingTimeInterval(8 * 3600) }, strain: strain)
    }

    func testADayHasOneCreditPerBubble() {
        let day = snapshot(3, steps: 10_400,
                           workouts: [WorkoutSession(name: "Run", minutes: 32), WorkoutSession(name: "Swim", minutes: 25),
                                      WorkoutSession(name: "Yoga", minutes: 12), WorkoutSession(name: "Mind", minutes: 20)],
                           asleep: at(2, 22, 48), strain: 11.4)
        let credits = rules.credits(on: day)
        XCTAssertEqual(credits.map(\.key), ["workout:Run:32", "workout:Swim:25", "steps", "night", "load"])
        // under 10k steps: no steps bubble; no sleep: no moon
        XCTAssertEqual(rules.credits(on: snapshot(3, steps: 9_999)).count, 0)
    }

    func testTwoIdenticalWorkoutsKeepApartKeys() {
        let keys = rules.workoutKeys([WorkoutSession(name: "Run", minutes: 30), WorkoutSession(name: "Run", minutes: 30)])
        XCTAssertEqual(keys, ["workout:Run:30", "workout:Run:30#2"])
    }

    func testUntappedCreditsAreBookedAtFourTheNextMorning() {
        XCTAssertEqual(rules.autoBookTime(for: day(3)), at(4, 4))
        let days = [snapshot(3, steps: 12_000)]
        XCTAssertEqual(rules.pending(in: days, booked: [], now: at(3, 20)).count, 1)
        // still Thursday's bubble at 01:00 on Friday
        XCTAssertEqual(rules.pending(in: days, booked: [], now: at(4, 1)).count, 1)
        XCTAssertEqual(rules.pending(in: days, booked: [], now: at(4, 4)).count, 0)
        XCTAssertEqual(rules.due(in: days, booked: [], now: at(4, 4), since: day(0)).map(\.key), ["steps"])
        // a tapped one is never due again; days before `since` get no ledger line
        let id = rules.credits(on: days[0])[0].id
        XCTAssertEqual(rules.due(in: days, booked: [id], now: at(4, 5), since: day(0)).count, 0)
        XCTAssertEqual(rules.due(in: days, booked: [], now: at(4, 5), since: day(4)).count, 0)
    }

    func testPendingDataDoesNotCountYet() {
        let run = WorkoutSession(name: "Run", minutes: 32)
        let today = snapshot(3, steps: 10_500, workouts: [run, WorkoutSession(name: "Yoga", minutes: 10)], asleep: at(2, 22, 50))
        let pending = rules.pending(in: [today], booked: [], now: at(3, 9))
        let booked = rules.booked(today, pending: pending)
        XCTAssertFalse(tracker.countsAsWorkout(booked))
        XCTAssertNil(tracker.isOnTimeNight(booked))
        XCTAssertEqual(booked.allWorkouts.map(\.name), ["Yoga"])
        XCTAssertEqual(booked.steps, 9_999)
        let activities = ActivityTracker(discipline: tracker, wakeTarget: WakeTime(hour: 7))
        XCTAssertEqual(activities.activities(on: booked, dayIsOver: false), [])

        // tapping the run: the day counts as a workout, Chili gets it, the night still waits
        let runID = pending.first { $0.kind == .workout }!.id
        let afterRun = rules.booked(today, pending: rules.pending(in: [today], booked: [runID], now: at(3, 9)))
        XCTAssertTrue(tracker.countsAsWorkout(afterRun))
        XCTAssertEqual(activities.activities(on: afterRun, dayIsOver: false), [.running])

        // everything tapped (or 04:00 passed): the day is the day
        let all = Set(pending.map(\.id))
        XCTAssertEqual(rules.booked(today, pending: rules.pending(in: [today], booked: all, now: at(3, 9))), today)
        XCTAssertEqual(rules.booked(today, pending: rules.pending(in: [today], booked: [], now: at(4, 4))), today)
    }

    func testTheWeekOnlySeesBookedNights() {
        let days = (0...3).map { snapshot($0, asleep: at($0 - 1, 22, 30)) }
        let pending = rules.pending(in: days, booked: [], now: at(3, 8))
        XCTAssertEqual(pending.map(\.key), ["night"])
        let week = tracker.week(containing: at(3, 8), snapshots: rules.booked(days, pending: pending))
        XCTAssertEqual(week.onTimeNights, 3)
        let tapped = tracker.week(containing: at(3, 8), snapshots: rules.booked(days, pending: rules.pending(in: days, booked: Set(pending.map(\.id)), now: at(3, 8))))
        XCTAssertEqual(tapped.onTimeNights, 4)
    }

    func testWorkoutDistanceSurvivesSaving() throws {
        let saved = try JSONEncoder().encode(WorkoutSession(name: "Run", minutes: 32, distanceKm: 5.1))
        XCTAssertEqual(try JSONDecoder().decode(WorkoutSession.self, from: saved).distanceKm, 5.1)
        // sessions saved before distances were read still load
        let old = Data(#"{"name":"Run","minutes":30}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(WorkoutSession.self, from: old).distanceKm)
    }
}
