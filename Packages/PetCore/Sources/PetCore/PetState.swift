import Foundation

/// Today's fast state. Each mood maps to one look of the current character skin.
/// The face stays positive in every mood: the pet is on the user's side.
public enum PetMood: String, Codable, Sendable, CaseIterable {
    /// Normal good day.
    case golden
    /// Sleep debt (for the toast: burnt edges = dark circles).
    case burnt
    /// Low recovery / energy (for the toast: soggy, folded).
    case soggy
    /// Fully recharged (for the toast: fresh with steam).
    case fresh
}

public struct PetState: Codable, Sendable, Equatable {
    public var mood: PetMood
    /// 0...1, derived recovery. Shown only one tap deeper, never on the home screen.
    public var energy: Double
    /// 0...1, how short recent sleep was versus the user's own normal.
    public var sleepDebt: Double
    /// Steps versus the user's own normal; 1 = a typical day. Feeds slow traits later.
    public var activity: Double
    /// True when the pet is asleep (automatic, driven by bedtime + sleep data).
    public var isAsleep: Bool

    public init(mood: PetMood, energy: Double, sleepDebt: Double, activity: Double, isAsleep: Bool = false) {
        self.mood = mood
        self.energy = energy
        self.sleepDebt = sleepDebt
        self.activity = activity
        self.isAsleep = isAsleep
    }

    public static let neutral = PetState(mood: .golden, energy: 0.6, sleepDebt: 0, activity: 1)
}
