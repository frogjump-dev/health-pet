import Foundation
import PetCore

/// A food bubble on home: one piece of today's data the pet can eat.
struct FoodBubble: Identifiable, Equatable {
    enum Kind { case steps, energy, workout, load }

    let id: String
    let kind: Kind
    let icon: String
    /// Compared with the value it had when eaten: a bubble grows back once the data has moved on.
    let value: Double
    let label: String
    /// Fixed place around the pet (see `HomeLayout.slots`).
    let slot: Int
    let spoken: String

    /// How much the data must grow before an eaten bubble comes back today.
    var regrowStep: Double? {
        switch kind {
        case .steps: 1_000
        case .energy: 100
        case .load: 1
        case .workout: nil   // a finished workout doesn't change; a new one is a new bubble
        }
    }
}

/// One status bar under the rug: fuller = more rested. Never red.
struct StatusRow: Identifiable {
    let id: String
    let name: String
    let icon: String
    let label: String
    let fill: Double
}

/// One day in the week row on home.
struct WeekDay: Identifiable {
    let id: Date
    let letter: String
    let number: Int
    let isToday: Bool
    let isFuture: Bool
    let workout: Bool
    let night: Bool
    /// A past day with nothing logged: a short dash.
    var rest: Bool { !isFuture && !isToday && !workout && !night }
}

extension AppModel {
    // MARK: - Home: food bubbles

    /// Today's food: steps, active energy, each workout (up to two), the day's load.
    /// `eaten` gives the value a bubble had when it was eaten today.
    func foodBubbles(eaten: (String) -> Double?) -> [FoodBubble] {
        guard let today else { return [] }
        var all: [FoodBubble] = []
        if let steps = today.steps, steps > 0 {
            all.append(FoodBubble(id: "steps", kind: .steps, icon: "shoeprints.fill", value: Double(steps),
                                  label: Format.short(steps), slot: 0, spoken: "\(steps) steps"))
        }
        if let kcal = today.activeEnergyKcal, kcal >= 1 {
            all.append(FoodBubble(id: "energy", kind: .energy, icon: "flame", value: kcal,
                                  label: "\(Int(kcal.rounded()))", slot: 1, spoken: "\(Int(kcal.rounded())) active calories"))
        }
        let workouts = today.allWorkouts.sorted { $0.minutes > $1.minutes }.prefix(2)
        for (i, workout) in workouts.enumerated() {
            let minutes = Int(workout.minutes.rounded())
            all.append(FoodBubble(id: "workout-\(workout.name)-\(minutes)", kind: .workout, icon: workoutIcon(workout.name),
                                  value: workout.minutes, label: "\(minutes)m", slot: i == 0 ? 2 : 4,
                                  spoken: "\(workout.name), \(minutes) minutes"))
        }
        if let load = DailyMetrics.dailyLoad(today), load >= 0.1 {
            all.append(FoodBubble(id: "load", kind: .load, icon: "gauge.with.dots.needle.50percent", value: load,
                                  label: String(format: "%.1f", load), slot: 3,
                                  spoken: today.strain != nil ? "Day strain \(String(format: "%.1f", load))" : "Daily load \(String(format: "%.1f", load))"))
        }
        return all.filter { bubble in
            guard let was = eaten(bubble.id) else { return true }
            guard let step = bubble.regrowStep else { return false }
            return bubble.value - was >= step
        }
    }

    // MARK: - Home: status bars

    var statusRows: [StatusRow] {
        let day = today
        let recovery = day.flatMap { DailyMetrics.recovery($0, baseline: baseline) }
        let hrvFill = day.flatMap { DailyMetrics.hrvFill($0, baseline: baseline) }
        let onsetFill = day.flatMap { DailyMetrics.onsetFill($0, tracker: discipline) }
        return [
            StatusRow(id: "recovery", name: "Recovery", icon: "heart",
                      label: recovery.map { "\(Int($0.rounded()))%" } ?? "–", fill: (recovery ?? 0) / 100),
            StatusRow(id: "hrv", name: "HRV", icon: "waveform.path.ecg",
                      label: day?.hrvMs.map { "\(Int($0.rounded()))ms" } ?? "–", fill: hrvFill ?? 0),
            StatusRow(id: "onset", name: "Asleep at", icon: "moon",
                      label: day?.sleepOnset.map(Format.time) ?? "–", fill: onsetFill ?? 0),
        ]
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
                           workout: snapshot.map(tracker.countsAsWorkout) ?? false,
                           night: snapshot.flatMap(tracker.isOnTimeNight) ?? false)
        }
    }

    // MARK: - Today

    var sleptOnTime: Bool { today.flatMap(discipline.isOnTimeNight) ?? false }
    var workedOut: Bool { today.map(discipline.countsAsWorkout) ?? false }

    /// Today's check-ins: an on-time night and a workout (or a 10k-step day).
    var checkInsToday: Int { (sleptOnTime ? 1 : 0) + (workedOut ? 1 : 0) }

    /// The longest workout today, if any.
    var mainWorkout: WorkoutSession? { today?.allWorkouts.max { $0.minutes < $1.minutes } }

    /// The pet's mood on the stage: low days get the gentle "tired" look, never a sad one.
    var stageMood: String {
        switch petState.mood {
        case .burnt, .soggy: "tired"
        case .golden, .fresh: "normal"
        }
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
