import XCTest
@testable import PetCore

final class DailyMetricsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    /// Monday 2026-10-26, 00:00 UTC.
    private let day = Date(timeIntervalSince1970: 1_792_972_800)
    private let normal = PersonalBaseline(sleepHours: 8, hrvMs: 50, hrvMethod: .sdnn, sampleCount: 20)

    private func snapshot(hrv: Double? = nil, sleep: Double? = nil, recovery: Double? = nil, strain: Double? = nil,
                          kcal: Double? = nil, workout: Double? = nil, onset: Date? = nil) -> HealthSnapshot {
        HealthSnapshot(day: day, source: .healthKit, sleepHours: sleep, hrvMs: hrv, hrvMethod: hrv == nil ? nil : .sdnn,
                       vendorRecovery: recovery, sleepOnset: onset, workoutMinutes: workout, workoutType: workout == nil ? nil : "Run",
                       strain: strain, activeEnergyKcal: kcal)
    }

    func testWhoopStrainIsTheLoadWhenThereIsOne() {
        XCTAssertEqual(DailyMetrics.dailyLoad(snapshot(strain: 12.3, kcal: 2_000)), 12.3)
    }

    func testEstimatedLoadRisesAndFlattensBelowTwentyOne() {
        XCTAssertNil(DailyMetrics.estimatedLoad(activeKcal: nil, workoutMinutes: 0))
        let light = DailyMetrics.estimatedLoad(activeKcal: 412, workoutMinutes: 32)!
        let big = DailyMetrics.estimatedLoad(activeKcal: 1_000, workoutMinutes: 0)!
        let huge = DailyMetrics.estimatedLoad(activeKcal: 3_000, workoutMinutes: 120)!
        XCTAssertEqual(light, 9.1, accuracy: 0.3)
        XCTAssertEqual(big, 14.0, accuracy: 0.3)
        XCTAssertLessThan(huge, DailyMetrics.maxLoad)
        XCTAssertLessThan(light, big)
        XCTAssertLessThan(big, huge)
    }

    func testAppleHealthLoadUsesEnergyAndWorkouts() {
        let load = DailyMetrics.dailyLoad(snapshot(kcal: 412, workout: 32))
        XCTAssertEqual(load!, 9.1, accuracy: 0.3)
        XCTAssertNil(DailyMetrics.dailyLoad(snapshot()))
    }

    func testWhoopRecoveryWinsOverTheEstimate() {
        XCTAssertEqual(DailyMetrics.recovery(snapshot(hrv: 20, sleep: 3, recovery: 81), baseline: normal), 81)
    }

    func testEstimatedRecoveryFromHRVAndSleep() {
        // a usual HRV and a nearly full night: about two thirds
        let usual = DailyMetrics.recovery(snapshot(hrv: 50, sleep: 7.5), baseline: normal)!
        XCTAssertEqual(usual, 67.5, accuracy: 0.5)
        // well above usual and a full night: full
        XCTAssertEqual(DailyMetrics.recovery(snapshot(hrv: 70, sleep: 8), baseline: normal)!, 100, accuracy: 0.01)
        // well below usual and a short night: low, never below zero
        let low = DailyMetrics.recovery(snapshot(hrv: 30, sleep: 4), baseline: normal)!
        XCTAssertLessThan(low, 25)
        XCTAssertGreaterThanOrEqual(low, 0)
    }

    func testRecoveryWithoutEnoughHistoryFallsBackToSleep() {
        let fresh = PersonalBaseline(hrvMs: 50, hrvMethod: .sdnn, sampleCount: 2)
        XCTAssertEqual(DailyMetrics.recovery(snapshot(hrv: 50, sleep: 8), baseline: fresh)!, 80, accuracy: 0.01)
        XCTAssertNil(DailyMetrics.recovery(snapshot(hrv: 50), baseline: fresh))
    }

    func testHRVFillComparesWithTheUsersOwnNormal() {
        XCTAssertEqual(DailyMetrics.hrvFill(snapshot(hrv: 50), baseline: normal)!, 1 / 1.4, accuracy: 0.001)
        XCTAssertEqual(DailyMetrics.hrvFill(snapshot(hrv: 90), baseline: normal), 1)
        XCTAssertNil(DailyMetrics.hrvFill(snapshot(), baseline: normal))
        // never mixes SDNN with RMSSD
        let whoopNormal = PersonalBaseline(hrvMs: 80, hrvMethod: .rmssd, sampleCount: 20)
        XCTAssertEqual(DailyMetrics.hrvFill(snapshot(hrv: 50), baseline: whoopNormal), 0.7)
    }

    func testOnsetFillIsFullOnTimeAndEmptiesWhenLate() {
        let tracker = DisciplineTracker(bedtime: Bedtime(hour: 23), calendar: calendar)
        let evening = calendar.date(byAdding: .day, value: -1, to: day)!
        func asleep(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: hour >= 12 ? evening : day)!
        }
        XCTAssertEqual(DailyMetrics.onsetFill(snapshot(onset: asleep(22, 48)), tracker: tracker), 1)
        XCTAssertEqual(DailyMetrics.onsetFill(snapshot(onset: asleep(23, 25)), tracker: tracker), 1)
        XCTAssertEqual(DailyMetrics.onsetFill(snapshot(onset: asleep(0, 45)), tracker: tracker)!, 0.5, accuracy: 0.001)
        XCTAssertEqual(DailyMetrics.onsetFill(snapshot(onset: asleep(4, 0)), tracker: tracker), 0.08)
        XCTAssertNil(DailyMetrics.onsetFill(snapshot(), tracker: tracker))
    }

    func testActiveEnergyComesFromThePhone() {
        let phone = HealthSnapshot(day: day, source: .healthKit, steps: 8_000, activeEnergyKcal: 400)
        let whoop = HealthSnapshot(day: day, source: .whoop, strain: 11, activeEnergyKcal: 650)
        let merged = SnapshotMerger.merge([whoop, phone])[0]
        XCTAssertEqual(merged.activeEnergyKcal, 400)
        XCTAssertEqual(merged.strain, 11)
    }
}
