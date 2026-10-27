import Foundation

/// The user's own "normal", averaged over the last `windowDays`.
/// The pet reacts to change relative to this, never to population norms.
public struct PersonalBaseline: Sendable, Equatable {
    public var steps: Double?
    public var sleepHours: Double?
    public var hrvMs: Double?
    public var hrvMethod: HRVMethod?
    public var restingHeartRate: Double?
    public var sampleCount: Int

    public static let windowDays = 30
    /// Below this many days we fall back to sensible defaults.
    public static let minimumSamples = 5

    public var isReliable: Bool { sampleCount >= Self.minimumSamples }

    public init(
        steps: Double? = nil,
        sleepHours: Double? = nil,
        hrvMs: Double? = nil,
        hrvMethod: HRVMethod? = nil,
        restingHeartRate: Double? = nil,
        sampleCount: Int = 0
    ) {
        self.steps = steps
        self.sleepHours = sleepHours
        self.hrvMs = hrvMs
        self.hrvMethod = hrvMethod
        self.restingHeartRate = restingHeartRate
        self.sampleCount = sampleCount
    }

    /// Builds a baseline from history, excluding `today`. HRV only averages samples
    /// measured with `hrvMethod` so SDNN and RMSSD never get mixed.
    public static func from(history: [HealthSnapshot], before today: Date, hrvMethod: HRVMethod?) -> PersonalBaseline {
        let window = history
            .filter { $0.day < today }
            .sorted { $0.day > $1.day }
            .prefix(windowDays)

        let hrvSamples = window.compactMap { s -> Double? in
            guard let method = hrvMethod, s.hrvMethod == method else { return nil }
            return s.hrvMs
        }

        return PersonalBaseline(
            steps: mean(window.compactMap { $0.steps.map(Double.init) }),
            sleepHours: mean(window.compactMap(\.sleepHours)),
            hrvMs: mean(hrvSamples),
            hrvMethod: hrvMethod,
            restingHeartRate: mean(window.compactMap(\.restingHeartRate)),
            sampleCount: window.count
        )
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
