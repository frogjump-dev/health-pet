import Foundation
import PetCore

/// The status area under the pet: the sleep onset time with a check when it was on time (never a
/// cross), then what the wearable recorded (PRD v0.3 「只读原值」): last night's sleep for Apple
/// Watch users ("Slept 7h 30m"), Whoop's recovery as a bar without a number for Whoop users.
struct HomeStatus {
    /// "22:48", nil without sleep data.
    let onset: String?
    /// On time, and the moon was eaten: the lime check is lit.
    let onTime: Bool
    /// On time, but the moon still waits as a bubble: an empty ring where the check will light up.
    let checkWaiting: Bool
    /// Whoop user: the second row is Whoop's recovery bar (with a small WHOOP mark).
    let whoop: Bool
    /// "7h 30m" asleep last night, as the watch recorded it; nil without sleep data.
    let slept: String?
    /// Whoop's recovery today, 0...1; nil = not scored yet (the bar stays empty).
    let recovery: Double?
}

/// One day in the week row on home.
struct WeekDay: Identifiable {
    let id: Date
    let letter: String
    let number: Int
    let isToday: Bool
    let isFuture: Bool
    /// A workout (or a 10k-step day) was booked: a small run icon.
    let workout: Bool
    /// An on-time night was booked: a small moon.
    let night: Bool
    /// The night was this week's leave night.
    let leave: Bool
    /// A short dash: the leave night, or a past day with nothing logged.
    var dash: Bool { leave || (!isFuture && !isToday && !workout && !night) }
}

extension AppModel {
    // MARK: - Home: status (v3.2)

    /// Every other number lives in Today; the home shows the onset time and one more row.
    var homeStatus: HomeStatus {
        HomeStatus(onset: today?.sleepOnset.map(Format.time), onTime: sleptOnTime && nightBooked,
                   checkWaiting: sleptOnTime && !nightBooked, whoop: isWhoopUser,
                   slept: today?.sleepHours.map { Format.duration(hours: $0) },
                   recovery: whoopRecovery.map { $0 / 100 })
    }

    // MARK: - Week

    var weekStrip: [WeekDay] {
        let tracker = discipline
        let calendar = tracker.calendar
        let todayStart = calendar.startOfDay(for: Date())
        let start = tracker.weekStart(for: todayStart)
        return (0..<7).compactMap { offset -> WeekDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let snapshot = weekDays.first { $0.day == day }
            let weekday = calendar.component(.weekday, from: day)
            return WeekDay(id: day,
                           letter: calendar.veryShortStandaloneWeekdaySymbols[weekday - 1],
                           number: calendar.component(.day, from: day),
                           isToday: day == todayStart,
                           isFuture: day > todayStart,
                           // booked days only: today's icons wait until its bubbles are eaten
                           workout: snapshot.map(tracker.countsAsWorkout) ?? false,
                           night: snapshot.flatMap(tracker.isOnTimeNight) ?? false,
                           leave: leaveDays.contains(day) && snapshot.flatMap(tracker.isOnTimeNight) != true)
        }
    }

    // MARK: - Today

    /// Last night was on time, as the data has it (booked or not).
    var sleptOnTime: Bool { today.flatMap(discipline.isOnTimeNight) ?? false }
    /// Today has a workout or a 10k-step day, as the data has it (booked or not).
    var workedOut: Bool { today.map(discipline.countsAsWorkout) ?? false }

    /// Today's booked check-ins: an on-time night and a workout (or a 10k-step day).
    var checkInsToday: Int {
        ((bookedToday.flatMap(discipline.isOnTimeNight) ?? false) ? 1 : 0) + ((bookedToday.map(discipline.countsAsWorkout) ?? false) ? 1 : 0)
    }

    /// The longest workout today, if any.
    var mainWorkout: WorkoutSession? { today?.allWorkouts.max { $0.minutes < $1.minutes } }

    /// The day's line after the morning wake-up (早上揭晓), and the expression that goes with it.
    /// Only good news: a level-up (collected overnight) hops; an on-time night is said, and the
    /// proud look comes when its moon is eaten (§4.4). Otherwise nothing is said.
    func morningReveal(levelUps: [Pet3D]) -> (expression: String?, line: String)? {
        if let pet = levelUps.first { return ("hop", "\(pet.name) is Lv \(record(pet).level) now!") }
        if sleptOnTime { return (nil, nightBooked ? "On time last night ✓" : "On time last night!") }
        return nil
    }

    /// One short line from the pet, shown for a moment after a tap or a check-in. Besides the
    /// day's news it only follows the pet's energy (PRD v0.3: no daily mood of its own).
    func petLine(afterCheckIn: Bool = false, energy: PetEnergy? = nil) -> String {
        if isPetAsleep { return "Zzz… see you in the morning." }
        if afterCheckIn || Bool.random() {
            if let workout = mainWorkout, workout.minutes >= discipline.rules.minWorkoutMinutes {
                return "\(workout.name) logged. Proud of you!"
            }
            if workedOut { return "10k steps! Nice walking." }
            if onTimeStreak >= 2 { return "On time \(onTimeStreak) nights in a row!" }
            if sleptOnTime { return "In bed on time. Proud of you!" }
        }
        switch energy ?? self.energy {
        case .lively: return ["Fully charged today!", "Good to see you!"].randomElement()!
        case .normal: return ["Good to see you!", "Hi! I missed you.", "What shall we do today?"].randomElement()!
        case .low: return ["Let's take it easy today.", "Early night together?"].randomElement()!
        }
    }

    // MARK: - Weeks with the pet

    /// 1 in the week the pet was adopted, 2 the week after, …
    var weekNumber: Int {
        let tracker = discipline
        let weeks = tracker.calendar.dateComponents([.weekOfYear], from: tracker.weekStart(for: store.adoptedOn),
                                                    to: tracker.weekStart(for: Date())).weekOfYear ?? 0
        return weeks + 1
    }

    /// Monday to Sunday of the week starting `weekStart` (nil = this week).
    func weekRange(starting weekStart: Date?) -> (start: Date, end: Date) {
        let tracker = discipline
        let start = weekStart ?? tracker.weekStart(for: Date())
        return (start, tracker.calendar.date(byAdding: .day, value: 6, to: start) ?? start)
    }
}

enum Format {
    /// 820 → "820", 8,214 → "8.2k", 12,400 → "12.4k", 64,213 → "64k".
    static func short(_ n: Int) -> String {
        if n < 1_000 { return "\(n)" }
        let k = Double(n) / 1_000
        if k >= 20 { return "\(Int(k.rounded()))k" }
        let text = String(format: "%.1f", k)
        return (text.hasSuffix(".0") ? String(text.dropLast(2)) : text) + "k"
    }

    /// "22:48", always on the 24-hour clock like the design (a 12-hour choice comes with PRD v0.3 batch 2).
    static func time(_ date: Date) -> String { clock.string(from: date) }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    /// 7.7 → "7h 42m"
    static func duration(hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    /// "Oct 27 – Nov 2"
    static func range(_ start: Date, _ end: Date) -> String {
        "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    }
}
