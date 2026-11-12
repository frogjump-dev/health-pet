import Foundation
import PetCore

/// Fake data for the simulator and SwiftUI previews (the simulator has no Health data).
struct DemoHealthProvider: HealthDataProvider {
    let source: DataSource = .mock

    func requestAuthorization() async throws {}

    func snapshots(from start: Date, to end: Date) async throws -> [HealthSnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: end)
        var result: [HealthSnapshot] = []
        var day = calendar.startOfDay(for: start)
        var generator = SeededGenerator(seed: 42)

        while day < today {
            // Mostly in bed around 23:00, now and then a late night; a workout every couple of days.
            let lateNight = Int.random(in: 0..<5, using: &generator) == 0
            let onsetMinute = lateNight ? Int.random(in: 30...90, using: &generator) : Int.random(in: -30...20, using: &generator)
            let workedOut = Int.random(in: 0..<2, using: &generator) == 0
            let workoutMinutes = Double.random(in: 22...50, using: &generator)
            let workoutType = ["Run", "Run", "Yoga", "Strength", "Ride"].randomElement(using: &generator)!
            // Up most mornings by 07:00, now and then a lie-in; a short meditation a couple of times a week.
            let wakeMinute = Int.random(in: -40...25, using: &generator)
            let meditated = Int.random(in: 0..<3, using: &generator) == 0
            let steps = Int.random(in: 6_000...12_500, using: &generator)
            result.append(HealthSnapshot(
                day: day, source: .mock,
                steps: steps,
                sleepHours: Double.random(in: 7...8, using: &generator),
                hrvMs: Double.random(in: 45...55, using: &generator), hrvMethod: .sdnn,
                restingHeartRate: Double.random(in: 58...62, using: &generator),
                sleepOnset: Self.onset(nightEnding: day, minutesAfter11pm: onsetMinute),
                workoutMinutes: workedOut ? workoutMinutes : nil,
                workoutType: workedOut ? workoutType : nil,
                workouts: workedOut ? [WorkoutSession(name: workoutType, minutes: workoutMinutes,
                                                      distanceKm: workoutType == "Run" ? workoutMinutes / 6.2 : nil)] : [],
                wakeTime: Self.wake(day: day, minutesAfter7am: wakeMinute),
                mindfulMinutes: meditated ? 10 : nil,
                // about 30 kcal per 1,000 steps, plus ~8 kcal a workout minute
                activeEnergyKcal: Double(steps) * 0.03 + (workedOut ? workoutMinutes * 8 : 0)
            ))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        result.append(todaySnapshot(day: today))
        return result
    }

    /// The v3.3 mock's day: last night on time, a run, a swim and a 10k-step day, four bubbles.
    private func todaySnapshot(day: Date) -> HealthSnapshot {
        HealthSnapshot(day: day, source: .mock, steps: 10_240, sleepHours: 7.5, hrvMs: 50, hrvMethod: .sdnn, restingHeartRate: 60,
                       sleepOnset: Self.onset(nightEnding: day, minutesAfter11pm: -12), workoutMinutes: 32, workoutType: "Run",
                       workouts: [WorkoutSession(name: "Run", minutes: 32, distanceKm: 5.1), WorkoutSession(name: "Swim", minutes: 25, distanceKm: 1.0)],
                       wakeTime: Self.wake(day: day, minutesAfter7am: -15),
                       activeEnergyKcal: 512)
    }

    private static func wake(day: Date, minutesAfter7am minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: day)!.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private static func onset(nightEnding day: Date, minutesAfter11pm minutes: Int) -> Date {
        let calendar = Calendar.current
        let elevenPM = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: day)!)!
        return elevenPM.addingTimeInterval(TimeInterval(minutes * 60))
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
