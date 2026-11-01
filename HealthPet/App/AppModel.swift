import Foundation
import Observation
import PetCore

/// Live = the phone's Apple Health data plus Whoop (when linked), merged per day.
/// Demo = generated data, for the simulator and previews.
enum DataMode: String, CaseIterable, Identifiable {
    case live, demo
    var id: String { rawValue }
}

enum WhoopStatus: Equatable {
    case unavailable   // this build has no backend configured
    case notConnected
    case connected
}

/// App-wide state: gathers health data from every source, turns it into the pet's state,
/// and exposes the pet store to the views.
@MainActor
@Observable
final class AppModel {
    private(set) var petState: PetState = .neutral
    private(set) var today: HealthSnapshot?
    /// This calendar week's 自律周 progress.
    private(set) var week: WeekProgress?
    /// On-time nights in a row, up to last night.
    private(set) var onTimeStreak = 0
    private(set) var isLoading = false
    private(set) var whoopStatus: WhoopStatus
    /// HealthKit never reveals whether read access was granted, so this only records that
    /// the user went through the permission sheet.
    private(set) var appleHealthConnected: Bool
    /// Bumped on every pat or treat so the pet view can play a reaction.
    private(set) var reactionCount = 0
    var errorMessage: String?

    var dataMode: DataMode {
        didSet { defaults.set(dataMode.rawValue, forKey: Keys.dataMode) }
    }
    var demoScenario: PetMood = .golden
    var skin: any CharacterSkin = CharacterCatalog.defaultSkin
    var sleepSchedule = SleepSchedule()

    let store: PetStore

    private let engine = PetStateEngine()
    private let memoryDetector = MemoryDetector()
    private let healthKit = HealthKitProvider()
    private let whoop: WhoopProvider
    private let whoopConnector = WhoopConnector()
    private let backend: Backend?
    private let defaults: UserDefaults

    private enum Keys {
        static let dataMode = "dataMode"
        static let whoopConnected = "whoopConnected"
        static let appleHealthConnected = "appleHealthConnected"
    }

    init(defaults: UserDefaults = .standard, backend: Backend? = Backend.shared) {
        self.defaults = defaults
        self.backend = backend
        store = PetStore(defaults: defaults)
        whoop = WhoopProvider(backend: backend)

        #if targetEnvironment(simulator)
        let fallback = DataMode.demo
        #else
        let fallback = DataMode.live
        #endif
        dataMode = defaults.string(forKey: Keys.dataMode).flatMap(DataMode.init) ?? fallback
        appleHealthConnected = defaults.bool(forKey: Keys.appleHealthConnected)

        if backend == nil {
            whoopStatus = .unavailable
        } else {
            whoopStatus = defaults.bool(forKey: Keys.whoopConnected) ? .connected : .notConnected
        }

        // Show yesterday's pet straight away; refresh() replaces it with fresh data.
        evaluate(store.cachedSnapshots, now: Date(), recordMemories: false)
    }

    // MARK: - Pet interactions (forwarded so views only talk to the model)

    var bond: Bond { store.bond }
    var memories: [MemoryEvent] { store.memories }
    var daysTogether: Int { store.daysTogether }
    var canClaimTreat: Bool { store.canClaimTreat }

    /// The pets standing in the room, main pet first.
    /// TODO: the starter four stand in until the collection (出炉券) is built.
    var homePets: [RosterPet] { RosterPet.starters }

    var discipline: DisciplineTracker {
        DisciplineTracker(bedtime: Bedtime(hour: sleepSchedule.bedtimeHour))
    }

    /// Which week of the current 4-week achievement block this is (1...4), counted from adoption.
    var weekInBlock: Int {
        let tracker = discipline
        let weeks = Calendar.current.dateComponents([.weekOfYear], from: tracker.weekStart(for: store.adoptedOn),
                                                    to: tracker.weekStart(for: Date())).weekOfYear ?? 0
        return weeks % tracker.rules.weeksPerBlock + 1
    }

    var disciplinedWeekCount: Int { store.disciplinedWeeks.count }

    /// The main pet's bubble: cheers for what got logged, otherwise how it feels. Never a score.
    var homeLine: String {
        if petState.isAsleep { return skin.greeting(for: petState) }
        if onTimeStreak >= 2 { return "Slept on time \(onTimeStreak) nights!" }
        if let today, discipline.countsAsWorkout(today) {
            return today.workoutType.map { "\($0) logged. Proud of you!" } ?? "10k steps today. Nice walking!"
        }
        return skin.greeting(for: petState)
    }

    func pat() {
        reactionCount += 1
        store.recordPat()
    }

    func claimTreat() {
        if store.claimTreat() { reactionCount += 1 }
    }

    // MARK: - Sources

    func connectAppleHealth() async {
        do {
            try await healthKit.requestAuthorization()
            appleHealthConnected = true
            defaults.set(true, forKey: Keys.appleHealthConnected)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connectWhoop() async {
        guard let backend else { return }
        do {
            try await whoopConnector.connect(backend: backend)
            setWhoopConnected(true)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnectWhoop() async {
        do {
            try await whoop.disconnect()
            setWhoopConnected(false)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setWhoopConnected(_ connected: Bool) {
        guard backend != nil else { return }
        whoopStatus = connected ? .connected : .notConnected
        defaults.set(connected, forKey: Keys.whoopConnected)
    }

    // MARK: - Refresh

    /// Pulls the last 30 days from every source, merges them per day and re-evaluates the pet.
    /// Called on launch and whenever the app comes to the foreground.
    func refresh(now: Date = Date()) async {
        isLoading = true
        defer { isLoading = false }

        let start = Calendar.current.date(byAdding: .day, value: -PersonalBaseline.windowDays, to: now)!
        var collected: [HealthSnapshot] = []
        var failures: [Error] = []

        switch dataMode {
        case .demo:
            collected = (try? await DemoHealthProvider(scenario: demoScenario).snapshots(from: start, to: now)) ?? []

        case .live:
            // Asks only for types added since the user first connected (e.g. workouts); no sheet otherwise.
            if appleHealthConnected { try? await healthKit.requestAuthorization() }
            let healthKit = healthKit, whoop = whoop
            // Unconnected sources are skipped rather than reported as errors.
            let phoneLinked = appleHealthConnected
            let whoopLinked = whoopStatus == .connected
            async let phone = phoneLinked ? Self.fetch(healthKit, from: start, to: now) : .success([])
            async let band = whoopLinked ? Self.fetch(whoop, from: start, to: now) : .success([])

            for result in await [phone, band] {
                switch result {
                case .success(let snapshots): collected += snapshots
                case .failure(WhoopError.notConnected): setWhoopConnected(false)
                case .failure(let error): failures.append(error)
                }
            }
        }

        let merged = SnapshotMerger.merge(collected)
        if !merged.isEmpty {
            if dataMode == .live { store.cache(merged) }
            evaluate(merged, now: now, recordMemories: true)
        }
        // Only complain when nothing worked; a single failing source just falls back to the others.
        errorMessage = merged.isEmpty ? failures.first?.localizedDescription : nil
    }

    nonisolated private static func fetch(_ provider: any HealthDataProvider, from start: Date, to end: Date) async -> Result<[HealthSnapshot], Error> {
        do {
            return .success(try await provider.snapshots(from: start, to: end))
        } catch {
            return .failure(error)
        }
    }

    private func evaluate(_ snapshots: [HealthSnapshot], now: Date, recordMemories: Bool) {
        let todayStart = Calendar.current.startOfDay(for: now)
        guard let todaySnapshot = snapshots.first(where: { $0.day == todayStart }) else { return }
        let history = snapshots.filter { $0.day < todayStart }

        today = todaySnapshot
        var state = engine.evaluate(today: todaySnapshot, history: history)
        state.isAsleep = sleepSchedule.isBedtime(at: now)
        petState = state

        let tracker = discipline
        week = tracker.week(containing: now, snapshots: snapshots)
        onTimeStreak = tracker.onTimeStreak(snapshots)
        if recordMemories && dataMode == .live {
            store.recordDisciplinedWeeks(tracker.disciplinedWeeks(in: snapshots, before: now))
        }

        if recordMemories {
            store.addMemories(memoryDetector.newMemories(today: todaySnapshot, history: history,
                                                         adoptedOn: store.adoptedOn, existing: store.memories))
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
