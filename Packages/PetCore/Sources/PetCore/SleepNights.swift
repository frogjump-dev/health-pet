import Foundation

/// Sorts the stretches of sleep Apple Health returns into nights (PRD v0.3 §7.2).
///
/// Apple Health has no "fell asleep at" value, only stretches of sleep (core, deep, REM…) written
/// one after another, often by several sources at once. The app only decides which stretches
/// belong to which night and reads the rest as recorded:
/// - a night is every stretch that starts between 18:00 one day and 18:00 the next, and it counts
///   on the morning you wake up (a night that starts at 22:48 on Sunday is Monday's night);
/// - asleep at = the start of that night's first stretch;
/// - hours = the stretches added up, overlaps counted once;
/// - woke at = the end of the last stretch that started before noon, so an afternoon nap does
///   not move it.
public enum SleepNights {
    /// Sleep that starts at or after this hour belongs to the next morning's night.
    public static let cutHour = 18
    /// Stretches starting at or after this hour on the wake-up day are naps for the wake time.
    public static let napFromHour = 12

    public struct Night: Equatable, Sendable {
        public var hours: Double
        public var onset: Date
        public var wake: Date

        public init(hours: Double, onset: Date, wake: Date) {
            self.hours = hours
            self.onset = onset
            self.wake = wake
        }
    }

    /// The day (its start) whose morning a stretch of sleep starting at `start` counts on.
    public static func wakeDay(forSleepStartingAt start: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: start)
        guard calendar.component(.hour, from: start) >= cutHour else { return day }
        return calendar.date(byAdding: .day, value: 1, to: day) ?? day
    }

    /// Nights keyed by the day they count on.
    public static func nights(_ stretches: [DateInterval], calendar: Calendar) -> [Date: Night] {
        let byDay = Dictionary(grouping: stretches) { wakeDay(forSleepStartingAt: $0.start, calendar: calendar) }
        return byDay.reduce(into: [:]) { result, entry in
            let (day, night) = entry
            guard let onset = night.map(\.start).min() else { return }
            let noon = calendar.date(byAdding: .hour, value: napFromHour, to: day) ?? day
            let beforeNoon = night.filter { $0.start < noon }
            let wake = (beforeNoon.isEmpty ? night : beforeNoon).map(\.end).max() ?? onset
            result[day] = Night(hours: mergedDuration(night) / 3600, onset: onset, wake: wake)
        }
    }

    /// Total time covered by `intervals`, overlaps counted once.
    public static func mergedDuration(_ intervals: [DateInterval]) -> TimeInterval {
        var total: TimeInterval = 0
        var current: DateInterval?
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            if let c = current, interval.start <= c.end {
                current = DateInterval(start: c.start, end: max(c.end, interval.end))
            } else {
                if let c = current { total += c.duration }
                current = interval
            }
        }
        if let c = current { total += c.duration }
        return total
    }
}
