import Foundation
import Observation
import PetCore

/// Everything about the pet that lives on this phone: adoption day, memories, finished 自律周,
/// the activity log, leave days, and the last health snapshots (so the pet shows up instantly, offline too).
/// Backed by UserDefaults for now; swap the storage here when it outgrows that.
@MainActor
@Observable
final class PetStore {
    let adoptedOn: Date
    private(set) var memories: [MemoryEvent]
    private(set) var cachedSnapshots: [HealthSnapshot]
    /// Starts of every finished 自律周. Kept forever: titles and double experience only go up.
    private(set) var disciplinedWeeks: Set<Date>
    /// Which activities each day counted for. Kept forever (the snapshot cache only holds
    /// 30 days), so pets stay unlocked and levels never go down.
    private(set) var activityLog: [Date: Set<Activity>]
    /// Nights the user took as a leave day (the morning each night ended on). One a week counts
    /// as an on-time night, no reason needed.
    private(set) var leaveDays: Set<Date>
    /// 「手表记错了」 (PRD v0.3 §4.2): when the user says they really fell asleep, by the morning
    /// the night ended on. It only decides whether that night was on time; it is not a ledger line.
    private(set) var sleepFixes: [Date: Date]

    private let defaults: UserDefaults

    private enum Keys {
        static let adoptedOn = "adoptedOn"
        static let memories = "memories"
        static let snapshots = "cachedSnapshots"
        static let disciplinedWeeks = "disciplinedWeeks"
        static let activityLog = "activityLog"
        static let leaveDays = "leaveDays"
        static let sleepFixes = "sleepFixes"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let saved = defaults.object(forKey: Keys.adoptedOn) as? Date {
            adoptedOn = saved
        } else {
            adoptedOn = Date()
            defaults.set(adoptedOn, forKey: Keys.adoptedOn)
        }
        memories = Self.decode([MemoryEvent].self, defaults.data(forKey: Keys.memories)) ?? []
        cachedSnapshots = Self.decode([HealthSnapshot].self, defaults.data(forKey: Keys.snapshots)) ?? []
        disciplinedWeeks = Self.decode(Set<Date>.self, defaults.data(forKey: Keys.disciplinedWeeks)) ?? []
        // Read activity names one by one, so a renamed activity never wipes the whole log.
        let names = Self.decode([Date: [String]].self, defaults.data(forKey: Keys.activityLog)) ?? [:]
        activityLog = names.compactMapValues { list in
            let known = Set(list.compactMap(Activity.init(rawValue:)))
            return known.isEmpty ? nil : known
        }
        leaveDays = Self.decode(Set<Date>.self, defaults.data(forKey: Keys.leaveDays)) ?? []
        sleepFixes = Self.decode([Date: Date].self, defaults.data(forKey: Keys.sleepFixes)) ?? [:]
    }

    // MARK: - Watch got it wrong

    /// A night's real time of falling asleep (nil takes the fix back).
    func setSleepFix(_ onset: Date?, nightEnding day: Date) {
        let morning = Calendar.current.startOfDay(for: day)
        var updated = sleepFixes
        updated[morning] = onset
        guard updated != sleepFixes else { return }
        sleepFixes = updated
        defaults.set(try? JSONEncoder().encode(updated), forKey: Keys.sleepFixes)
    }

    // MARK: - Leave days

    /// Marks (or unmarks) the night ending on the morning of `day` as a leave day.
    func setLeave(_ on: Bool, nightEnding day: Date) {
        let morning = Calendar.current.startOfDay(for: day)
        var updated = leaveDays
        if on { updated.insert(morning) } else { updated.remove(morning) }
        guard updated != leaveDays else { return }
        leaveDays = updated
        defaults.set(try? JSONEncoder().encode(updated), forKey: Keys.leaveDays)
    }

    // MARK: - Days together

    var daysTogether: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: adoptedOn),
                                           to: calendar.startOfDay(for: Date())).day ?? 0
        return days + 1
    }

    // MARK: - Memories & cache

    func addMemories(_ new: [MemoryEvent]) {
        guard !new.isEmpty else { return }
        memories.append(contentsOf: new)
        defaults.set(try? JSONEncoder().encode(memories), forKey: Keys.memories)
    }

    /// Adds weeks that counted. Weeks are never removed, even if later data looks different.
    func recordDisciplinedWeeks(_ weekStarts: [Date]) {
        let updated = disciplinedWeeks.union(weekStarts)
        guard updated != disciplinedWeeks else { return }
        disciplinedWeeks = updated
        defaults.set(try? JSONEncoder().encode(updated), forKey: Keys.disciplinedWeeks)
    }

    /// Adds days' activities. Nothing is ever removed, even if later data looks different.
    func recordActivities(_ log: [Date: Set<Activity>]) {
        var updated = activityLog
        for (day, activities) in log {
            updated[day, default: []].formUnion(activities)
        }
        guard updated != activityLog else { return }
        activityLog = updated
        defaults.set(try? JSONEncoder().encode(updated), forKey: Keys.activityLog)
    }

    func cache(_ snapshots: [HealthSnapshot]) {
        cachedSnapshots = snapshots
        defaults.set(try? JSONEncoder().encode(snapshots), forKey: Keys.snapshots)
    }

    // MARK: - Helpers

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
