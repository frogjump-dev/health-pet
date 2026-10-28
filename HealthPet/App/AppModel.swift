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
    var errorMessage: String?

    var sourceChoice: DataSourceChoice {
        didSet { defaults.set(sourceChoice.rawValue, forKey: Keys.source) }
    }
    var demoScenario: PetMood = .golden
    var skin: any CharacterSkin = CharacterCatalog.defaultSkin
    var sleepSchedule = SleepSchedule()

    /// The day the user got their pet; anniversaries count from here.
    let adoptedOn: Date

    /// Warmth earned by caring for the pet; fills the level bar. Never tied to health scores.
    private(set) var warmth: Int {
        didSet { defaults.set(warmth, forKey: Keys.warmth) }
    }
    private var lastPatDay: Date? {
        didSet { defaults.set(lastPatDay, forKey: Keys.lastPatDay) }
    }

    private let engine = PetStateEngine()
    private let memoryDetector = MemoryDetector()
    private let defaults: UserDefaults

    private enum Keys {
        static let source = "dataSource"
        static let adoptedOn = "adoptedOn"
        static let memories = "memories"
        static let warmth = "warmth"
        static let lastPatDay = "lastPatDay"
    }

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

        warmth = defaults.integer(forKey: Keys.warmth)
        lastPatDay = defaults.object(forKey: Keys.lastPatDay) as? Date

        if let data = defaults.data(forKey: Keys.memories),
           let saved = try? JSONDecoder().decode([MemoryEvent].self, from: data) {
            memories = saved
        }
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

    // MARK: Companionship

    /// Day 1 is the adoption day.
    var daysTogether: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: adoptedOn), to: calendar.startOfDay(for: Date())).day ?? 0
        return days + 1
    }

    /// Each level needs a bit more warmth than the last: 100, 150, 200, …
    var level: (number: Int, current: Int, needed: Int) {
        var number = 1
        var remaining = warmth
        var needed = 100
        while remaining >= needed {
            remaining -= needed
            number += 1
            needed += 50
        }
        return (number, remaining, needed)
    }

    var canPatToday: Bool {
        guard let lastPatDay else { return true }
        return !Calendar.current.isDateInToday(lastPatDay)
    }

    /// The once-a-day pat on the head.
    func pat() {
        guard canPatToday else { return }
        warmth += 10
        lastPatDay = Date()
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
