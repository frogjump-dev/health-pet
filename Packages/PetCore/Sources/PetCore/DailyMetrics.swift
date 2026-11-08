import Foundation

/// The day's numbers behind the 3D app: the daily load and the rest estimate. Bars are
/// "fuller = more rested" and never red.
///
/// Apple Watch has no recovery or load score that apps can read, so for Apple Health days
/// both are estimated here, on the phone, from the user's own data. They are our own
/// estimates: the UI calls them Daily load and Rest, never Strain or Recovery (PRD v0.2).
/// Home shows the load only when it is Whoop's strain, and the rest bar without a number.
public enum DailyMetrics {
    /// Upper end of the load scale; the same 0–21 range a Whoop day strain uses, so a
    /// Whoop user and an Apple Watch user read the number the same way.
    public static let maxLoad = 21.0

    /// The day's load: Whoop's day strain when there is one, otherwise our estimate.
    public static func dailyLoad(_ day: HealthSnapshot) -> Double? {
        day.strain ?? estimatedLoad(activeKcal: day.activeEnergyKcal,
                                    workoutMinutes: day.allWorkouts.reduce(0) { $0 + $1.minutes })
    }

    /// Load estimated from active energy plus workout time (each workout minute counts like
    /// 3 extra kcal, so a hard session weighs more than a long walk). It rises quickly at
    /// first and flattens towards 21, like a strain scale: 500 → about 9, 1,000 → 14, 2,000 → 19.
    public static func estimatedLoad(activeKcal: Double?, workoutMinutes: Double) -> Double? {
        guard activeKcal != nil || workoutMinutes > 0 else { return nil }
        let effort = max(0, activeKcal ?? 0) + 3 * max(0, workoutMinutes)
        return maxLoad * (1 - exp(-effort / 900))
    }

    /// 0–100. Whoop's recovery when there is one; otherwise estimated from last night's HRV
    /// against the user's own 30-day normal (60%) and how much they slept (40%).
    /// nil when there is nothing to go on.
    public static func recovery(_ day: HealthSnapshot, baseline: PersonalBaseline) -> Double? {
        if let vendor = day.vendorRecovery { return vendor }
        let hrv = hrvRatio(day, baseline: baseline).map { clamp(($0 - 0.7) / 0.6) }
        let sleep = day.sleepHours.map { clamp($0 / max(7, baseline.sleepHours ?? 8)) }
        switch (hrv, sleep) {
        case let (hrv?, sleep?): return 100 * (0.6 * hrv + 0.4 * sleep)
        case let (hrv?, nil): return 100 * hrv
        case let (nil, sleep?): return 100 * (0.2 + 0.6 * sleep)
        case (nil, nil): return nil
        }
    }

    /// Today's HRV over the user's own normal, measured the same way (SDNN with SDNN,
    /// RMSSD with RMSSD). nil until there are enough days to compare with.
    public static func hrvRatio(_ day: HealthSnapshot, baseline: PersonalBaseline) -> Double? {
        guard let hrv = day.hrvMs, let normal = baseline.hrvMs, normal > 0, baseline.isReliable,
              baseline.hrvMethod == nil || baseline.hrvMethod == day.hrvMethod else { return nil }
        return hrv / normal
    }

    /// How full the HRV bar is: a usual night fills about 70%, 40% above usual fills it.
    /// Without a normal to compare with yet, it sits at the usual 70%.
    public static func hrvFill(_ day: HealthSnapshot, baseline: PersonalBaseline) -> Double? {
        guard day.hrvMs != nil else { return nil }
        guard let ratio = hrvRatio(day, baseline: baseline) else { return 0.7 }
        return max(0.05, clamp(ratio / 1.4))
    }

    /// How full the sleep-onset bar is: asleep on time (within the grace period) = full,
    /// then it empties over the next 2.5 hours, never quite to nothing.
    public static func onsetFill(_ day: HealthSnapshot, tracker: DisciplineTracker) -> Double? {
        guard let onset = day.sleepOnset else { return nil }
        let target = tracker.target(forNightEnding: day.day)
        let minutesLate = onset.timeIntervalSince(target) / 60 - Double(tracker.rules.bedtimeGraceMinutes)
        guard minutesLate > 0 else { return 1 }
        return max(0.08, 1 - minutesLate / 150)
    }

    private static func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
}
