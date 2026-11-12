import Foundation
import Observation
import PetCore

/// The booked credits (点击 = 入账, PRD v0.2 §4.4): which food bubbles were eaten (tapped, or
/// collected for the user at 04:00), each with its ledger line. Live data's book is kept on this
/// phone and in iCloud's key-value store (PRD v0.3 §9); demo data gets a fresh book every launch,
/// so the simulator always has food.
@MainActor
@Observable
final class CreditBook {
    /// Newest last.
    private(set) var records: [CreditRecord]
    /// Credits from this day on get a ledger line when collected at 04:00; earlier days are the
    /// history the first open showed, booked without one.
    private(set) var since: Date

    @ObservationIgnored private(set) var bookedIDs: Set<String>
    private let defaults: UserDefaults?
    private let cloud: NSUbiquitousKeyValueStore?
    /// Enough for a year of lines; older ones only fall off the bottom of Memories.
    private static let limit = 1_500

    private enum Keys {
        static let records = "3d.credits"
        static let since = "3d.creditsSince"
    }

    /// `defaults` nil = nothing is saved (demo data). `history` = how many days before today get
    /// ledger lines on a fresh book (demo: 6, so Memories shows this week's collected food).
    init(defaults: UserDefaults?, cloud: NSUbiquitousKeyValueStore? = nil, history: Int = 0) {
        self.defaults = defaults
        self.cloud = defaults == nil ? nil : cloud
        if let defaults, let saved = defaults.object(forKey: Keys.since) as? Date {
            since = saved
        } else {
            let today = Calendar.current.startOfDay(for: Date())
            let start = Calendar.current.date(byAdding: .day, value: -history, to: today) ?? today
            since = start
            defaults?.set(start, forKey: Keys.since)
        }
        let savedRecords = defaults?.data(forKey: Keys.records)
            .flatMap { try? JSONDecoder().decode([CreditRecord].self, from: $0) } ?? []
        records = savedRecords
        bookedIDs = Set(savedRecords.map(\.id))
    }

    func add(_ new: [CreditRecord]) {
        let fresh = new.filter { !bookedIDs.contains($0.id) }
        guard !fresh.isEmpty else { return }
        records.append(contentsOf: fresh)
        if records.count > Self.limit { records.removeFirst(records.count - Self.limit) }
        bookedIDs = Set(records.map(\.id))
        save()
    }

    /// The pet's level went up with this booking: the ledger line says "Lv 15 → 16".
    func setLevels(_ id: String, from: Int, to: Int) {
        guard let index = records.lastIndex(where: { $0.id == id }) else { return }
        records[index].levelFrom = from
        records[index].levelTo = to
        save()
    }

    /// Test build: taps are given back, so the bubbles grow again. (Live data: a pet's
    /// experience already saved stays; the cells and the ledger lines go.)
    func unbook(where shouldGo: (CreditRecord) -> Bool) {
        records.removeAll(where: shouldGo)
        bookedIDs = Set(records.map(\.id))
        save()
    }

    // MARK: - iCloud

    /// Takes in the lines iCloud has that this phone doesn't (after a reinstall, or from another
    /// iPhone), in booking order, and the earlier start. Returns whether anything changed.
    @discardableResult
    func mergeFromCloud() -> Bool {
        guard let cloud else { return false }
        var changed = false
        if let theirs = cloud.object(forKey: Keys.since) as? Date, theirs < since {
            since = theirs
            defaults?.set(theirs, forKey: Keys.since)
            changed = true
        }
        let theirs = cloud.data(forKey: Keys.records).flatMap { try? JSONDecoder().decode([CreditRecord].self, from: $0) } ?? []
        let new = theirs.filter { !bookedIDs.contains($0.id) }
        if !new.isEmpty {
            records = (records + new).sorted { $0.bookedAt < $1.bookedAt }
            if records.count > Self.limit { records.removeFirst(records.count - Self.limit) }
            bookedIDs = Set(records.map(\.id))
            save(toCloud: false)
            changed = true
        }
        return changed
    }

    /// Puts the book into iCloud as this phone has it.
    func pushToCloud() {
        guard let cloud, let defaults else { return }
        cloud.set(defaults.object(forKey: Keys.since), forKey: Keys.since)
        cloud.set(defaults.data(forKey: Keys.records), forKey: Keys.records)
    }

    private func save(toCloud: Bool = true) {
        let data = try? JSONEncoder().encode(records)
        defaults?.set(data, forKey: Keys.records)
        if toCloud { cloud?.set(data, forKey: Keys.records) }
    }
}
