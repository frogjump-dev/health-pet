import Foundation
import Observation
import PetCore

/// The wardrobe on this phone (PRD v0.3 §5.4): points, what was drawn, each pet's outfit. Kept in
/// the App Group's defaults and in iCloud's key-value store, like the pet's other records (§9).
/// The rules themselves are `DressUp`'s (PetCore).
@MainActor
@Observable
final class DressUpStore {
    private(set) var state: DressUp
    /// Set when the welcome gift is put on from home: the pet's page says so once and the pet
    /// does 骄傲挺胸 (design v1, D13).
    var justWorn: (pet: String, item: String)?

    private let defaults: UserDefaults
    private let cloud: NSUbiquitousKeyValueStore?
    private static let key = "3d.dressUp"

    init(defaults: UserDefaults = AppGroup.defaults, cloud: NSUbiquitousKeyValueStore? = nil) {
        self.defaults = defaults
        self.cloud = cloud
        state = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(DressUp.self, from: $0) } ?? DressUp()
        #if DEBUG
        if let seed = UserDefaults.standard.string(forKey: "hp3dDressUp") { debugSeed(seed) }
        #endif
    }

    // MARK: - Reading

    var points: Int { state.points }
    var canDraw: Bool { state.canDraw }
    var allCollected: Bool { state.allCollected }
    var collected: Int { state.collected }
    var pointsShort: Int { state.pointsShort }
    var welcomeGiven: Bool { state.welcomeGiven }
    /// Today's point is in (the 「+1 today」 tag in Dress up).
    var gotPointToday: Bool { state.gotPoint(on: DressUp.dayKey(Date())) }

    func owns(_ id: String) -> Bool { state.owns(id) }
    func isNew(_ id: String) -> Bool { state.fresh.contains(id) }
    /// What the pet (its 3D id) wears, in slot order: what its page and home draw on it.
    func outfit(for pet: String) -> [String] { state.outfit(for: pet) }
    func worn(_ slot: DecorSlot, on pet: String) -> String? { state.worn(slot, on: pet) }

    /// "Toast, wearing Cowboy hat and Bandana" (VoiceOver).
    func wearingLabel(_ pet: Pet3D) -> String {
        "\(pet.name), wearing \(wearing(pet) ?? "nothing yet")"
    }

    /// "Cowboy hat and Bandana"; nil when it wears nothing.
    func wearing(_ pet: Pet3D) -> String? {
        let names = outfit(for: pet.id).compactMap { Decor.with(id: $0)?.name }
        guard let last = names.last else { return nil }
        return names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " and " + last
    }

    // MARK: - Changes

    /// The first time the app is active on a day: one point (nothing shows on home).
    @discardableResult
    func collectDailyPoint(now: Date = Date()) -> Bool {
        change { $0.collectPoint(day: DressUp.dayKey(now)) }
    }

    /// Five points for one item not owned yet; nil when there aren't enough.
    func draw() -> String? {
        change { $0.draw() }
    }

    /// The party hat, once, after the tour (and once for those who already did the tour).
    func giveWelcome() -> String? {
        change { $0.giveWelcome() }
    }

    func wear(_ id: String, on pet: String) {
        change { $0.wear(id, on: pet) }
    }

    func takeOff(_ slot: DecorSlot, from pet: String) {
        change { $0.takeOff(slot, from: pet) }
    }

    @discardableResult
    private func change<T>(_ body: (inout DressUp) -> T) -> T {
        var new = state
        let result = body(&new)
        if new != state {
            state = new
            save()
        }
        return result
    }

    // MARK: - iCloud

    /// Takes in another iPhone's (or a reinstall's) wardrobe: days and items add up, the newer
    /// outfits win. Returns whether anything changed here.
    @discardableResult
    func mergeFromCloud() -> Bool {
        guard let cloud, let data = cloud.data(forKey: Self.key),
              let theirs = try? JSONDecoder().decode(DressUp.self, from: data) else { return false }
        var merged = state
        merged.merge(theirs)
        guard merged != state else { return false }
        state = merged
        save(toCloud: false)
        return true
    }

    func pushToCloud() {
        cloud?.set(defaults.data(forKey: Self.key), forKey: Self.key)
    }

    private func save(toCloud: Bool = true) {
        let data = try? JSONEncoder().encode(state)
        defaults.set(data, forKey: Self.key)
        if toCloud { cloud?.set(data, forKey: Self.key) }
    }

    #if DEBUG
    /// For screenshots on the simulator: -hp3dDressUp ready (7 pts, 23 items, the design's outfits) |
    /// short (3 pts) | last (one item left) | all (51) | gift (a new user right after the tour).
    private func debugSeed(_ name: String) {
        var d = DressUp()
        let owned = ["party", "cowboy", "crown", "halo", "bulb", "tophat", "sunglasses", "glasses", "starglasses", "monocle",
                     "mustache", "rose", "lollipop", "whiskers", "bandana", "bowtie", "scarf", "pearls", "medal", "wings",
                     "backpack", "cape", "pinwheel"]
        func days(_ n: Int) -> Set<String> { Set((0..<n).map { "seed-\($0)" }) }
        switch name {
        case "gift":
            break
        case "all":
            d.welcomeGiven = true
            d.owned = Decor.all.map(\.id)
            d.pointDays = days(5 * 50)
        case "last":
            d.welcomeGiven = true
            d.owned = Decor.all.map(\.id).filter { $0 != "surfboard" }
            d.pointDays = days(5 * 49 + 5)
        default:
            d.welcomeGiven = true
            d.owned = owned
            d.pointDays = days(5 * (owned.count - 1) + (name == "short" ? 3 : 7))
        }
        if name != "gift" {
            let have = Set(d.owned)
            let looks = ["toast": ["cowboy", "bandana"], "chili": ["sunglasses"], "coffee": ["tophat", "bowtie"], "pudding": ["halo"]]
            d.outfits = looks.mapValues { items in items.filter { have.contains($0) } }
        }
        d.pointDays.insert(DressUp.dayKey(Date()))
        d.pointDays.remove("seed-0")
        state = d
        // into iCloud too, or the merge at launch would bring back an earlier run's wardrobe
        let data = try? JSONEncoder().encode(d)
        defaults.set(data, forKey: Self.key)
        cloud?.set(data, forKey: Self.key)
    }
    #endif
}
