import Foundation
import PetCore

/// The status area under the pet (home v3.2): no numbers. The sleep onset time with a check
/// when it was on time (never a cross), and one Rest bar, fuller = more rested, never red.
struct HomeStatus {
    /// "22:48", nil without sleep data.
    let onset: String?
    /// On time, and the moon was eaten: the lime check is lit.
    let onTime: Bool
    /// On time, but the moon still waits as a bubble: an empty ring where the check will light up.
    let checkWaiting: Bool
    /// 0...1, nil = nothing to go on (the bar stays empty rather than showing a made-up value).
    let rest: Double?
    /// The bar is Whoop's recovery (a small WHOOP mark), not our own Rest estimate.
    let fromWhoop: Bool
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

    /// HRV and every number live in Today; the home only shows the onset time and one bar.
    var homeStatus: HomeStatus {
        HomeStatus(onset: today?.sleepOnset.map(Format.time), onTime: sleptOnTime && nightBooked,
                   checkWaiting: sleptOnTime && !nightBooked, rest: rest.map { $0 / 100 }, fromWhoop: restIsWhoop)
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

    /// The pet's mood on the stage: low days get the gentle "tired" look, never a sad one.
    var stageMood: String {
        switch petState.mood {
        case .burnt, .soggy: "tired"
        case .golden, .fresh: "normal"
        }
    }

    /// The day's line after the morning wake-up (早上揭晓), and the expression that goes with it.
    /// Only good news: a level-up (collected overnight) hops; an on-time night is said, and the
    /// proud look comes when its moon is eaten (§4.4). Otherwise nothing is said.
    func morningReveal(levelUps: [Pet3D]) -> (expression: String?, line: String)? {
        if let pet = levelUps.first { return ("hop", "\(pet.name) is Lv \(record(pet).level) now!") }
        if sleptOnTime { return (nil, nightBooked ? "On time last night ✓" : "On time last night!") }
        return nil
    }

    /// One short line from the pet, shown for a moment after a tap or a check-in.
    func petLine(afterCheckIn: Bool = false) -> String {
        if petState.isAsleep { return "Zzz… see you in the morning." }
        if afterCheckIn || Bool.random() {
            if let workout = mainWorkout, workout.minutes >= discipline.rules.minWorkoutMinutes {
                return "\(workout.name) logged. Proud of you!"
            }
            if workedOut { return "10k steps! Nice walking." }
            if onTimeStreak >= 2 { return "On time \(onTimeStreak) nights in a row!" }
            if sleptOnTime { return "In bed on time. Proud of you!" }
        }
        switch petState.mood {
        case .fresh: return "Fully charged today!"
        case .golden: return ["Good to see you!", "Hi! I missed you.", "What shall we do today?"].randomElement()!
        case .burnt: return "Early night together?"
        case .soggy: return "Let's take it easy today."
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

    var weekRange: (start: Date, end: Date) {
        let tracker = discipline
        let start = tracker.weekStart(for: Date())
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

    /// "22:48", always on the 24-hour clock like the design.
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
