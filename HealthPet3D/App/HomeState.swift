import SwiftUI
import Observation

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

/// What this app remembers about the home screen, on this phone: which food bubbles were
/// eaten today, whether the pet already woke up today, what was already celebrated, which
/// new pets were seen, and a few settings.
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
    /// Food bubbles eaten today: bubble id → the value it had when eaten.
    private(set) var eaten: [String: Double]
    private var eatenDay: Date?
    private var wokeUpOn: Date?
    private var celebratedDay: Date?
    private var celebrated: Int
    private(set) var seenPets: Set<String>

    private let defaults: UserDefaults
    private let calendar = Calendar.current

    private enum Keys {
        static let appearance = "3d.appearance"
        static let userName = "3d.userName"
        static let eaten = "3d.eaten"
        static let eatenDay = "3d.eatenDay"
        static let wokeUpOn = "3d.wokeUpOn"
        static let celebratedDay = "3d.celebratedDay"
        static let celebrated = "3d.celebrated"
        static let seenPets = "3d.seenPets"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Keys.appearance).flatMap(Appearance.init) ?? .system
        userName = defaults.string(forKey: Keys.userName) ?? ""
        eaten = defaults.dictionary(forKey: Keys.eaten) as? [String: Double] ?? [:]
        eatenDay = defaults.object(forKey: Keys.eatenDay) as? Date
        wokeUpOn = defaults.object(forKey: Keys.wokeUpOn) as? Date
        celebratedDay = defaults.object(forKey: Keys.celebratedDay) as? Date
        celebrated = defaults.integer(forKey: Keys.celebrated)
        seenPets = Set(defaults.stringArray(forKey: Keys.seenPets) ?? [])
    }

    private var today: Date { calendar.startOfDay(for: Date()) }

    // MARK: - Food bubbles

    /// The value a bubble had when it was eaten today, nil if it hasn't been.
    func eatenValue(_ id: String) -> Double? {
        eatenDay == today ? eaten[id] : nil
    }

    func eat(_ id: String, value: Double) {
        if eatenDay != today {
            eaten = [:]
            eatenDay = today
            defaults.set(today, forKey: Keys.eatenDay)
        }
        eaten[id] = value
        defaults.set(eaten, forKey: Keys.eaten)
    }

    func regrowFood() {
        eaten = [:]
        defaults.set(eaten, forKey: Keys.eaten)
    }

    // MARK: - Once a day

    /// True the first time it is asked on a new day: the pet plays 醒来.
    func takeMorning() -> Bool {
        guard wokeUpOn != today else { return false }
        wokeUpOn = today
        defaults.set(today, forKey: Keys.wokeUpOn)
        return true
    }

    func replayMorning() {
        wokeUpOn = nil
        defaults.removeObject(forKey: Keys.wokeUpOn)
    }

    /// True when today has more check-ins than were celebrated so far (then they count as celebrated).
    func takeCelebration(checkIns: Int) -> Bool {
        if celebratedDay != today {
            celebratedDay = today
            celebrated = 0
            defaults.set(today, forKey: Keys.celebratedDay)
        }
        guard checkIns > celebrated else { return false }
        celebrated = checkIns
        defaults.set(celebrated, forKey: Keys.celebrated)
        return true
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
