import XCTest
@testable import PetCore

final class SnapshotMergerTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_790_000_000)

    func testWhoopRecoveryAndPhoneSteps() {
        let phone = HealthSnapshot(day: day, source: .healthKit, steps: 9_000, sleepHours: 6.5,
                                   hrvMs: 45, hrvMethod: .sdnn, restingHeartRate: 60)
        let whoop = HealthSnapshot(day: day, source: .whoop, sleepHours: 7.2,
                                   hrvMs: 70, hrvMethod: .rmssd, restingHeartRate: 55, vendorRecovery: 81)

        let merged = SnapshotMerger.merge([phone, whoop])

        XCTAssertEqual(merged.count, 1)
        let m = merged[0]
        XCTAssertEqual(m.source, .combined)
        XCTAssertEqual(m.steps, 9_000)
        XCTAssertEqual(m.sleepHours, 7.2)
        XCTAssertEqual(m.hrvMs, 70)
        XCTAssertEqual(m.hrvMethod, .rmssd)
        XCTAssertEqual(m.restingHeartRate, 55)
        XCTAssertEqual(m.vendorRecovery, 81)
    }

    func testFallsBackToPhoneWhenWhoopHasNoScoreYet() {
        let phone = HealthSnapshot(day: day, source: .healthKit, steps: 4_000, sleepHours: 7,
                                   hrvMs: 48, hrvMethod: .sdnn)
        let whoop = HealthSnapshot(day: day, source: .whoop)

        let m = SnapshotMerger.merge([whoop, phone])[0]

        XCTAssertEqual(m.sleepHours, 7)
        XCTAssertEqual(m.hrvMs, 48)
        XCTAssertEqual(m.hrvMethod, .sdnn, "HRV value and method must come from the same source")
        XCTAssertNil(m.vendorRecovery)
    }

    func testSingleSourceDaysPassThroughSorted() {
        let later = day.addingTimeInterval(86_400)
        let merged = SnapshotMerger.merge([
            HealthSnapshot(day: later, source: .healthKit, steps: 1),
            HealthSnapshot(day: day, source: .whoop, sleepHours: 8)
        ])
        XCTAssertEqual(merged.map(\.day), [day, later])
        XCTAssertEqual(merged[0].source, .whoop)
        XCTAssertEqual(merged[1].source, .healthKit)
    }
}
