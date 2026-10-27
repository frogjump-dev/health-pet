import Foundation
import PetCore

/// Fake data for the simulator and SwiftUI previews (the simulator has no Health data).
struct DemoHealthProvider: HealthDataProvider {
    let source: DataSource = .mock
    /// Which mood today's data should produce.
    var scenario: PetMood = .golden

    func requestAuthorization() async throws {}

    func snapshots(from start: Date, to end: Date) async throws -> [HealthSnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: end)
        var result: [HealthSnapshot] = []
        var day = calendar.startOfDay(for: start)
        var generator = SeededGenerator(seed: 42)

        while day < today {
            let daysAgo = calendar.dateComponents([.day], from: day, to: today).day ?? 0
            // Sleep debt builds over several nights, so the burnt scenario shortens the last two too.
            let shortNight = scenario == .burnt && daysAgo <= 2
            result.append(HealthSnapshot(
                day: day, source: .mock,
                steps: Int.random(in: 6_000...10_000, using: &generator),
                sleepHours: shortNight ? 5 : Double.random(in: 7...8, using: &generator),
                hrvMs: Double.random(in: 45...55, using: &generator), hrvMethod: .sdnn,
                restingHeartRate: Double.random(in: 58...62, using: &generator)
            ))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        result.append(todaySnapshot(day: today))
        return result
    }

    private func todaySnapshot(day: Date) -> HealthSnapshot {
        switch scenario {
        case .golden: HealthSnapshot(day: day, source: .mock, steps: 8_000, sleepHours: 7.5, hrvMs: 50, hrvMethod: .sdnn, restingHeartRate: 60)
        case .burnt:  HealthSnapshot(day: day, source: .mock, steps: 5_000, sleepHours: 4.5, hrvMs: 48, hrvMethod: .sdnn, restingHeartRate: 62)
        case .soggy:  HealthSnapshot(day: day, source: .mock, steps: 3_000, sleepHours: 7.2, hrvMs: 30, hrvMethod: .sdnn, restingHeartRate: 68)
        case .fresh:  HealthSnapshot(day: day, source: .mock, steps: 12_000, sleepHours: 8.3, hrvMs: 68, hrvMethod: .sdnn, restingHeartRate: 55)
        }
    }
}

/// Deterministic RNG so demo data looks the same on every launch.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
