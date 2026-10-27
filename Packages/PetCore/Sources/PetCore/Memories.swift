import Foundation

/// A page in the "shared memories" album, created automatically from data events.
public struct MemoryEvent: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case firstTwentyKSteps
        case onTimeSleepStreak
        case anniversary
    }

    public var id: String { "\(kind.rawValue)-\(Int(day.timeIntervalSince1970))" }
    public var kind: Kind
    public var day: Date
    /// Short English title for now; localisation comes later.
    public var title: String

    public init(kind: Kind, day: Date, title: String) {
        self.kind = kind
        self.day = day
        self.title = title
    }
}

/// One rule that may produce a memory for `today`. Add new rules without touching the detector.
public protocol MemoryRule: Sendable {
    func check(today: HealthSnapshot, history: [HealthSnapshot], adoptedOn: Date, existing: [MemoryEvent]) -> MemoryEvent?
}

public struct MemoryDetector: Sendable {
    public var rules: [any MemoryRule]

    public init(rules: [any MemoryRule] = [FirstTwentyKStepsRule(), AnniversaryRule()]) {
        self.rules = rules
    }

    public func newMemories(today: HealthSnapshot, history: [HealthSnapshot], adoptedOn: Date, existing: [MemoryEvent]) -> [MemoryEvent] {
        rules.compactMap { $0.check(today: today, history: history, adoptedOn: adoptedOn, existing: existing) }
    }
}

public struct FirstTwentyKStepsRule: MemoryRule {
    public init() {}

    public func check(today: HealthSnapshot, history: [HealthSnapshot], adoptedOn: Date, existing: [MemoryEvent]) -> MemoryEvent? {
        guard let steps = today.steps, steps >= 20_000,
              !existing.contains(where: { $0.kind == .firstTwentyKSteps }) else { return nil }
        return MemoryEvent(kind: .firstTwentyKSteps, day: today.day, title: "Our first 20k-step day")
    }
}

public struct AnniversaryRule: MemoryRule {
    public static let milestones = [30, 100, 365]
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func check(today: HealthSnapshot, history: [HealthSnapshot], adoptedOn: Date, existing: [MemoryEvent]) -> MemoryEvent? {
        let start = calendar.startOfDay(for: adoptedOn)
        let end = calendar.startOfDay(for: today.day)
        guard let days = calendar.dateComponents([.day], from: start, to: end).day,
              Self.milestones.contains(days),
              !existing.contains(where: { $0.kind == .anniversary && calendar.isDate($0.day, inSameDayAs: today.day) })
        else { return nil }
        return MemoryEvent(kind: .anniversary, day: today.day, title: "\(days) days together")
    }
}
