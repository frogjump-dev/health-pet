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
    /// This calendar week's days so far (Monday first), oldest first, as they count so far:
    /// what still waits as a food bubble is left out (点击 = 入账).
    private(set) var weekDays: [HealthSnapshot] = []
    /// Today as it counts so far (booked), next to `today` as the data has it.
    private(set) var bookedToday: HealthSnapshot?
    /// Credits waiting on home as food bubbles, oldest day first.
    private(set) var pending: [Credit] = []
    /// The user's own 30-day normal before today (HRV measured the same way as today's).
    private(set) var baseline = PersonalBaseline()
    /// On-time nights in a row, up to last night.
    private(set) var onTimeStreak = 0
    /// Each activity's sessions, experience and unlock day; one entry per activity.
    private(set) var activityProgress: [Activity: ActivityProgress] = [:]
    /// Every day's activities so far (live: everything ever recorded; demo: the generated days),
    /// with Protein Bar's two-day streaks added.
    private(set) var activityLog: [Date: Set<Activity>] = [:]
    /// Starts of the finished weeks that counted as 自律周 (live: kept forever).
    private(set) var disciplinedWeekStarts: Set<Date> = []
    /// The pet's slow condition from the last 7 days (PRD v0.2 §5.5).
    private(set) var energy: PetEnergy = .normal
    private(set) var isLoading = false
    private(set) var whoopStatus: WhoopStatus
    /// HealthKit never reveals whether read access was granted, so this only records that
    /// the user went through the permission sheet.
    private(set) var appleHealthConnected: Bool
    var errorMessage: String?

    var dataMode: DataMode {
        didSet { defaults.set(dataMode.rawValue, forKey: Keys.dataMode) }
    }
    var demoScenario: PetMood = .golden
    /// Saved on this phone; changing it re-judges past nights on the next refresh.
    var sleepSchedule: SleepSchedule {
        didSet { defaults.set(try? JSONEncoder().encode(sleepSchedule), forKey: Keys.sleepSchedule) }
    }

    let store: PetStore
    /// Which food bubbles were eaten (PRD v0.2 §4.4). Live data's book is saved; demo data
    /// starts a fresh one every launch.
    private let liveBook: CreditBook
    private let demoBook: CreditBook
    var creditBook: CreditBook { dataMode == .live ? liveBook : demoBook }

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
        static let mainPetID = "mainPetID"
        static let sleepSchedule = "sleepSchedule"
    }

    init(defaults: UserDefaults = .standard, backend: Backend? = Backend.shared) {
        self.defaults = defaults
        self.backend = backend
        store = PetStore(defaults: defaults)
        liveBook = CreditBook(defaults: defaults)
        demoBook = CreditBook(defaults: nil, history: 6)
        whoop = WhoopProvider(backend: backend)

        #if targetEnvironment(simulator)
        let fallback = DataMode.demo
        #else
        let fallback = DataMode.live
        #endif
        dataMode = defaults.string(forKey: Keys.dataMode).flatMap(DataMode.init) ?? fallback
        appleHealthConnected = defaults.bool(forKey: Keys.appleHealthConnected)
        mainPetID = defaults.string(forKey: Keys.mainPetID) ?? RosterPet.toast.id
        sleepSchedule = defaults.data(forKey: Keys.sleepSchedule)
            .flatMap { try? JSONDecoder().decode(SleepSchedule.self, from: $0) } ?? SleepSchedule()

        if backend == nil {
            whoopStatus = .unavailable
        } else {
            whoopStatus = defaults.bool(forKey: Keys.whoopConnected) ? .connected : .notConnected
        }

        // Show yesterday's pet straight away; refresh() replaces it with fresh data.
        evaluate(store.cachedSnapshots, now: Date(), recordMemories: false)
    }

    // MARK: - Pets and progress (forwarded so views only talk to the model)

    var memories: [MemoryEvent] { store.memories }
    var daysTogether: Int { store.daysTogether }

    func progress(for activity: Activity) -> ActivityProgress {
        activityProgress[activity] ?? ActivityProgress(activity: activity, sessions: 0, experience: 0, unlockedOn: nil)
    }

    /// The pet on the home stage and in the middle of share cards.
    var mainPetID: String {
        didSet { defaults.set(mainPetID, forKey: Keys.mainPetID) }
    }

    /// Weeks always start on Monday (PRD v0.2), whatever the phone's region says.
    static var weekCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    var discipline: DisciplineTracker {
        DisciplineTracker(bedtime: sleepSchedule.bedtime, weekendBedtime: sleepSchedule.weekendBedtime,
                          calendar: Self.weekCalendar)
    }

    var creditRules: CreditRules { CreditRules(discipline: discipline) }

    var activityTracker: ActivityTracker {
        ActivityTracker(discipline: discipline, wakeTarget: sleepSchedule.wake, weekendWakeTarget: sleepSchedule.weekendWake)
    }

    /// Nights taken as a leave day (one a week counts as on time).
    var leaveDays: Set<Date> { store.leaveDays }

    /// Takes (or gives back) the night ending on the morning of `day` as this week's leave day.
    func setLeave(_ on: Bool, nightEnding day: Date) {
        store.setLeave(on, nightEnding: day)
        reevaluate()
    }

    /// Works everything out again from the days already fetched (a booking, a leave day).
    func reevaluate(now: Date = Date()) {
        evaluate(recentDays, now: now, recordMemories: false)
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
        recentDays = merged.isEmpty ? recentDays : merged
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

    /// The days last evaluated (up to 30), so a leave day can be applied without fetching again.
    @ObservationIgnored private(set) var recentDays: [HealthSnapshot] = []

    private func evaluate(_ snapshots: [HealthSnapshot], now: Date, recordMemories: Bool) {
        if recentDays.isEmpty { recentDays = snapshots }
        let todayStart = Calendar.current.startOfDay(for: now)
        guard let todaySnapshot = snapshots.first(where: { $0.day == todayStart }) else { return }
        let history = snapshots.filter { $0.day < todayStart }

        today = todaySnapshot
        var state = engine.evaluate(today: todaySnapshot, history: history)
        state.isAsleep = sleepSchedule.isBedtime(at: now)
        petState = state

        let tracker = discipline
        let leave = store.leaveDays

        // 点击 = 入账 (PRD v0.2 §4.4): what wasn't tapped by 04:00 the next day is collected for the
        // user; what still waits as a food bubble doesn't count yet. Everything that counts (the
        // week, the calendar, levels, the ledger) is worked out from the booked days.
        let credits = CreditRules(discipline: tracker)
        let book = creditBook
        let due = credits.due(in: snapshots, booked: book.bookedIDs, now: now, since: book.since)
        if !due.isEmpty {
            book.add(due.map { creditRecord($0, in: snapshots, auto: true, at: credits.autoBookTime(for: $0.day)) })
        }
        pending = credits.pending(in: snapshots, booked: book.bookedIDs, now: now)
        let booked = credits.booked(snapshots, pending: pending)
        bookedToday = booked.first { $0.day == todayStart }

        week = tracker.week(containing: now, snapshots: booked, leaveDays: leave)
        let weekStart = tracker.weekStart(for: now)
        weekDays = booked.filter { $0.day >= weekStart && $0.day <= todayStart }.sorted { $0.day < $1.day }
        let baseline = PersonalBaseline.from(history: history, before: todayStart, hrvMethod: todaySnapshot.hrvMethod)
        self.baseline = baseline
        onTimeStreak = tracker.onTimeStreak(booked)
        // the pet's slow condition is about how the days went, booked or not
        energy = EnergyMeter.energy(snapshots: snapshots, today: now, tracker: tracker, baseline: baseline, leaveDays: leave)
        let finishedWeeks = tracker.disciplinedWeeks(in: booked, before: now, leaveDays: leave)
        let activities = activityTracker
        let log = activities.log(booked, today: todayStart)
        // only ever adds, so a booking is saved the moment it happens
        if dataMode == .live {
            store.recordDisciplinedWeeks(finishedWeeks)
            store.recordActivities(log)
        }
        // Live: everything ever recorded. Demo: only the generated days, never saved.
        let (allLog, allWeeks) = dataMode == .live
            ? (store.activityLog.merging(log) { $0.union($1) }, store.disciplinedWeeks.union(finishedWeeks))
            : (log, Set(finishedWeeks))
        // Protein Bar's two-day streaks are paired over the whole history, never stored.
        let fullLog = activities.withBalancedStreaks(allLog)
        activityLog = fullLog
        disciplinedWeekStarts = allWeeks
        activityProgress = ActivityProgress.all(log: fullLog, disciplinedWeeks: allWeeks, weekStart: tracker.weekStart(for:))

        if recordMemories {
            store.addMemories(memoryDetector.newMemories(today: todaySnapshot, history: history,
                                                         adoptedOn: store.adoptedOn, existing: store.memories))
        }
    }
}

/// The user's sleep targets, in half-hour steps, with an optional weekend pair (PRD v0.2).
/// "Weekend" = Friday and Saturday nights, i.e. the nights ending on Saturday and Sunday
/// mornings, and those two mornings for waking up.
/// The pet falls asleep on its own at bedtime; no "sleep together" tap for wearable users.
/// TODO: learn bedtime from the user's real sleep onset, and also require the phone to be idle.
struct SleepSchedule: Codable, Equatable {
    /// Minutes after midnight: 23:00 = 1380, 00:30 = 30 (before noon = after midnight).
    var bedtimeMinutes = 23 * 60
    var wakeMinutes = 7 * 60
    /// nil = the same as on weekdays.
    var weekendBedtimeMinutes: Int?
    var weekendWakeMinutes: Int?

    var bedtime: Bedtime { Bedtime(hour: bedtimeMinutes / 60, minute: bedtimeMinutes % 60) }
    var weekendBedtime: Bedtime? { weekendBedtimeMinutes.map { Bedtime(hour: $0 / 60, minute: $0 % 60) } }
    var wake: WakeTime { WakeTime(hour: wakeMinutes / 60, minute: wakeMinutes % 60) }
    var weekendWake: WakeTime? { weekendWakeMinutes.map { WakeTime(hour: $0 / 60, minute: $0 % 60) } }

    /// Targets for the night ending on the morning of `morning`.
    func targets(nightEnding morning: Date, calendar: Calendar = .current) -> (bed: Int, wake: Int) {
        let weekend = calendar.isDateInWeekend(morning)
        return ((weekend ? weekendBedtimeMinutes : nil) ?? bedtimeMinutes,
                (weekend ? weekendWakeMinutes : nil) ?? wakeMinutes)
    }

    func isBedtime(at date: Date, calendar: Calendar = .current) -> Bool {
        let now = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        // Before noon the night ends this morning, otherwise the next one.
        let today = calendar.startOfDay(for: date)
        let morning = now < 12 * 60 ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let (bed, wake) = targets(nightEnding: morning, calendar: calendar)
        return bed > wake ? (now >= bed || now < wake) : (now >= bed && now < wake)
    }

    /// "23:00", "00:30"
    static func clock(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }
}
