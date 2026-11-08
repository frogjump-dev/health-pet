import Foundation
import PetCore

/// What piles up (PRD v0.2 §4.2): 自律周 so far, the achievement ledger, leave days, the
/// share card's identity, and the moments the pet reacts to (level-ups, missing data).
extension AppModel {
    // MARK: - 自律周

    /// Every 自律周 so far, this week included once it counts. Toast's level and the big number
    /// on share cards.
    var disciplinedWeekTotal: Int {
        guard let week, week.isDisciplined, !disciplinedWeekStarts.contains(week.weekStart) else {
            return disciplinedWeekStarts.count
        }
        return disciplinedWeekStarts.count + 1
    }

    /// This week on its way to a 自律周, 0...1 (workouts and nights together).
    var weekFraction: Double {
        guard let week else { return 0 }
        let rules = week.rules
        let done = min(week.workouts, rules.workoutsPerWeek) + min(week.onTimeNights, rules.onTimeNightsPerWeek)
        return Double(done) / Double(rules.workoutsPerWeek + rules.onTimeNightsPerWeek)
    }

    // MARK: - Ledger (Memories)

    var ledger: [LedgerEntry] {
        Ledger.entries(log: activityLog, disciplinedWeeks: disciplinedWeekStarts,
                       currentWeekDone: week?.isDisciplined ?? false, adoptedOn: store.adoptedOn,
                       today: Date(), memories: memories, tracker: discipline)
    }

    // MARK: - Leave day

    /// The morning of last night (today's start): the night the Sleep card is about.
    private var lastNight: Date { Calendar.current.startOfDay(for: Date()) }

    /// Last night is this week's leave day.
    var lastNightIsLeave: Bool { leaveDays.contains(lastNight) }

    /// Last night was late (or has no sleep data) and this week's leave day is still free.
    var canTakeLeaveLastNight: Bool {
        guard !sleptOnTime, !lastNightIsLeave else { return false }
        let tracker = discipline
        let start = tracker.weekStart(for: Date())
        guard let end = tracker.calendar.date(byAdding: .day, value: 7, to: start) else { return false }
        let used = leaveDays.filter { $0 >= start && $0 < end }.count
        return used < tracker.rules.leaveDaysPerWeek
    }

    // MARK: - Share identity

    /// "Early-to-bed Runner": the share card's title (PRD v0.2 §6 / F).
    var identityTitle: String {
        ShareIdentity.title(progress: activityProgress, mainActivity: mainPet3D.activity,
                            onTimeNightsThisWeek: week?.onTimeNights ?? 0)
    }

    /// The main pet in the middle, the two highest-level other pets beside it (left, right).
    var showOffPets: (left: PetRecord?, main: PetRecord, right: PetRecord?) {
        let main = record(mainPet3D)
        let others = petRecords.filter { $0.isUnlocked && $0.pet.id != main.pet.id }
            .sorted { $0.level > $1.level }
        return (others.first, main, others.dropFirst().first)
    }

    // MARK: - Moments

    /// Each unlocked pet's level, for spotting level-ups between mornings.
    var petLevels: [String: Int] {
        Dictionary(uniqueKeysWithValues: petRecords.filter(\.isUnlocked).map { ($0.pet.id, $0.level) })
    }

    /// Apple Health gave nothing for today yet (watch not synced, access missing): the pet is puzzled.
    var dataMissing: Bool {
        guard dataMode == .live else { return false }
        if errorMessage != nil { return true }
        guard let today else { return true }
        return today.steps == nil && today.sleepOnset == nil && today.allWorkouts.isEmpty
    }

    /// Steps are within 2,000 of a 10k day and there is no workout yet: "almost there".
    var almostWorkout: Bool {
        guard !workedOut, let steps = today?.steps else { return false }
        return steps >= discipline.rules.activeDaySteps - 2_000
    }

    /// Yesterday had neither a workout nor an on-time night, and last night was late too:
    /// the streak broke, so the first open of the day cheers the user on (never sad).
    var cameBackAfterLapse: Bool {
        let tracker = discipline
        let calendar = tracker.calendar
        let todayStart = calendar.startOfDay(for: Date())
        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let yesterday = recentDays.first(where: { $0.day == yesterdayStart }) else { return false }
        let yesterdayDone = tracker.countsAsWorkout(yesterday) || tracker.isOnTimeNight(yesterday) == true
            || leaveDays.contains(yesterdayStart)
        return !yesterdayDone && !sleptOnTime && !lastNightIsLeave
    }

    /// Whoop's own recovery is behind the rest bar (labelled WHOOP).
    var restIsWhoop: Bool { today?.vendorRecovery != nil }

    /// 0–100: Whoop recovery or our Rest estimate. nil = nothing to go on, the bar stays empty.
    var rest: Double? { today.flatMap { DailyMetrics.recovery($0, baseline: baseline) } }
}

extension AppModel {
    /// Days together today, when today is one of the pet's anniversaries (7 / 30 / 100 / 365):
    /// 「喜欢你」 plays on the first open of that day.
    var anniversaryToday: Int? {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: store.adoptedOn),
                                           to: calendar.startOfDay(for: Date())).day ?? 0
        return [7, 30, 100, 365].contains(days) ? days : nil
    }
}
