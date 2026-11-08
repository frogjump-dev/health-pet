import Foundation

/// One line of the achievement ledger (Memories, PRD v0.2 §6): everything the user has piled up,
/// so even a week that did not count still adds something.
public struct LedgerEntry: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable, Hashable {
        /// The n-th 自律周.
        case disciplinedWeek(Int)
        /// The n-th monthly achievement (3 of a block of 4 weeks).
        case monthlyAchievement(Int)
        /// A pet joined: the first day its activity was done.
        case unlocked(Activity)
        /// A pet reached a milestone level (10, 20).
        case level(Activity, Int)
        /// 30 / 100 on-time nights in total.
        case onTimeNights(Int)
        /// 100 workouts in total.
        case workouts(Int)
        case firstTwentyKSteps
        /// 30 / 100 / 365 days since adoption.
        case daysTogether(Int)
    }

    public var kind: Kind
    public var day: Date

    public init(kind: Kind, day: Date) {
        self.kind = kind
        self.day = day
    }

    public var id: String { "\(kind)@\(Int(day.timeIntervalSince1970))" }
}

/// Builds the ledger from what is kept forever: the activity log, the 自律周 week starts,
/// the adoption day and the saved memories. Nothing is stored twice.
public enum Ledger {
    public static let levelMilestones = [10, 20]
    public static let nightMilestones = [30, 100]
    public static let workoutMilestones = [100]
    public static let anniversaries = [30, 100, 365]

    /// Newest first.
    /// - Parameters:
    ///   - log: every day's activities (with two-day streaks already added).
    ///   - disciplinedWeeks: starts of the finished weeks that counted (they also double experience).
    ///   - currentWeekDone: this week already counts; its line is dated `today`.
    public static func entries(log: [Date: Set<Activity>], disciplinedWeeks: Set<Date>, currentWeekDone: Bool,
                               adoptedOn: Date, today: Date, memories: [MemoryEvent],
                               tracker: DisciplineTracker) -> [LedgerEntry] {
        let calendar = tracker.calendar
        let rules = tracker.rules
        let todayStart = calendar.startOfDay(for: today)
        var result: [LedgerEntry] = []

        // 自律周 and monthly achievements, in blocks of 4 weeks counted from the adoption week
        var weeks = disciplinedWeeks.map { (start: $0, day: calendar.date(byAdding: .day, value: 6, to: $0) ?? $0) }
        let thisWeek = tracker.weekStart(for: today)
        if currentWeekDone, !disciplinedWeeks.contains(thisWeek) { weeks.append((thisWeek, todayStart)) }
        weeks.sort { $0.start < $1.start }
        let firstWeek = tracker.weekStart(for: adoptedOn)
        var perBlock: [Int: Int] = [:]
        var months = 0
        for (n, week) in weeks.enumerated() {
            result.append(LedgerEntry(kind: .disciplinedWeek(n + 1), day: week.day))
            let offset = calendar.dateComponents([.weekOfYear], from: firstWeek, to: week.start).weekOfYear ?? 0
            let block = Int((Double(offset) / Double(rules.weeksPerBlock)).rounded(.down))
            perBlock[block, default: 0] += 1
            if perBlock[block] == rules.weeksNeededPerBlock {
                months += 1
                result.append(LedgerEntry(kind: .monthlyAchievement(months), day: week.day))
            }
        }

        // pets joining and reaching milestone levels, replayed day by day with the 自律周 bonus
        var experience: [Activity: Int] = [:]
        var nights = 0, workouts = 0
        for day in log.keys.sorted() {
            let done = log[day] ?? []
            let bonus = disciplinedWeeks.contains(tracker.weekStart(for: day)) ? 2 : 1
            for activity in Activity.allCases where done.contains(activity) {
                let before = experience[activity, default: 0]
                let after = before + bonus
                experience[activity] = after
                if before == 0 { result.append(LedgerEntry(kind: .unlocked(activity), day: day)) }
                for level in levelMilestones {
                    let needed = PetLevel.experience(for: level)
                    if before < needed && after >= needed {
                        result.append(LedgerEntry(kind: .level(activity, level), day: day))
                    }
                }
            }
            if done.contains(.onTimeSleep) {
                nights += 1
                if nightMilestones.contains(nights) { result.append(LedgerEntry(kind: .onTimeNights(nights), day: day)) }
            }
            if done.contains(where: \.isWorkout) {
                workouts += 1
                if workoutMilestones.contains(workouts) { result.append(LedgerEntry(kind: .workouts(workouts), day: day)) }
            }
        }

        if let first = memories.filter({ $0.kind == .firstTwentyKSteps }).min(by: { $0.day < $1.day }) {
            result.append(LedgerEntry(kind: .firstTwentyKSteps, day: calendar.startOfDay(for: first.day)))
        }

        let adopted = calendar.startOfDay(for: adoptedOn)
        for days in anniversaries {
            if let day = calendar.date(byAdding: .day, value: days, to: adopted), day <= todayStart {
                result.append(LedgerEntry(kind: .daysTogether(days), day: day))
            }
        }

        // newest first; on the same day the bigger moments come first
        return result.enumerated().sorted { a, b in
            if a.element.day != b.element.day { return a.element.day > b.element.day }
            if rank(a.element.kind) != rank(b.element.kind) { return rank(a.element.kind) < rank(b.element.kind) }
            return a.offset < b.offset
        }.map(\.element)
    }

    private static func rank(_ kind: LedgerEntry.Kind) -> Int {
        switch kind {
        case .monthlyAchievement: 0
        case .disciplinedWeek: 1
        case .daysTogether: 2
        case .level: 3
        case .unlocked: 4
        case .onTimeNights, .workouts: 5
        case .firstTwentyKSteps: 6
        }
    }
}
