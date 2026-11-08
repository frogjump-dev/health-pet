import Foundation
import Observation
import PetCore

/// Everything about the pet that lives on this phone: adoption day, friendship, daily
/// treat, memories, finished 自律周, and the last health snapshots (so the pet shows up instantly, offline too).
/// Backed by UserDefaults for now; swap the storage here when it outgrows that.
@MainActor
@Observable
final class PetStore {
    static let pointsPerPat = 1
    static let maxPatPointsPerDay = 10
    static let pointsPerTreat = 10

    let adoptedOn: Date
    private(set) var bond: Bond
    private(set) var lastTreatDay: Date?
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

    private let defaults: UserDefaults
    private var pats: [String: Int]

    private enum Keys {
        static let adoptedOn = "adoptedOn"
        static let memories = "memories"
        static let bondPoints = "bondPoints"
        static let lastTreatDay = "lastTreatDay"
        static let pats = "pats"
        static let snapshots = "cachedSnapshots"
        static let disciplinedWeeks = "disciplinedWeeks"
        static let activityLog = "activityLog"
        static let leaveDays = "leaveDays"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let saved = defaults.object(forKey: Keys.adoptedOn) as? Date {
            adoptedOn = saved
        } else {
            adoptedOn = Date()
            defaults.set(adoptedOn, forKey: Keys.adoptedOn)
        }
        bond = Bond(points: defaults.integer(forKey: Keys.bondPoints))
        lastTreatDay = defaults.object(forKey: Keys.lastTreatDay) as? Date
        pats = defaults.dictionary(forKey: Keys.pats) as? [String: Int] ?? [:]
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

    // MARK: - Friendship

    var daysTogether: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: adoptedOn),
                                           to: calendar.startOfDay(for: Date())).day ?? 0
        return days + 1
    }

    var canClaimTreat: Bool {
        guard let last = lastTreatDay else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    /// Only the first few pats a day add points.
    func recordPat(now: Date = Date()) {
        let key = Self.dayKey(now)
        let count = pats[key] ?? 0
        guard count < Self.maxPatPointsPerDay else { return }
        pats = [key: count + 1]
        defaults.set(pats, forKey: Keys.pats)
        addBond(Self.pointsPerPat)
    }

    /// Returns false if today's treat was already claimed.
    @discardableResult
    func claimTreat(now: Date = Date()) -> Bool {
        guard canClaimTreat else { return false }
        lastTreatDay = now
        defaults.set(now, forKey: Keys.lastTreatDay)
        addBond(Self.pointsPerTreat)
        return true
    }

    private func addBond(_ amount: Int) {
        bond.add(amount)
        defaults.set(bond.points, forKey: Keys.bondPoints)
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

    private static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
