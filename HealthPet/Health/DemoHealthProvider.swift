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
            // Mostly in bed around 23:00, now and then a late night; a workout every couple of days.
            let lateNight = shortNight || Int.random(in: 0..<5, using: &generator) == 0
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
                sleepHours: shortNight ? 5 : Double.random(in: 7...8, using: &generator),
                hrvMs: Double.random(in: 45...55, using: &generator), hrvMethod: .sdnn,
                restingHeartRate: Double.random(in: 58...62, using: &generator),
                sleepOnset: Self.onset(nightEnding: day, minutesAfter11pm: onsetMinute),
                workoutMinutes: workedOut ? workoutMinutes : nil,
                workoutType: workedOut ? workoutType : nil,
                workouts: workedOut ? [WorkoutSession(name: workoutType, minutes: workoutMinutes)] : [],
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

    private func todaySnapshot(day: Date) -> HealthSnapshot {
        switch scenario {
        case .golden: HealthSnapshot(day: day, source: .mock, steps: 8_214, sleepHours: 7.5, hrvMs: 50, hrvMethod: .sdnn, restingHeartRate: 60,
                                     sleepOnset: Self.onset(nightEnding: day, minutesAfter11pm: 5), workoutMinutes: 32, workoutType: "Run",
                                     workouts: [WorkoutSession(name: "Run", minutes: 32)], wakeTime: Self.wake(day: day, minutesAfter7am: -15),
                                     activeEnergyKcal: 412)
        case .burnt:  HealthSnapshot(day: day, source: .mock, steps: 5_000, sleepHours: 4.5, hrvMs: 48, hrvMethod: .sdnn, restingHeartRate: 62,
                                     sleepOnset: Self.onset(nightEnding: day, minutesAfter11pm: 150), activeEnergyKcal: 160)
        case .soggy:  HealthSnapshot(day: day, source: .mock, steps: 3_000, sleepHours: 7.2, hrvMs: 30, hrvMethod: .sdnn, restingHeartRate: 68,
                                     sleepOnset: Self.onset(nightEnding: day, minutesAfter11pm: -10), activeEnergyKcal: 95)
        case .fresh:  HealthSnapshot(day: day, source: .mock, steps: 12_000, sleepHours: 8.3, hrvMs: 68, hrvMethod: .sdnn, restingHeartRate: 55,
                                     sleepOnset: Self.onset(nightEnding: day, minutesAfter11pm: -40), workoutMinutes: 45, workoutType: "Yoga",
                                     workouts: [WorkoutSession(name: "Yoga", minutes: 45)], wakeTime: Self.wake(day: day, minutesAfter7am: -30),
                                     activeEnergyKcal: 640)
        }
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
