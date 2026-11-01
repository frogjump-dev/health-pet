import SwiftUI
import PetCore

/// Today, one tap behind the big yellow dock button: what got logged on its own today
/// (last night's sleep, workout, steps) and how this 自律周 is going day by day.
struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let tracker = model.discipline
        ChibiPage(title: "Today", subtitle: Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) {
            SourceChip(connected: model.dataMode == .demo || model.appleHealthConnected,
                       demo: model.dataMode == .demo)
        } content: {
            ScrollView {
                VStack(spacing: 10) {
                    PetLine(pet: model.mainPet, line: line(tracker))
                    SleepCard(today: model.today, tracker: tracker)
                    HStack(spacing: 10) {
                        WorkoutCard(today: model.today, tracker: tracker)
                        StepsCard(steps: model.today?.steps ?? 0, goal: tracker.rules.activeDaySteps)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if model.recoveryBonus { RecoveryBonusLine() }
                    WeekCard(days: model.weekDays, week: model.week, weekInBlock: model.weekInBlock, tracker: tracker)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// The main pet cheers for what got logged. Never a score, never a scolding.
    private func line(_ tracker: DisciplineTracker) -> String {
        guard let today = model.today else { return "Nothing synced yet. I'll wait right here." }
        let night = tracker.isOnTimeNight(today) == true
        let workout = tracker.countsAsWorkout(today)
        switch (night, workout) {
        case (true, true): return "On time last night and \(workoutPhrase(today)). Two ticks already!"
        case (true, false): return "Slept on time last night. That's one tick!"
        case (false, true): return "\(workoutPhrase(today).capitalizedFirst) logged. Proud of you!"
        case (false, false): return "A quiet day so far. Every bit still counts."
        }
    }

    private func workoutPhrase(_ day: HealthSnapshot) -> String {
        if let minutes = day.workoutMinutes, minutes > 0 {
            return "a \(Int(minutes))-min \((day.workoutType ?? "workout").lowercased())"
        }
        return "10k steps"
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: - Header bits

private struct SourceChip: View {
    let connected: Bool
    let demo: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: connected ? "checkmark" : "exclamationmark")
                .font(.system(size: 7, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 14, height: 14)
                .background(Circle().fill(connected ? Palette.mintDeep : Palette.coral))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
            Text(demo ? "Demo data" : (connected ? "Apple Health" : "Not connected"))
                .font(ChibiFont.bold(11))
                .foregroundStyle(Palette.ink)
        }
        .padding(.leading, 5)
        .padding(.trailing, 9)
        .padding(.vertical, 3)
        .background(Capsule().fill(Palette.cream))
        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
    }
}

private struct PetLine: View {
    let pet: RosterPet
    let line: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(pet.art).resizable().scaledToFit().frame(height: 86)
            Text(line)
                .font(ChibiFont.bold(13))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.ink, lineWidth: 3))
                // Tail pointing at the pet.
                .overlay(alignment: .bottomLeading) {
                    BubbleTail()
                        .fill(.white)
                        .overlay(BubbleTail().stroke(Palette.ink, style: StrokeStyle(lineWidth: 3, lineJoin: .round)))
                        .frame(width: 12, height: 14)
                        .offset(x: -10, y: -10)
                }
                .padding(.bottom, 26)
        }
        .padding(.top, 6)
    }
}

/// Left-pointing speech-bubble tail; its open right side tucks under the bubble's border.
private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.maxX + 1, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY + 2))
            p.addLine(to: CGPoint(x: rect.maxX + 1, y: rect.maxY))
        }
    }
}

// MARK: - Cards

/// A "+1 night" / "+1 workout" pill: what today adds to the week.
private struct CountPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(ChibiFont.bold(11))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 8)
            .padding(.top, 2)
            .padding(.bottom, 1)
            .background(Capsule().fill(Palette.mint))
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
            .fixedSize()
    }
}

private struct SleepCard: View {
    let today: HealthSnapshot?
    let tracker: DisciplineTracker

    private var target: Date? { today.map { tracker.bedtime.target(forNightEnding: $0.day) } }

    var body: some View {
        let onTime = today.flatMap(tracker.isOnTimeNight)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image("ic_sleep").resizable().scaledToFit().frame(width: 40, height: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(today?.sleepOnset.map { "Asleep \(time($0))" } ?? "No sleep yet")
                        .font(ChibiFont.title(24)).foregroundStyle(Palette.ink)
                    Text(caption(onTime))
                        .font(ChibiFont.body(12)).foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
                if onTime == true { CountPill(text: "+1 night") }
            }
            if let onset = today?.sleepOnset, let target {
                SleepTimeline(target: target, onset: onset, hours: today?.sleepHours)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .chibiPanel(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// " · 7h 30m", or nothing without a sleep length.
    private var slept: String {
        guard let hours = today?.sleepHours else { return "" }
        return " · \(Int(hours))h \(Int((hours * 60).truncatingRemainder(dividingBy: 60)))m"
    }

    private func caption(_ onTime: Bool?) -> String {
        guard let target else { return "Wear your watch to bed and it logs itself" }
        let latest = target.addingTimeInterval(TimeInterval(tracker.rules.bedtimeGraceMinutes * 60))
        switch onTime {
        case true?: return "Counts if asleep by \(time(latest))" + slept
        case false?: return "A late one. Tonight is a fresh start" + slept
        case nil: return "Goal \(time(target)) · no sleep data for last night"
        }
    }
}

private func time(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
}

/// 22:00 → 08:00 strip: the night asleep in lavender, the bedtime goal as a tick.
private struct SleepTimeline: View {
    let target: Date
    let onset: Date
    let hours: Double?

    private var start: Date { target.addingTimeInterval(-3600) }   // 1 h before the goal
    private var span: TimeInterval { 10 * 3600 }
    private var wake: Date? { hours.map { onset.addingTimeInterval($0 * 3600) } }

    private func x(_ date: Date, _ width: CGFloat) -> CGFloat {
        CGFloat(min(max(date.timeIntervalSince(start) / span, 0), 1)) * width
    }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.lavender.opacity(0.3))
                    Rectangle()
                        .fill(Palette.lavender)
                        .frame(width: max(x(wake ?? onset, w) - x(onset, w), 4))
                        .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 2))
                        .offset(x: x(onset, w))
                }
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Palette.ink)
                        .frame(width: 3, height: 26)
                        .offset(x: x(target, w) - 1.5)
                }
            }
            .frame(height: 16)

            // Ends of the strip at the edges, the goal label right under its tick.
            GeometryReader { geo in
                let w = geo.size.width
                // No start label: the goal sits 1 h into the strip, so its label would collide with it.
                ZStack {
                    Text(time(start.addingTimeInterval(span)))
                        .frame(width: w, alignment: .trailing)
                    Text("goal \(time(target))")
                        .fixedSize()
                        .position(x: max(x(target, w), 30), y: 7)
                }
            }
            .frame(height: 14)
            .font(ChibiFont.body(10.5))
            .foregroundStyle(Palette.inkSoft)
        }
    }
}

private struct WorkoutCard: View {
    let today: HealthSnapshot?
    let tracker: DisciplineTracker

    var body: some View {
        let counts = today.map(tracker.countsAsWorkout) ?? false
        let minutes = Int(today?.workoutMinutes ?? 0)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image("ic_workout").resizable().scaledToFit().frame(height: 28)
                Spacer(minLength: 0)
                if counts { CountPill(text: "+1 workout") }
            }
            Text(minutes > 0 ? "\(today?.workoutType ?? "Workout") \(minutes) min" : (counts ? "10k day" : "No workout"))
                .font(ChibiFont.title(22))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 6)
            Text("Anything \(Int(tracker.rules.minWorkoutMinutes)) min+ counts")
                .font(ChibiFont.body(12)).foregroundStyle(Palette.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chibiPanel(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct StepsCard: View {
    let steps: Int
    let goal: Int

    var body: some View {
        let progress = min(Double(steps) / Double(goal), 1)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image("ic_steps").resizable().scaledToFit().frame(height: 22)
                Spacer(minLength: 0)
                Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(ChibiFont.bold(11)).foregroundStyle(Palette.inkSoft)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(steps.formatted()).font(ChibiFont.title(22)).foregroundStyle(Palette.ink)
                Text("/ \(goal / 1000)k").font(ChibiFont.title(14)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.empty)
                    Capsule().fill(Palette.mint).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
            .padding(.top, 5)
            Text("\(goal / 1000)k steps is a workout too")
                .font(ChibiFont.body(12)).foregroundStyle(Palette.inkSoft)
                .padding(.top, 3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chibiPanel(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct RecoveryBonusLine: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color(red: 0.61, green: 0.88, blue: 0.36))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5))
                .frame(width: 14, height: 14)
                .padding(.top, 2)
            (Text("Recovery bonus").font(ChibiFont.bold(12)).foregroundColor(Palette.ink)
             + Text(" · HRV a bit above your usual. Nice extra, never scored.").font(ChibiFont.body(12)).foregroundColor(Palette.inkSoft))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Week

/// Mon–Sun: a coral square for each workout day, a lavender one for each on-time night.
private struct WeekCard: View {
    let days: [HealthSnapshot]
    let week: WeekProgress?
    let weekInBlock: Int
    let tracker: DisciplineTracker

    var body: some View {
        let rules = tracker.rules
        let workouts = week?.workouts ?? 0
        let nights = week?.onTimeNights ?? 0
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image("ic_trophy").resizable().scaledToFit().frame(height: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Discipline Week \(weekInBlock) / \(rules.weeksPerBlock)")
                        .font(ChibiFont.title(19)).foregroundStyle(Palette.ink)
                    Text("Goal: \(rules.workoutsPerWeek) workouts + \(rules.onTimeNightsPerWeek) on-time nights")
                        .font(ChibiFont.body(12)).foregroundStyle(Palette.inkSoft)
                }
            }
            HStack(spacing: 4) {
                ForEach(weekDates, id: \.self) { date in
                    dayColumn(date)
                }
            }
            .padding(.top, 8)
            HStack(spacing: 12) {
                legend(color: Palette.coral, label: "Workouts", value: "\(min(workouts, rules.workoutsPerWeek))/\(rules.workoutsPerWeek)")
                legend(color: Palette.lavender, label: "Nights", value: "\(min(nights, rules.onTimeNightsPerWeek))/\(rules.onTimeNightsPerWeek)")
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            Text(nudge(workouts: workouts, nights: nights, rules: rules))
                .font(ChibiFont.bold(12))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(red: 1, green: 0.94, blue: 0.76)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2.5))
                .padding(.top, 8)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .chibiPanel(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var weekDates: [Date] {
        let start = tracker.weekStart(for: Date())
        return (0..<7).compactMap { tracker.calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayColumn(_ date: Date) -> some View {
        let snapshot = days.first { tracker.calendar.isDate($0.day, inSameDayAs: date) }
        let isToday = tracker.calendar.isDateInToday(date)
        return VStack(spacing: 3) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(ChibiFont.bold(11))
                .foregroundStyle(isToday ? Palette.ink : Palette.inkSoft)
            square(filled: snapshot.map(tracker.countsAsWorkout) ?? false, color: Palette.coral)
            square(filled: snapshot.flatMap(tracker.isOnTimeNight) ?? false, color: Palette.lavender)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background {
            if isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(red: 1, green: 0.90, blue: 0.63))
                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2.5)
            }
        }
    }

    private func square(filled: Bool, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(filled ? color : Palette.empty)
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2.5))
            .frame(width: 20, height: 20)
    }

    private func legend(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.ink, lineWidth: 2))
                .frame(width: 12, height: 12)
            Text(label).font(ChibiFont.body(11.5)).foregroundStyle(Palette.ink)
            Text(value).font(ChibiFont.title(14)).foregroundStyle(Palette.ink)
        }
    }

    /// What's left this week, said gently. Missing a week costs nothing.
    private func nudge(workouts: Int, nights: Int, rules: DisciplineRules) -> String {
        let needW = max(rules.workoutsPerWeek - workouts, 0)
        let needN = max(rules.onTimeNightsPerWeek - nights, 0)
        if needW == 0 && needN == 0 { return "Discipline Week done! A bake ticket is waiting." }
        var parts: [String] = []
        if needW > 0 { parts.append("\(needW) workout\(needW == 1 ? "" : "s")") }
        if needN > 0 { parts.append("\(needN) good night\(needN == 1 ? "" : "s")") }
        return parts.joined(separator: " + ") + " more this week bakes a ticket"
    }
}
