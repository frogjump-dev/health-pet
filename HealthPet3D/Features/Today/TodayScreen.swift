import SwiftUI
import PetCore

/// Today: what got logged, this week's dots, rest. Share sits top right. All the numbers live here
/// (the home shows none). Last night can be taken as this week's leave day.
struct TodayScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PageScroll {
            PageHeader(title: "Today") {
                NavigationLink(value: Route.share) { RoundIcon(systemName: "square.and.arrow.up") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share")
            }
            .padding(.bottom, 4)
            sleepCard
            HStack(spacing: Metrics.gap) {
                workoutCard
                stepsCard
            }
            .fixedSize(horizontal: false, vertical: true)
            weekCard
            restCard
        }
    }

    private var day: HealthSnapshot? { model.today }

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(icon: "moon", title: "Sleep", done: model.sleptOnTime || model.lastNightIsLeave, doneColor: Jade.sleep)
            HStack(alignment: .firstTextBaseline) {
                BigNumber(day?.sleepOnset.map(Format.time) ?? "–")
                Spacer()
                if let hours = day?.sleepHours {
                    Text(Format.duration(hours: hours))
                        .font(.rounded(20, .bold))
                        .foregroundStyle(Jade.ink2)
                }
            }
            leaveButton
        }
        .card()
    }

    /// 「用请假」: one night a week counts as on time, no reason needed. Tap again to give it back.
    @ViewBuilder
    private var leaveButton: some View {
        if model.lastNightIsLeave {
            Button { model.setLeave(false, nightEnding: Date()) } label: {
                Label("Leave day", systemImage: "checkmark")
                    .font(.rounded(14, .bold))
                    .foregroundStyle(Jade.onSleep)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(Jade.sleep))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Gives the leave day back")
        } else if model.canTakeLeaveLastNight {
            Button { model.setLeave(true, nightEnding: Date()) } label: {
                Label("Use leave day", systemImage: "moon.zzz")
                    .font(.rounded(14, .bold))
                    .foregroundStyle(Jade.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(Jade.fill))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Counts last night as on time. One a week.")
        }
    }

    private var workoutCard: some View {
        let workout = model.mainWorkout
        return VStack(alignment: .leading, spacing: 12) {
            CardTitle(icon: workoutIcon(workout?.name), title: workout?.name ?? "Workout",
                      done: (workout?.minutes ?? 0) >= model.discipline.rules.minWorkoutMinutes, doneColor: Jade.accent)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                BigNumber(workout.map { "\(Int($0.minutes.rounded()))" } ?? "–", size: 34)
                if workout != nil {
                    Text("min").font(.rounded(15, .semibold)).foregroundStyle(Jade.ink3)
                }
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private var stepsCard: some View {
        let steps = day?.steps ?? 0
        let goal = model.discipline.rules.activeDaySteps
        return VStack(alignment: .leading, spacing: 12) {
            CardTitle(icon: "shoeprints.fill", title: "Steps", done: steps >= goal, doneColor: Jade.accent)
            BigNumber(day?.steps.map(Format.short) ?? "–", size: 34)
            Track(fraction: Double(steps) / Double(goal), color: Jade.ink)
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private var weekCard: some View {
        let rules = model.discipline.rules
        return VStack(alignment: .leading, spacing: 14) {
            Text("This week").font(.rounded(15, .semibold)).foregroundStyle(Jade.ink)
            DotRow(icon: "waveform.path.ecg", done: model.week?.workouts ?? 0, of: rules.workoutsPerWeek, color: Jade.accent)
                .accessibilityLabel("Workouts \(model.week?.workouts ?? 0) of \(rules.workoutsPerWeek)")
            DotRow(icon: "moon", done: model.week?.onTimeNights ?? 0, of: rules.onTimeNightsPerWeek, color: Jade.sleep)
                .accessibilityLabel("On-time nights \(model.week?.onTimeNights ?? 0) of \(rules.onTimeNightsPerWeek)")
        }
        .card()
    }

    /// Apple users: our own estimate, called Rest. Whoop users: Whoop's recovery, marked WHOOP.
    private var restCard: some View {
        let whoop = model.restIsWhoop
        return HStack {
            Label { Text(whoop ? "Recovery" : "Rest") } icon: { Image(systemName: "battery.75percent") }
                .font(.rounded(15, .semibold))
                .foregroundStyle(Jade.ink)
            if whoop {
                Text("WHOOP")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Jade.ink3)
            }
            Spacer()
            Text(model.rest.map { "\(Int($0.rounded()))%" } ?? "–")
                .font(.rounded(20, .bold))
                .foregroundStyle(Jade.ink)
                .monospacedDigit()
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

/// Icon + name, with a check in the corner when it is done.
struct CardTitle: View {
    let icon: String
    let title: String
    var done = false
    var doneColor: Color = Jade.accent

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(Jade.ink2)
            Text(title).font(.rounded(15, .semibold)).foregroundStyle(Jade.ink).lineLimit(1)
            Spacer(minLength: 4)
            if done { CheckBadge(color: doneColor) }
        }
        .frame(minHeight: 22)
    }
}

struct BigNumber: View {
    let text: String
    var size: CGFloat = 46

    init(_ text: String, size: CGFloat = 46) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(.rounded(size, .bold))
            .foregroundStyle(Jade.ink)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// An icon and a row of dots: filled = done, grey = not yet.
struct DotRow: View {
    let icon: String
    let done: Int
    let of: Int
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(Jade.ink2)
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<of, id: \.self) { i in
                    Circle().fill(i < done ? color : Jade.fill).frame(width: 13, height: 13)
                }
            }
        }
        .accessibilityElement(children: .ignore)
    }
}
