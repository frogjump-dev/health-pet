import Foundation
import Observation

/// 24-hour (22:48) or 12-hour (10:48 PM) clock, picked in Settings → Look (PRD v0.3 §6, decided
/// 2026-11-10). Until the user picks one it follows the phone (a suggestion, not yet confirmed).
/// Every clock time in the app goes through `Format`, which reads this, so the switch is here only.
/// Observable: a view that shows a time updates as soon as the setting changes.
@Observable
final class ClockStyle {
    static let shared = ClockStyle()

    private static let key = "3d.timeFormat"

    var twelveHour: Bool {
        didSet { UserDefaults.standard.set(twelveHour ? "12" : "24", forKey: Self.key) }
    }

    private init() {
        switch UserDefaults.standard.string(forKey: Self.key) {
        case "12": twelveHour = true
        case "24": twelveHour = false
        default: twelveHour = Self.phoneUses12Hour
        }
    }

    /// The phone's own setting (Settings › General › Date & Time › 24-Hour Time, and the region).
    static var phoneUses12Hour: Bool {
        (DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")
    }
}
