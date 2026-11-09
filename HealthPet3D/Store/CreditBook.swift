import Foundation
import Observation
import PetCore

/// The booked credits (点击 = 入账, PRD v0.2 §4.4): which food bubbles were eaten (tapped, or
/// collected for the user at 04:00), each with its ledger line. Live data's book is kept on this
/// phone; demo data gets a fresh book every launch, so the simulator always has food.
@MainActor
@Observable
final class CreditBook {
    /// Newest last.
    private(set) var records: [CreditRecord]
    /// Credits from this day on get a ledger line when collected at 04:00; earlier days are the
    /// history the first open showed, booked without one.
    let since: Date

    @ObservationIgnored private(set) var bookedIDs: Set<String>
    private let defaults: UserDefaults?
    /// Enough for a year of lines; older ones only fall off the bottom of Memories.
    private static let limit = 1_500

    private enum Keys {
        static let records = "3d.credits"
        static let since = "3d.creditsSince"
    }

    /// `defaults` nil = nothing is saved (demo data). `history` = how many days before today get
    /// ledger lines on a fresh book (demo: 6, so Memories shows this week's collected food).
    init(defaults: UserDefaults?, history: Int = 0) {
        self.defaults = defaults
        if let defaults, let saved = defaults.object(forKey: Keys.since) as? Date {
            since = saved
        } else {
            let today = Calendar.current.startOfDay(for: Date())
            since = Calendar.current.date(byAdding: .day, value: -history, to: today) ?? today
            defaults?.set(since, forKey: Keys.since)
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

    private func save() {
        defaults?.set(try? JSONEncoder().encode(records), forKey: Keys.records)
    }
}
