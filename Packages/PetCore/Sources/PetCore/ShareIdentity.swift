import Foundation

/// The identity title on share cards (PRD v0.2 §6, decided 2026-11-08): "{Early-to-bed} {sport}",
/// e.g. "Early-to-bed Runner". Like an MBTI type it is something people recognise themselves in
/// and pass on, and it shows behaviour only, never a health number.
public enum ShareIdentity {
    /// The qualifier needs this many on-time nights this week (a leave day counts).
    public static let earlyNightsNeeded = 5
    public static let qualifier = "Early-to-bed"
    /// When no sport pet is unlocked yet.
    public static let fallback = "Early Bird"

    /// - Parameters:
    ///   - progress: every activity's progress; only sport pets name the title (not Toast,
    ///     sleep, waking, mindfulness or the Whoop pets).
    ///   - mainActivity: the main pet's activity, which wins a tie on level.
    public static func title(progress: [Activity: ActivityProgress], mainActivity: Activity?,
                             onTimeNightsThisWeek: Int) -> String {
        guard let sport = topSport(progress: progress, mainActivity: mainActivity) else { return fallback }
        let noun = sport.identity
        return onTimeNightsThisWeek >= earlyNightsNeeded ? "\(qualifier) \(noun)" : noun
    }

    /// The unlocked sport with the highest level; ties go to the main pet, then to more experience.
    public static func topSport(progress: [Activity: ActivityProgress], mainActivity: Activity?) -> Activity? {
        let sports = Activity.allCases.compactMap { progress[$0] }.filter { $0.activity.isWorkout && $0.isUnlocked }
        guard let top = sports.map(\.level).max() else { return nil }
        let tied = sports.filter { $0.level == top }
        if let main = mainActivity, tied.contains(where: { $0.activity == main }) { return main }
        return tied.max { ($0.experience, $0.sessions) < ($1.experience, $1.sessions) }?.activity
    }
}

extension Activity {
    /// Who does this sport, for the share title: "Runner", "Yogi".
    public var identity: String {
        switch self {
        case .walking: "Walker"
        case .running: "Runner"
        case .strength: "Lifter"
        case .hiit: "HIIT Fan"
        case .cycling: "Cyclist"
        case .swimming: "Swimmer"
        case .hiking: "Hiker"
        case .yoga: "Yogi"
        case .pilates: "Stretcher"
        case .dance: "Dancer"
        case .ballSports: "Baller"
        case .climbing: "Climber"
        case .other: "All-rounder"
        case .onTimeSleep: "Sleeper"
        case .earlyRise: "Early Riser"
        case .mindfulness: "Meditator"
        case .recoveryMatch, .sleepNeedMet, .redDayRest: "Balancer"
        }
    }
}
