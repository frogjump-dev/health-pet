import XCTest
@testable import PetCore

/// The rules added with PRD v0.2 (2026-11-08): weekend bedtimes, the pet's slow energy,
/// the achievement ledger and the share card's identity title.
final class PRDv02Tests: XCTestCase {
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

    private func snapshot(_ offset: Int, steps: Int? = nil, workout: Double? = nil, asleep: Date? = nil,
                          sleep: Double? = nil, hrv: Double? = nil) -> HealthSnapshot {
        HealthSnapshot(day: day(offset), source: .healthKit, steps: steps, sleepHours: sleep, hrvMs: hrv,
                       hrvMethod: hrv == nil ? nil : .sdnn, sleepOnset: asleep, workoutMinutes: workout,
                       workoutType: workout == nil ? nil : "Run",
                       workouts: workout.map { [WorkoutSession(name: "Run", minutes: $0)] })
    }

    // MARK: - Half-hour and weekend bedtimes

    func testWeekendBedtimeAppliesToFridayAndSaturdayNights() {
        var weekend = tracker
        weekend.weekendBedtime = Bedtime(hour: 0, minute: 30)
        // Friday night → Saturday morning (day 5): 00:50 is on time with a 00:30 weekend target
        XCTAssertEqual(weekend.isOnTimeNight(snapshot(5, asleep: onset(5, 0, 50))), true)
        XCTAssertEqual(tracker.isOnTimeNight(snapshot(5, asleep: onset(5, 0, 50))), false)
        // Saturday night → Sunday morning (day 6) too
        XCTAssertEqual(weekend.isOnTimeNight(snapshot(6, asleep: onset(6, 0, 50))), true)
        // Sunday night → Monday morning (day 7) is a school night again
        XCTAssertEqual(weekend.isOnTimeNight(snapshot(7, asleep: onset(7, 0, 50))), false)
        XCTAssertEqual(weekend.target(forNightEnding: day(7)), onset(7, 23))
    }

    func testHalfHourBedtime() {
        let half = DisciplineTracker(bedtime: Bedtime(hour: 22, minute: 30), calendar: calendar)
        XCTAssertEqual(half.isOnTimeNight(snapshot(1, asleep: onset(1, 23, 0))), true)
        XCTAssertEqual(half.isOnTimeNight(snapshot(1, asleep: onset(1, 23, 1))), false)
    }

    // MARK: - The pet's slow energy

    private func week(nights: Int, workouts: Int, hrv: Double, sleep: Double) -> [HealthSnapshot] {
        // days -7...0: nights from the 7 snapshots ending today, workouts from the 7 days before today
        (-7...0).map { i in
            let nightIndex = i + 6 // 0...6 for days -6...0
            let onTime = nightIndex >= 0 && nightIndex < nights
            let workoutIndex = i + 7 // 0...6 for days -7...-1
            let worked = i < 0 && workoutIndex < workouts
            return snapshot(i, steps: 4_000, workout: worked ? 30 : nil,
                            asleep: onTime ? onset(i, 22, 45) : onset(i, 1, 30), sleep: sleep, hrv: hrv)
        }.map { s in
            var s = s
            s.day = calendar.date(byAdding: .day, value: 14, to: s.day)!
            if let onset = s.sleepOnset { s.sleepOnset = calendar.date(byAdding: .day, value: 14, to: onset) }
            return s
        }
    }

    func testEnergyTiers() {
        let today = day(14)
        let good = week(nights: 6, workouts: 4, hrv: 55, sleep: 8)
        XCTAssertEqual(EnergyMeter.energy(snapshots: good, today: today, tracker: tracker), .lively)

        let middling = week(nights: 3, workouts: 2, hrv: 50, sleep: 7)
        XCTAssertEqual(EnergyMeter.energy(snapshots: middling, today: today, tracker: tracker), .normal)

        let flat = week(nights: 0, workouts: 0, hrv: 40, sleep: 5)
        XCTAssertEqual(EnergyMeter.energy(snapshots: flat, today: today, tracker: tracker), .low)

        XCTAssertEqual(EnergyMeter.energy(snapshots: [], today: today, tracker: tracker), .normal,
                       "no data is never low")
    }

    func testTodaysWorkoutDoesNotMoveTheTierDuringTheDay() {
        let today = day(14)
        var days = week(nights: 3, workouts: 2, hrv: 50, sleep: 7)
        let before = EnergyMeter.score(snapshots: days, today: today, tracker: tracker)
        days[days.count - 1].workoutMinutes = 60
        days[days.count - 1].workouts = [WorkoutSession(name: "Run", minutes: 60)]
        XCTAssertEqual(EnergyMeter.score(snapshots: days, today: today, tracker: tracker), before)
    }

    func testLeaveDaysCountAsOnTimeNightsForEnergy() {
        let today = day(14)
        let days = week(nights: 4, workouts: 3, hrv: 50, sleep: 7.5)
        let without = EnergyMeter.score(snapshots: days, today: today, tracker: tracker)!
        let with = EnergyMeter.score(snapshots: days, today: today, tracker: tracker,
                                     leaveDays: [day(13)])!
        XCTAssertGreaterThan(with, without)
    }

    // MARK: - Ledger

    func testLedgerCollectsWeeksMonthsUnlocksAndMilestones() {
        var log: [Date: Set<Activity>] = [:]
        // 30 on-time nights from day 0; a run every day for 12 days from day 0
        for i in 0..<30 { log[day(i), default: []].insert(.onTimeSleep) }
        for i in 0..<12 { log[day(i), default: []].insert(.running) }
        // weeks 0, 1 and 3 counted (a monthly achievement on the third), plus this week (week 4) so far
        let weeks: Set<Date> = [day(0), day(7), day(21)]
        let entries = Ledger.entries(log: log, disciplinedWeeks: weeks, currentWeekDone: true,
                                     adoptedOn: day(0), today: day(30), memories: [], tracker: tracker)
        let kinds = entries.map(\.kind)

        XCTAssertTrue(kinds.contains(.disciplinedWeek(1)))
        XCTAssertTrue(kinds.contains(.disciplinedWeek(4)))
        XCTAssertEqual(entries.first { $0.kind == .disciplinedWeek(4) }?.day, day(30), "this week is dated today")
        XCTAssertEqual(entries.first { $0.kind == .monthlyAchievement(1) }?.day, day(27))
        XCTAssertFalse(kinds.contains(.monthlyAchievement(2)))
        XCTAssertEqual(entries.first { $0.kind == .unlocked(.running) }?.day, day(0))
        XCTAssertEqual(entries.first { $0.kind == .onTimeNights(30) }?.day, day(29))
        XCTAssertEqual(entries.first { $0.kind == .daysTogether(30) }?.day, day(30))
        // running: 12 days in counted weeks = 24 XP, well short of Lv 10 (55 XP)
        XCTAssertFalse(kinds.contains(.level(.running, 10)))
        // newest first
        XCTAssertEqual(entries.map(\.day), entries.map(\.day).sorted(by: >))
    }

    func testLedgerLevelMilestoneUsesTheDoubleWeeks() {
        var log: [Date: Set<Activity>] = [:]
        for i in 0..<28 { log[day(i)] = [.yoga] }
        // weeks 0-3 all counted: 28 days × 2 = 56 XP, Lv 10 (55 XP) on day 27 (the 28th session)
        let weeks: Set<Date> = [day(0), day(7), day(14), day(21)]
        let entries = Ledger.entries(log: log, disciplinedWeeks: weeks, currentWeekDone: false,
                                     adoptedOn: day(0), today: day(28), memories: [], tracker: tracker)
        XCTAssertEqual(entries.first { $0.kind == .level(.yoga, 10) }?.day, day(27))
        XCTAssertTrue(entries.contains { $0.kind == .monthlyAchievement(1) })
    }

    func testLedgerKeepsTheFirstTwentyKStepDay() {
        let memory = MemoryEvent(kind: .firstTwentyKSteps, day: day(3), title: "Our first 20k-step day")
        let entries = Ledger.entries(log: [:], disciplinedWeeks: [], currentWeekDone: false,
                                     adoptedOn: day(0), today: day(5), memories: [memory], tracker: tracker)
        XCTAssertEqual(entries.map(\.kind), [.firstTwentyKSteps])
    }

    // MARK: - Share identity

    private func progress(_ pairs: [(Activity, Int)]) -> [Activity: ActivityProgress] {
        var result = Dictionary(uniqueKeysWithValues: Activity.allCases.map {
            ($0, ActivityProgress(activity: $0, sessions: 0, experience: 0, unlockedOn: nil))
        })
        for (activity, xp) in pairs {
            result[activity] = ActivityProgress(activity: activity, sessions: xp, experience: xp, unlockedOn: monday)
        }
        return result
    }

    func testIdentityTitle() {
        let p = progress([(.running, 120), (.yoga, 15), (.onTimeSleep, 400), (.balancedStreak, 300)])
        XCTAssertEqual(ShareIdentity.title(progress: p, mainActivity: nil, onTimeNightsThisWeek: 5), "Early-to-bed Runner")
        XCTAssertEqual(ShareIdentity.title(progress: p, mainActivity: nil, onTimeNightsThisWeek: 4), "Runner",
                       "the qualifier needs 5 on-time nights")
        XCTAssertEqual(ShareIdentity.title(progress: progress([(.onTimeSleep, 40)]), mainActivity: nil,
                                           onTimeNightsThisWeek: 6), "Early Bird", "no sport pet yet")
    }

    func testIdentityTieGoesToTheMainPet() {
        let p = progress([(.running, 15), (.cycling, 16)]) // both Lv 5
        XCTAssertEqual(ShareIdentity.topSport(progress: p, mainActivity: .running), .running)
        XCTAssertEqual(ShareIdentity.topSport(progress: p, mainActivity: nil), .cycling)
        XCTAssertEqual(ShareIdentity.topSport(progress: p, mainActivity: .yoga), .cycling)
    }
}
