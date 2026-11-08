import Foundation

/// The pet's slow-changing condition (decided 2026-11-08, PRD §5.5): how the last 7 days went,
/// shown only by the pet's idle behaviour and the tint of its floor. Friends never see numbers,
/// but anyone can tell from the pet how you have been doing. It never changes levels, unlocks
/// or anything else, and there is no sad tier: a low week makes the pet sleepy, not unhappy.
public enum PetEnergy: String, Codable, Sendable, CaseIterable, Identifiable {
    /// 元气: hums, hops and sparkles more often; the floor is the normal jade.
    case lively
    /// 平常: the usual idle.
    case normal
    /// 没电: yawns, daydreams and stretches more; the floor is paler; a tap cheers you on.
    case low

    public var id: String { rawValue }
}

public enum EnergyMeter {
    /// Score at or above this is lively, below `lowBelow` low.
    public static let livelyFrom = 0.75
    public static let lowBelow = 0.4

    /// On-time nights, workouts and the rest estimate over the last 7 days, a third each.
    /// Only finished days count for workouts and the nights up to last night, so the tier is
    /// settled in the morning and does not jump around during the day.
    ///
    /// - nights: the 7 nights ending this morning; 5 on time is full marks (a leave day counts).
    /// - workouts: the 7 days before today; 3 is full marks.
    /// - rest: the mean of the 7 days' rest (Whoop recovery or our estimate), 0–100.
    /// Parts without any data are left out; with no data at all the pet is normal.
    public static func energy(snapshots: [HealthSnapshot], today: Date, tracker: DisciplineTracker,
                              baseline: PersonalBaseline, leaveDays: Set<Date> = []) -> PetEnergy {
        guard let score = score(snapshots: snapshots, today: today, tracker: tracker,
                                baseline: baseline, leaveDays: leaveDays) else { return .normal }
        if score >= livelyFrom { return .lively }
        if score < lowBelow { return .low }
        return .normal
    }

    /// 0...1, nil when there is nothing to go on.
    public static func score(snapshots: [HealthSnapshot], today: Date, tracker: DisciplineTracker,
                             baseline: PersonalBaseline, leaveDays: Set<Date> = []) -> Double? {
        let calendar = tracker.calendar
        let todayStart = calendar.startOfDay(for: today)
        guard let nightsFrom = calendar.date(byAdding: .day, value: -6, to: todayStart),
              let workoutsFrom = calendar.date(byAdding: .day, value: -7, to: todayStart) else { return nil }

        let nightDays = snapshots.filter { $0.day >= nightsFrom && $0.day <= todayStart }
        let workoutDays = snapshots.filter { $0.day >= workoutsFrom && $0.day < todayStart }
        let leave = Set(leaveDays.map { calendar.startOfDay(for: $0) }.filter { $0 >= nightsFrom && $0 <= todayStart })

        var parts: [Double] = []
        let judged = nightDays.compactMap { day in tracker.isOnTimeNight(day).map { (day.day, $0) } }
        if !judged.isEmpty || !leave.isEmpty {
            let onTime = Set(judged.filter(\.1).map(\.0)).union(leave).count
            parts.append(min(1, Double(onTime) / Double(tracker.rules.onTimeNightsPerWeek)))
        }
        if workoutDays.contains(where: { $0.steps != nil || $0.workoutMinutes != nil || !$0.allWorkouts.isEmpty }) {
            let workouts = workoutDays.filter(tracker.countsAsWorkout).count
            parts.append(min(1, Double(workouts) / Double(tracker.rules.workoutsPerWeek)))
        }
        let rests = nightDays.compactMap { DailyMetrics.recovery($0, baseline: baseline) }
        if !rests.isEmpty {
            parts.append(rests.reduce(0, +) / Double(rests.count) / 100)
        }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +) / Double(parts.count)
    }
}
