import Foundation
import Observation
import PetCore

enum DataSourceChoice: String, CaseIterable, Identifiable {
    case appleHealth, whoop, demo
    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleHealth: "Apple Health"
        case .whoop: "Whoop"
        case .demo: "Demo data"
        }
    }
}

/// App-wide state: picks a data source, refreshes, and turns data into the pet's state.
@MainActor
@Observable
final class AppModel {
    private(set) var petState: PetState = .neutral
    private(set) var today: HealthSnapshot?
    private(set) var memories: [MemoryEvent] = []
    private(set) var isLoading = false
    private(set) var bond = Bond()
    private(set) var lastTreatDay: Date?
    private(set) var patsToday = 0
    /// Bumped on every pat or treat so the pet view can play a reaction.
    private(set) var reactionCount = 0
    var errorMessage: String?

    var sourceChoice: DataSourceChoice {
        didSet { defaults.set(sourceChoice.rawValue, forKey: Keys.source) }
    }
    var demoScenario: PetMood = .golden
    var skin: any CharacterSkin = CharacterCatalog.defaultSkin
    var sleepSchedule = SleepSchedule()

    /// The day the user got their pet; anniversaries count from here.
    let adoptedOn: Date

    private let engine = PetStateEngine()
    private let memoryDetector = MemoryDetector()
    private let defaults: UserDefaults

    private enum Keys {
        static let source = "dataSource"
        static let adoptedOn = "adoptedOn"
        static let memories = "memories"
        static let bondPoints = "bondPoints"
        static let lastTreatDay = "lastTreatDay"
        static let pats = "pats"
    }

    static let pointsPerPat = 1
    static let maxPatPointsPerDay = 10
    static let pointsPerTreat = 10

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        #if targetEnvironment(simulator)
        let fallback = DataSourceChoice.demo
        #else
        let fallback = DataSourceChoice.appleHealth
        #endif
        sourceChoice = defaults.string(forKey: Keys.source).flatMap(DataSourceChoice.init) ?? fallback

        if let saved = defaults.object(forKey: Keys.adoptedOn) as? Date {
            adoptedOn = saved
        } else {
            adoptedOn = Date()
            defaults.set(adoptedOn, forKey: Keys.adoptedOn)
        }

        if let data = defaults.data(forKey: Keys.memories),
           let saved = try? JSONDecoder().decode([MemoryEvent].self, from: data) {
            memories = saved
        }

        bond = Bond(points: defaults.integer(forKey: Keys.bondPoints))
        lastTreatDay = defaults.object(forKey: Keys.lastTreatDay) as? Date
        if let pats = defaults.dictionary(forKey: Keys.pats) as? [String: Int] {
            patsToday = pats[Self.dayKey(Date())] ?? 0
        }
    }

    // MARK: - Bond

    var daysTogether: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: adoptedOn), to: calendar.startOfDay(for: Date())).day ?? 0
        return days + 1
    }

    var canClaimTreat: Bool {
        guard let last = lastTreatDay else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    /// Patting always gets a reaction; only the first few pats a day add bond points.
    func pat() {
        reactionCount += 1
        let today = Self.dayKey(Date())
        patsToday = (defaults.dictionary(forKey: Keys.pats) as? [String: Int])?[today] ?? 0
        guard patsToday < Self.maxPatPointsPerDay else { return }
        patsToday += 1
        defaults.set([today: patsToday], forKey: Keys.pats)
        addBond(Self.pointsPerPat)
    }

    /// The daily treat: opening the app and checking on the pet is the reward loop.
    func claimTreat() {
        guard canClaimTreat else { return }
        lastTreatDay = Date()
        defaults.set(lastTreatDay, forKey: Keys.lastTreatDay)
        reactionCount += 1
        addBond(Self.pointsPerTreat)
    }

    private func addBond(_ amount: Int) {
        bond.add(amount)
        defaults.set(bond.points, forKey: Keys.bondPoints)
    }

    private static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private var provider: any HealthDataProvider {
        switch sourceChoice {
        case .appleHealth: return HealthKitProvider()
        case .whoop: return WhoopProvider(backendBaseURL: nil)
        case .demo: return DemoHealthProvider(scenario: demoScenario)
        }
    }

    func connect() async {
        do {
            try await provider.requestAuthorization()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Pulls the last 30 days and re-evaluates the pet. Called on launch and when the app comes to the foreground.
    func refresh(now: Date = Date()) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let start = Calendar.current.date(byAdding: .day, value: -PersonalBaseline.windowDays, to: now)!
            let snapshots = try await provider.snapshots(from: start, to: now)
            let todayStart = Calendar.current.startOfDay(for: now)
            guard let todaySnapshot = snapshots.first(where: { $0.day == todayStart }) else { return }
            let history = snapshots.filter { $0.day < todayStart }

            today = todaySnapshot
            var state = engine.evaluate(today: todaySnapshot, history: history)
            state.isAsleep = sleepSchedule.isBedtime(at: now)
            petState = state

            let found = memoryDetector.newMemories(today: todaySnapshot, history: history, adoptedOn: adoptedOn, existing: memories)
            if !found.isEmpty {
                memories.append(contentsOf: found)
                saveMemories()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveMemories() {
        if let data = try? JSONEncoder().encode(memories) {
            defaults.set(data, forKey: Keys.memories)
        }
    }
}

/// The pet falls asleep on its own at bedtime; no "sleep together" tap for wearable users.
/// TODO: learn bedtime from the user's real sleep onset, and also require the phone to be idle.
struct SleepSchedule {
    var bedtimeHour = 23
    var wakeHour = 7

    func isBedtime(at date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return bedtimeHour > wakeHour
            ? (hour >= bedtimeHour || hour < wakeHour)
            : (hour >= bedtimeHour && hour < wakeHour)
    }
}
