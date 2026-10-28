import Foundation
import Observation
import PetCore

/// Everything about the pet that lives on this phone: adoption day, friendship, daily
/// treat, memories, and the last health snapshots (so the pet shows up instantly, offline too).
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

    private let defaults: UserDefaults
    private var pats: [String: Int]

    private enum Keys {
        static let adoptedOn = "adoptedOn"
        static let memories = "memories"
        static let bondPoints = "bondPoints"
        static let lastTreatDay = "lastTreatDay"
        static let pats = "pats"
        static let snapshots = "cachedSnapshots"
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
