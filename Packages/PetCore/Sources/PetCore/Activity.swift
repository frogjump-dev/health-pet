import Foundation

/// The activities pets are bound to (decided 2026-11-02): do an activity once to get its pet,
/// and the pet's level shows how much of it you have done. Only behaviour is tracked, never
/// outcomes like HRV, resting heart rate or weight, because levels are shown off and compared.
public enum Activity: String, Codable, Sendable, CaseIterable, Identifiable {
    case walking, onTimeSleep, earlyRise, mindfulness
    case running, strength, hiit, cycling, swimming, hiking
    case yoga, pilates, dance, ballSports, climbing, other

    public var id: String { rawValue }

    /// Short name for chips and titles, e.g. "Running".
    public var title: String {
        switch self {
        case .walking: "Walking"
        case .onTimeSleep: "On-time sleep"
        case .earlyRise: "Early rising"
        case .mindfulness: "Mindfulness"
        case .running: "Running"
        case .strength: "Strength"
        case .hiit: "HIIT"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .hiking: "Hiking"
        case .yoga: "Yoga"
        case .pilates: "Pilates & stretch"
        case .dance: "Dance"
        case .ballSports: "Ball sports"
        case .climbing: "Climbing"
        case .other: "All-rounder"
        }
    }

    /// One session, as the user would count it: "3 runs", "1 on-time night".
    public func sessions(_ count: Int) -> String {
        let names: (one: String, many: String) = switch self {
        case .walking: ("10k-step day", "10k-step days")
        case .onTimeSleep: ("on-time night", "on-time nights")
        case .earlyRise: ("early morning", "early mornings")
        case .mindfulness: ("mindful session", "mindful sessions")
        case .running: ("run", "runs")
        case .cycling: ("ride", "rides")
        case .swimming: ("swim", "swims")
        case .hiking: ("hike", "hikes")
        case .climbing: ("climb", "climbs")
        default: ("session", "sessions")
        }
        return "\(count) \(count == 1 ? names.one : names.many)"
    }

    /// What one valid session is, for the "how to unlock" line.
    public var unlockHint: String {
        switch self {
        case .walking: "Walk 10,000 steps in a day"
        case .onTimeSleep: "Fall asleep on time one night"
        case .earlyRise: "Wake up by your target time"
        case .mindfulness: "10 minutes of mindfulness"
        case .other: "A 20-min workout of any other kind"
        default: "One 20-min \(title.lowercased()) workout"
        }
    }

    /// Maps a workout's short name (as `HealthSnapshot.workoutType` carries it) to its activity.
    /// Unknown kinds count for the all-rounder. "Mind" counts as mindfulness.
    public init(workoutName: String) {
        switch workoutName.lowercased() {
        case "walk", "walking": self = .walking
        case "run", "running": self = .running
        case "strength", "lifting", "core": self = .strength
        case "hiit": self = .hiit
        case "ride", "cycling", "bike": self = .cycling
        case "swim", "swimming": self = .swimming
        case "hike", "hiking": self = .hiking
        case "yoga": self = .yoga
        case "pilates", "stretch", "flexibility", "cooldown", "barre": self = .pilates
        case "dance": self = .dance
        case "ball", "basketball", "soccer", "football", "tennis", "badminton", "volleyball",
             "table tennis", "pickleball", "squash", "baseball", "rugby", "hockey": self = .ballSports
        case "climb", "climbing", "ski", "snowboard", "surf", "skate": self = .climbing
        case "mind", "mindfulness", "meditation", "tai chi": self = .mindfulness
        default: self = .other
        }
    }
}

/// One workout of a day.
public struct WorkoutSession: Codable, Sendable, Equatable {
    /// Short name ("Run", "Yoga"), see `Activity.init(workoutName:)`.
    public var name: String
    public var minutes: Double

    public init(name: String, minutes: Double) {
        self.name = name
        self.minutes = minutes
    }
}

/// Wall-clock wake-up target, e.g. 07:00.
public struct WakeTime: Sendable, Equatable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }
}

/// Decides which activities a day counts for. A day counts at most once per activity,
/// so two runs on one day are one run: steady habits matter more than one huge day.
public struct ActivityTracker: Sendable {
    public var discipline: DisciplineTracker
    public var wakeTarget: WakeTime
    public var minMindfulMinutes: Double = 10

    public init(discipline: DisciplineTracker, wakeTarget: WakeTime) {
        self.discipline = discipline
        self.wakeTarget = wakeTarget
    }

    public func activities(on day: HealthSnapshot) -> Set<Activity> {
        let rules = discipline.rules
        var result: Set<Activity> = []

        if (day.steps ?? 0) >= rules.activeDaySteps { result.insert(.walking) }
        if discipline.isOnTimeNight(day) == true { result.insert(.onTimeSleep) }
        if let woke = day.wakeTime,
           let target = discipline.calendar.date(bySettingHour: wakeTarget.hour, minute: wakeTarget.minute,
                                                 second: 0, of: day.day),
           woke <= target {
            result.insert(.earlyRise)
        }
        if (day.mindfulMinutes ?? 0) >= minMindfulMinutes { result.insert(.mindfulness) }

        for workout in day.allWorkouts {
            let activity = Activity(workoutName: workout.name)
            let needed = activity == .mindfulness ? minMindfulMinutes : rules.minWorkoutMinutes
            if workout.minutes >= needed { result.insert(activity) }
        }
        return result
    }

    /// Every day's activities, keyed by the start of the day. Days with none are left out.
    public func log(_ snapshots: [HealthSnapshot]) -> [Date: Set<Activity>] {
        snapshots.reduce(into: [:]) { log, day in
            let done = activities(on: day)
            if !done.isEmpty { log[day.day] = done }
        }
    }
}

extension HealthSnapshot {
    /// The day's workouts; older snapshots only kept the longest one.
    public var allWorkouts: [WorkoutSession] {
        if let workouts { return workouts }
        guard let minutes = workoutMinutes else { return [] }
        return [WorkoutSession(name: workoutType ?? "Workout", minutes: minutes)]
    }
}

/// Pet levels. Level L needs L×(L+1)/2 experience: Lv 2 = 3, Lv 5 = 15, Lv 10 = 55, Lv 20 = 210.
/// Fast at first, slower later. Levels never go down.
public enum PetLevel {
    /// Experience needed to reach `level`.
    public static func experience(for level: Int) -> Int {
        level * (level + 1) / 2
    }

    /// 0 = not unlocked yet.
    public static func level(forExperience xp: Int) -> Int {
        var level = 0
        while experience(for: level + 1) <= xp { level += 1 }
        return level
    }
}

/// One pet's activity record.
public struct ActivityProgress: Sendable, Equatable {
    public var activity: Activity
    /// Days the activity was done.
    public var sessions: Int
    /// Sessions, with those in a finished 自律周 counting double.
    public var experience: Int
    /// The day the pet was unlocked (its 出炉证书 date), nil while locked.
    public var unlockedOn: Date?

    public var level: Int { PetLevel.level(forExperience: experience) }
    public var isUnlocked: Bool { sessions > 0 }

    /// Experience still needed for the next level.
    public var experienceToNext: Int { PetLevel.experience(for: level + 1) - experience }

    /// 0...1 through the current level.
    public var levelFraction: Double {
        let start = PetLevel.experience(for: level)
        let end = PetLevel.experience(for: level + 1)
        return Double(experience - start) / Double(end - start)
    }

    /// Builds every activity's progress from a day → activities log.
    /// A session in a finished 自律周 (`disciplinedWeeks` holds week starts) earns double.
    public static func all(log: [Date: Set<Activity>], disciplinedWeeks: Set<Date>,
                           weekStart: (Date) -> Date) -> [Activity: ActivityProgress] {
        var result = Dictionary(uniqueKeysWithValues: Activity.allCases.map {
            ($0, ActivityProgress(activity: $0, sessions: 0, experience: 0, unlockedOn: nil))
        })
        for (day, activities) in log {
            let bonus = disciplinedWeeks.contains(weekStart(day)) ? 2 : 1
            for activity in activities {
                result[activity]!.sessions += 1
                result[activity]!.experience += bonus
                if result[activity]!.unlockedOn.map({ day < $0 }) ?? true {
                    result[activity]!.unlockedOn = day
                }
            }
        }
        return result
    }
}
