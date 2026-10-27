import Foundation

/// Turns health snapshots into a `PetState`. Pure and deterministic, so it is easy to test
/// and can later run on the server too.
public struct PetStateEngine: Sendable {
    public struct Config: Sendable {
        /// Used until the baseline is reliable.
        public var defaultSleepHours = 7.5
        public var defaultSteps = 6_000.0
        /// Number of recent nights averaged into sleep debt.
        public var sleepDebtNights = 3
        public var burntSleepDebt = 0.2
        public var soggyEnergy = 0.4
        public var freshEnergy = 0.8

        public init() {}
    }

    public var config: Config

    public init(config: Config = Config()) {
        self.config = config
    }

    /// - Parameters:
    ///   - today: today's snapshot (may be partial).
    ///   - history: previous days, any order; today is ignored if present.
    public func evaluate(today: HealthSnapshot, history: [HealthSnapshot]) -> PetState {
        let baseline = PersonalBaseline.from(history: history, before: today.day, hrvMethod: today.hrvMethod)

        let sleepDebt = sleepDebt(today: today, history: history, baseline: baseline)
        let energy = energy(today: today, baseline: baseline, sleepDebt: sleepDebt)
        let activity = activity(today: today, baseline: baseline)

        return PetState(
            mood: mood(energy: energy, sleepDebt: sleepDebt),
            energy: energy,
            sleepDebt: sleepDebt,
            activity: activity
        )
    }

    // MARK: - Signals

    func sleepDebt(today: HealthSnapshot, history: [HealthSnapshot], baseline: PersonalBaseline) -> Double {
        let target = baseline.isReliable ? (baseline.sleepHours ?? config.defaultSleepHours) : config.defaultSleepHours
        let recent = ([today] + history.filter { $0.day < today.day }.sorted { $0.day > $1.day })
            .prefix(config.sleepDebtNights)
            .compactMap(\.sleepHours)
        guard !recent.isEmpty, target > 0 else { return 0 }
        let avg = recent.reduce(0, +) / Double(recent.count)
        return clamp(1 - avg / target)
    }

    func energy(today: HealthSnapshot, baseline: PersonalBaseline, sleepDebt: Double) -> Double {
        // A vendor score (Whoop) is already personalised; trust it.
        if let vendor = today.vendorRecovery {
            return clamp(vendor / 100)
        }

        var parts: [(value: Double, weight: Double)] = []

        if let hrv = today.hrvMs, let base = baseline.hrvMs, baseline.isReliable, base > 0 {
            // +/-30% around the user's HRV maps onto 0...1.
            parts.append((clamp(0.5 + (hrv / base - 1) / 0.6), 0.5))
        }
        if let rhr = today.restingHeartRate, let base = baseline.restingHeartRate, baseline.isReliable, base > 0 {
            // A higher resting HR than normal means less recovered.
            parts.append((clamp(0.5 - (rhr / base - 1) / 0.2), 0.2))
        }
        if today.sleepHours != nil {
            parts.append((1 - sleepDebt, 0.3))
        }

        guard !parts.isEmpty else { return PetState.neutral.energy }
        let totalWeight = parts.reduce(0) { $0 + $1.weight }
        return clamp(parts.reduce(0) { $0 + $1.value * $1.weight } / totalWeight)
    }

    func activity(today: HealthSnapshot, baseline: PersonalBaseline) -> Double {
        guard let steps = today.steps else { return 1 }
        let base = baseline.isReliable ? (baseline.steps ?? config.defaultSteps) : config.defaultSteps
        return base > 0 ? min(Double(steps) / base, 3) : 1
    }

    func mood(energy: Double, sleepDebt: Double) -> PetMood {
        if sleepDebt >= config.burntSleepDebt { return .burnt }
        if energy < config.soggyEnergy { return .soggy }
        if energy >= config.freshEnergy { return .fresh }
        return .golden
    }

    private func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
}
