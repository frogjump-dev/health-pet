import Foundation
import HealthKit
import PetCore

/// Reads Apple Health on device. Raw samples never leave the phone; only daily summaries do.
struct HealthKitProvider: HealthDataProvider {
    let source: DataSource = .healthKit

    private let store = HKHealthStore()
    private let calendar = Calendar.current

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.workoutType()
        ]
    }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func snapshots(from start: Date, to end: Date) async throws -> [HealthSnapshot] {
        let firstDay = calendar.startOfDay(for: start)

        async let steps = daily(.stepCount, unit: .count(), options: .cumulativeSum, from: firstDay, to: end)
        async let hrv = daily(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), options: .discreteAverage, from: firstDay, to: end)
        async let rhr = daily(.restingHeartRate, unit: .count().unitDivided(by: .minute()), options: .discreteAverage, from: firstDay, to: end)
        async let sleep = dailySleep(from: firstDay, to: end)
        async let workouts = longestWorkouts(from: firstDay, to: end)
        let (stepsByDay, hrvByDay, rhrByDay, sleepByDay, workoutByDay) = try await (steps, hrv, rhr, sleep, workouts)

        var result: [HealthSnapshot] = []
        var day = firstDay
        while day <= end {
            let hrvValue = hrvByDay[day]
            result.append(HealthSnapshot(
                day: day,
                source: .healthKit,
                steps: stepsByDay[day].map { Int($0) },
                sleepHours: sleepByDay[day]?.hours,
                hrvMs: hrvValue,
                hrvMethod: hrvValue == nil ? nil : .sdnn,
                restingHeartRate: rhrByDay[day],
                sleepOnset: sleepByDay[day]?.onset,
                workoutMinutes: workoutByDay[day]?.minutes,
                workoutType: workoutByDay[day]?.name
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    // MARK: - Queries

    private func daily(
        _ id: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        from start: Date,
        to end: Date
    ) async throws -> [Date: Double] {
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(id),
            predicate: HKQuery.predicateForSamples(withStart: start, end: end)
        )
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate,
            options: options,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)

        var result: [Date: Double] = [:]
        for stats in collection.statistics() {
            let quantity = options.contains(.cumulativeSum) ? stats.sumQuantity() : stats.averageQuantity()
            if let quantity {
                result[calendar.startOfDay(for: stats.startDate)] = quantity.doubleValue(for: unit)
            }
        }
        return result
    }

    /// Hours asleep and the time of falling asleep for the night that ends on each day.
    /// Overlapping samples from several sources (Watch + phone + third-party apps) are merged
    /// so they are not double counted.
    private func dailySleep(from start: Date, to end: Date) async throws -> [Date: (hours: Double, onset: Date?)] {
        // Look back 12h so a night that started the evening before `start` is included.
        let queryStart = start.addingTimeInterval(-12 * 3600)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(
                type: HKCategoryType(.sleepAnalysis),
                predicate: HKQuery.predicateForSamples(withStart: queryStart, end: end)
            )],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)

        let asleep = samples.filter { sample in
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
            return HKCategoryValueSleepAnalysis.allAsleepValues.contains(value)
        }

        var intervalsByDay: [Date: [DateInterval]] = [:]
        for sample in asleep {
            let day = calendar.startOfDay(for: sample.endDate)
            intervalsByDay[day, default: []].append(DateInterval(start: sample.startDate, end: sample.endDate))
        }
        return intervalsByDay.reduce(into: [:]) { result, entry in
            // Onset = first sleep after 6 pm the evening before, so afternoon naps don't count.
            let eveningBefore = calendar.date(byAdding: .hour, value: -6, to: entry.key)!
            let onset = entry.value.map(\.start).filter { $0 >= eveningBefore }.min()
            result[entry.key] = (mergedDuration(entry.value) / 3600, onset)
        }
    }

    /// The longest workout started on each day.
    private func longestWorkouts(from start: Date, to end: Date) async throws -> [Date: (minutes: Double, name: String)] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(withStart: start, end: end))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let workouts = try await descriptor.result(for: store)

        var result: [Date: (minutes: Double, name: String)] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startDate)
            let minutes = workout.duration / 60
            if minutes > result[day]?.minutes ?? 0 {
                result[day] = (minutes, Self.shortName(workout.workoutActivityType))
            }
        }
        return result
    }

    private static func shortName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "Run"
        case .walking: "Walk"
        case .cycling: "Ride"
        case .swimming: "Swim"
        case .hiking: "Hike"
        case .yoga: "Yoga"
        case .highIntensityIntervalTraining: "HIIT"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Strength"
        case .dance, .cardioDance, .socialDance: "Dance"
        case .elliptical: "Elliptical"
        case .rowing: "Row"
        case .pilates: "Pilates"
        default: "Workout"
        }
    }

    private func mergedDuration(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var current: DateInterval?
        for interval in sorted {
            if let c = current, interval.start <= c.end {
                current = DateInterval(start: c.start, end: max(c.end, interval.end))
            } else {
                if let c = current { total += c.duration }
                current = interval
            }
        }
        if let c = current { total += c.duration }
        return total
    }
}
