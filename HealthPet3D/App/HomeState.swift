import SwiftUI
import Observation
import PetCore

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// What this app remembers about the home screen, on this phone: whether the pet already woke
/// up today, what was already celebrated, which new pets were seen, whether the tour was shown,
/// and a few settings. (Which food bubbles were eaten is the credit book's, see `CreditBook`.)
@MainActor
@Observable
final class HomeState {
    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    /// Shown on share cards, e.g. "WaTell". Empty = only the dates.
    var userName: String {
        didSet { defaults.set(userName, forKey: Keys.userName) }
    }
    /// The first open (the last 30 days as a highlight, then the bedtime) is done.
    var onboarded: Bool {
        didSet { defaults.set(onboarded, forKey: Keys.onboarded) }
    }
    /// The two notifications (PRD v0.2), both off until the user turns them on.
    var notifyBedtime: Bool {
        didSet { defaults.set(notifyBedtime, forKey: Keys.notifyBedtime) }
    }
    var notifyMorning: Bool {
        didSet { defaults.set(notifyMorning, forKey: Keys.notifyMorning) }
    }
    /// The pet asked once, after the first on-time moon, whether to yawn before bed (PRD v0.3 §6).
    /// Whatever the answer, it never asks again; the switch stays in Settings.
    var askedAboutBedtime: Bool {
        didSet { defaults.set(askedAboutBedtime, forKey: Keys.askedAboutBedtime) }
    }
    /// Test build: show a pet energy other than the one the data gives (nil = from the data).
    var energyOverride: PetEnergy? {
        didSet { defaults.set(energyOverride?.rawValue, forKey: Keys.energyOverride) }
    }
    /// The 3-step tour of home (PRD v0.2 §6, v3.4) was shown; 「Show me around」 shows it again.
    var tourDone: Bool {
        didSet { defaults.set(tourDone, forKey: Keys.tourDone) }
    }
    private var wokeUpOn: Date?
    private(set) var seenPets: Set<String>
    /// Pets whose arrival was already celebrated with 星星眼.
    private var welcomedPets: Set<String>
    /// The week whose 自律周 was already celebrated (and its share card offered).
    private var celebratedWeek: Date?
    /// Each pet's level at the last morning, for 「Chili is Lv 4 now!」.
    private var levelsAtMorning: [String: Int]
    /// Whole days between the previous open and today's first one (0 = opened yesterday too… 1 = skipped a day).
    private(set) var daysAway = 0

    private let defaults: UserDefaults
    private let calendar = Calendar.current

    private enum Keys {
        static let appearance = "3d.appearance"
        static let userName = "3d.userName"
        static let tourDone = "3d.tourDone"
        static let wokeUpOn = "3d.wokeUpOn"
        static let seenPets = "3d.seenPets"
        static let onboarded = "3d.onboarded"
        static let notifyBedtime = "3d.notifyBedtime"
        static let notifyMorning = "3d.notifyMorning"
        static let askedAboutBedtime = "3d.askedAboutBedtime"
        static let energyOverride = "3d.energyOverride"
        static let welcomedPets = "3d.welcomedPets"
        static let celebratedWeek = "3d.celebratedWeek"
        static let levelsAtMorning = "3d.levelsAtMorning"
        static func once(_ name: String) -> String { "3d.once.\(name)" }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Keys.appearance).flatMap(Appearance.init) ?? .system
        userName = defaults.string(forKey: Keys.userName) ?? ""
        tourDone = defaults.bool(forKey: Keys.tourDone)
        wokeUpOn = defaults.object(forKey: Keys.wokeUpOn) as? Date
        seenPets = Set(defaults.stringArray(forKey: Keys.seenPets) ?? [])
        onboarded = defaults.bool(forKey: Keys.onboarded)
        notifyBedtime = defaults.bool(forKey: Keys.notifyBedtime)
        notifyMorning = defaults.bool(forKey: Keys.notifyMorning)
        askedAboutBedtime = defaults.bool(forKey: Keys.askedAboutBedtime)
        energyOverride = defaults.string(forKey: Keys.energyOverride).flatMap(PetEnergy.init(rawValue:))
        welcomedPets = Set(defaults.stringArray(forKey: Keys.welcomedPets) ?? [])
        celebratedWeek = defaults.object(forKey: Keys.celebratedWeek) as? Date
        levelsAtMorning = defaults.dictionary(forKey: Keys.levelsAtMorning) as? [String: Int] ?? [:]
    }

    private var today: Date { calendar.startOfDay(for: Date()) }

    // MARK: - Once a day

    /// True the first time it is asked on a new day: the pet plays 醒来.
    func takeMorning() -> Bool {
        guard wokeUpOn != today else { return false }
        if let last = wokeUpOn {
            daysAway = max(0, (calendar.dateComponents([.day], from: last, to: today).day ?? 1) - 1)
        } else {
            daysAway = 0
        }
        wokeUpOn = today
        defaults.set(today, forKey: Keys.wokeUpOn)
        return true
    }

    /// True the first time `name` is asked today (one puzzled look, one "almost there" a day).
    func takeOnceToday(_ name: String) -> Bool {
        let key = Keys.once(name)
        if let last = defaults.object(forKey: key) as? Date, last == today { return false }
        defaults.set(today, forKey: key)
        return true
    }

    // MARK: - Pets arriving, levels going up

    /// Unlocked pets that haven't had their 星星眼 welcome yet (they count as welcomed now).
    func takeNewPets(_ unlocked: [Pet3D]) -> [Pet3D] {
        let new = unlocked.filter { $0.activity != nil && !welcomedPets.contains($0.id) }
        guard !new.isEmpty else { return [] }
        welcomedPets.formUnion(new.map(\.id))
        defaults.set(Array(welcomedPets), forKey: Keys.welcomedPets)
        return new
    }

    /// The first open already showed every pet so far: no welcome for those.
    func welcomeQuietly(_ pets: [Pet3D]) {
        welcomedPets.formUnion(pets.map(\.id))
        defaults.set(Array(welcomedPets), forKey: Keys.welcomedPets)
    }

    /// Pets whose level went up since the last morning (new pets left out: they get 星星眼).
    /// The first time it only remembers the levels.
    func takeLevelUps(_ levels: [String: Int]) -> [Pet3D] {
        defer {
            levelsAtMorning = levels
            defaults.set(levels, forKey: Keys.levelsAtMorning)
        }
        guard !levelsAtMorning.isEmpty else { return [] }
        return levels.filter { id, level in levelsAtMorning[id].map { level > $0 } ?? false }
            .sorted { $0.value > $1.value }
            .compactMap { Pet3D.with(id: $0.key) }
    }

    // MARK: - 自律周

    /// True once per week, the first time the week counts. Never for a week before the last one
    /// celebrated, so last week's late cheer (PRD v0.3 §4.4) can't come after this week's.
    func takeWeekCelebration(weekStart: Date) -> Bool {
        if let celebratedWeek, weekStart <= celebratedWeek { return false }
        celebratedWeek = weekStart
        defaults.set(weekStart, forKey: Keys.celebratedWeek)
        return true
    }

    func replayMorning() {
        wokeUpOn = nil
        defaults.removeObject(forKey: Keys.wokeUpOn)
    }

    // MARK: - New pets

    func hasUnseen(_ unlocked: [Pet3D]) -> Bool {
        unlocked.contains { !seenPets.contains($0.id) }
    }

    func markSeen(_ pets: [Pet3D]) {
        let ids = Set(pets.map(\.id))
        guard !ids.isSubset(of: seenPets) else { return }
        seenPets.formUnion(ids)
        defaults.set(Array(seenPets), forKey: Keys.seenPets)
    }
}
