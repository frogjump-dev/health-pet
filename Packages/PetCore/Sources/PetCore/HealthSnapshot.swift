import Foundation

/// Where a day's numbers came from. Values measured differently are never mixed
/// (e.g. Apple HRV is SDNN, Whoop HRV is RMSSD).
public enum DataSource: String, Codable, Sendable, CaseIterable {
    case healthKit
    case whoop
    case mock
    /// Merged from several sources by `SnapshotMerger`.
    case combined
}

public enum HRVMethod: String, Codable, Sendable {
    case sdnn   // Apple Health
    case rmssd  // Whoop / Oura
}

/// One day of canonical metrics, already normalised by a source adapter.
/// Every field is optional: a phone-only user may only have steps.
public struct HealthSnapshot: Codable, Sendable, Equatable, Identifiable {
    public var id: Date { day }

    /// Start of the calendar day this snapshot describes (sleep = the night ending this morning).
    public var day: Date
    public var source: DataSource
    public var steps: Int?
    public var sleepHours: Double?
    public var hrvMs: Double?
    public var hrvMethod: HRVMethod?
    public var restingHeartRate: Double?
    /// Vendor recovery score 0–100 (Whoop). nil for Apple Health, which has none an app can read.
    public var vendorRecovery: Double?
    /// When the user fell asleep for the night ending this morning.
    public var sleepOnset: Date?
    /// Length of the day's longest workout, in minutes.
    public var workoutMinutes: Double?
    /// Short name of that workout ("Run", "Yoga"), for display.
    public var workoutType: String?
    /// Every workout of the day (nil in snapshots saved before pets were bound to activities).
    public var workouts: [WorkoutSession]?
    /// When the user woke up from the night ending this morning.
    public var wakeTime: Date?
    /// Minutes of mindfulness / meditation logged this day.
    public var mindfulMinutes: Double?
    /// Whoop day strain, 0-21 (still rising during the day).
    public var strain: Double?
    /// Whoop sleep performance: sleep got vs. sleep needed, 0-100.
    public var sleepPerformance: Double?
    /// Active energy burned this day, in kcal (Apple Health "Move"; nil in older snapshots).
    public var activeEnergyKcal: Double?

    public init(
        day: Date,
        source: DataSource,
        steps: Int? = nil,
        sleepHours: Double? = nil,
        hrvMs: Double? = nil,
        hrvMethod: HRVMethod? = nil,
        restingHeartRate: Double? = nil,
        vendorRecovery: Double? = nil,
        sleepOnset: Date? = nil,
        workoutMinutes: Double? = nil,
        workoutType: String? = nil,
        workouts: [WorkoutSession]? = nil,
        wakeTime: Date? = nil,
        mindfulMinutes: Double? = nil,
        strain: Double? = nil,
        sleepPerformance: Double? = nil,
        activeEnergyKcal: Double? = nil
    ) {
        self.day = day
        self.source = source
        self.steps = steps
        self.sleepHours = sleepHours
        self.hrvMs = hrvMs
        self.hrvMethod = hrvMethod
        self.restingHeartRate = restingHeartRate
        self.vendorRecovery = vendorRecovery
        self.sleepOnset = sleepOnset
        self.workoutMinutes = workoutMinutes
        self.workoutType = workoutType
        self.workouts = workouts
        self.wakeTime = wakeTime
        self.mindfulMinutes = mindfulMinutes
        self.strain = strain
        self.sleepPerformance = sleepPerformance
        self.activeEnergyKcal = activeEnergyKcal
    }
}
