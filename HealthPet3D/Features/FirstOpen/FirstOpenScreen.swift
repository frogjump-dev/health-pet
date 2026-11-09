import SwiftUI
import PetCore

/// The first open (PRD v0.2 §6, v3.4, decided 2026-11-09). Each page = a title, two lines at
/// most, one main button:
/// ① Toast says hello → ② the four kinds of Apple Health data it reads (only telling; the real
/// switches are the system sheet and Settings) → ③ reading the last 30 days → ④ the pets those
/// days already earned, at their levels (skipped when there are none) → ⑤ the bedtime target →
/// ⑥ home, where the pet shows the user around.
struct FirstOpenScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home

    private enum Step: Int { case hello, health, reading, pets, bedtime }
    @State private var step: Step = {
        #if DEBUG
        // For screenshots on the simulator: -hp3dFirstOpenStep health|reading|pets|bedtime
        switch UserDefaults.standard.string(forKey: "hp3dFirstOpenStep") {
        case "health": return .health
        case "reading": return .reading
        case "pets", "lastDays": return .pets
        case "bedtime": return .bedtime
        default: break
        }
        #endif
        return .hello
    }()
    @State private var connecting = false
    @State private var progress = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch step {
            case .hello: hello
            case .health: health
            case .reading: reading
            case .pets: pets
            case .bedtime: bedtime
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Jade.canvas.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private func title(_ text: String, _ line: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.rounded(30, .bold))
                .foregroundStyle(Jade.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(line)
                .font(.rounded(15, .medium))
                .foregroundStyle(Jade.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 36)
    }

    // MARK: - ① Hello

    private var hello: some View {
        VStack(spacing: 0) {
            Spacer()
            PetPicture(pet: .toast, happy: true)
                .frame(width: 250, height: 250)
                .background(alignment: .bottom) {
                    Ellipse().fill(Jade.accent.opacity(0.16)).frame(width: 230, height: 40).offset(y: 6)
                }
            Text("Hi, I’m Toast.")
                .font(.rounded(26, .bold))
                .foregroundStyle(Jade.ink)
                .padding(.top, 40)
            Text("I grow from your walks, workouts and sleep.\nNothing to log, nothing to type.")
                .font(.rounded(15, .medium))
                .foregroundStyle(Jade.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 12)
            Spacer()
            Button("Continue") { step = .health }
                .buttonStyle(PillButtonStyle(primary: true))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - ② What it reads

    private var health: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("What I read from Apple Health", "Four things, read-only. That’s how your snacks grow.")
            VStack(spacing: 10) {
                readRow("shoeprints.fill", "Steps", "Your 10k-step days")
                readRow("figure.run", "Workouts", "Type and minutes, from your watch")
                readRow("moon", "Sleep", "When you fell asleep last night")
                readRow("waveform.path.ecg", "Heart rate", "Only for how rested you are")
            }
            .padding(.top, 24)
            Spacer()
            Text("Everything is calculated on your phone. Only a daily summary is stored, and you can switch any of these off in Settings.")
                .font(.rounded(12, .medium))
                .foregroundStyle(Jade.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
            Button {
                Task {
                    if model.dataMode == .live && !model.appleHealthConnected {
                        connecting = true
                        await model.connectAppleHealth()
                        connecting = false
                    }
                    step = .reading
                }
            } label: {
                if connecting { ProgressView().tint(Jade.onPrimary) } else { Text("Allow Apple Health") }
            }
            .buttonStyle(PillButtonStyle(primary: true))
            .disabled(connecting)
        }
    }

    private func readRow(_ icon: String, _ name: String, _ use: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Jade.ink2)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Jade.fill))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.rounded(15, .bold)).foregroundStyle(Jade.ink)
                Text(use).font(.rounded(13, .medium)).foregroundStyle(Jade.ink2)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14, radius: 20)
        .accessibilityElement(children: .combine)
    }

    // MARK: - ③ Reading the last 30 days

    private var reading: some View {
        VStack(spacing: 0) {
            Spacer()
            PetPicture(pet: .toast)
                .frame(width: 210, height: 210)
                .background(alignment: .bottom) {
                    Ellipse().fill(Jade.accent.opacity(0.16)).frame(width: 190, height: 34).offset(y: 6)
                }
            Text("Reading your last 30 days…")
                .font(.rounded(22, .bold))
                .foregroundStyle(Jade.ink)
                .padding(.top, 40)
            Track(fraction: progress, color: Jade.accent)
                .frame(width: 280)
                .padding(.top, 22)
            Text("Looking for pets you’ve already met.")
                .font(.rounded(13, .medium))
                .foregroundStyle(Jade.ink2)
                .padding(.top, 16)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .task {
            // the bar takes 2.5 s at least, and waits for the data (usually 2–5 s)
            withAnimation(.easeInOut(duration: 2.5)) { progress = 0.9 }
            try? await Task.sleep(for: .seconds(2.5))
            while model.isLoading { try? await Task.sleep(for: .milliseconds(200)) }
            withAnimation(.easeOut(duration: 0.3)) { progress = 1 }
            try? await Task.sleep(for: .seconds(0.4))
            step = earned.isEmpty ? .bedtime : .pets
        }
    }

    // MARK: - ④ The pets you've already met

    private var earned: [PetRecord] {
        model.petRecords.filter { $0.isUnlocked && $0.pet.activity != nil }
    }

    private static let words = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

    private var pets: some View {
        let count = earned.count
        let number = count < Self.words.count ? Self.words[count] : "\(count)"
        return VStack(alignment: .leading, spacing: 0) {
            title(count == 1 ? "You’ve already met one pet." : "You’ve already met \(number) pets.",
                  "From the last 30 days. They start at the level you’ve earned.")
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(earned, id: \.pet.id) { record in
                        MetCard(record: record, sessions: record.pet.activity.map { model.progress(for: $0).sessions } ?? 0)
                    }
                }
                .padding(.top, 24)
            }
            .scrollIndicators(.hidden)
            Text("Toast is your first companion. Everyone else lives in Pets.")
                .font(.rounded(12, .medium))
                .foregroundStyle(Jade.ink3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            Button("Nice") { step = .bedtime }
                .buttonStyle(PillButtonStyle(primary: true))
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - ⑤ Bedtime

    private var bedtime: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 0) {
            title("When do you want to be asleep?",
                  "Within 30 minutes after this counts as on time. Five on-time nights a week make the early-nights half of a disciplined week.")
            Picker("Asleep by", selection: $model.sleepSchedule.bedtimeMinutes) {
                ForEach(SleepOptions.bedtimes, id: \.self) { minutes in
                    Text(SleepSchedule.clock(minutes)).font(.rounded(22, .semibold)).tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            Toggle(isOn: weekendsApart) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Different on weekends").font(.rounded(15, .bold)).foregroundStyle(Jade.ink)
                    Text("Set a later time for Friday and Saturday").font(.rounded(12, .medium)).foregroundStyle(Jade.ink2)
                }
            }
            .tint(Jade.accent)
            .card(padding: 16, radius: 20)
            if let weekend = model.sleepSchedule.weekendBedtimeMinutes {
                Picker("Friday and Saturday", selection: Binding(get: { weekend }, set: { model.sleepSchedule.weekendBedtimeMinutes = $0 })) {
                    ForEach(SleepOptions.bedtimes, id: \.self) { minutes in
                        Text(SleepSchedule.clock(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                .tint(Jade.ink)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Spacer()
            Button("Done") {
                home.welcomeQuietly(model.unlockedPets)
                home.tourDone = false
                home.onboarded = true
            }
            .buttonStyle(PillButtonStyle(primary: true))
        }
    }

    /// Weekend targets start as a copy of the weekday ones; off = the same every night.
    private var weekendsApart: Binding<Bool> {
        Binding(get: { model.sleepSchedule.weekendBedtimeMinutes != nil }, set: { on in
            model.sleepSchedule.weekendBedtimeMinutes = on ? model.sleepSchedule.bedtimeMinutes : nil
            model.sleepSchedule.weekendWakeMinutes = on ? model.sleepSchedule.wakeMinutes : nil
        })
    }
}

/// A pet the last 30 days already earned: its picture on a small oval, name, level (jade for a
/// sport, lime for sleep), and what earned it ("Running · 3 runs").
private struct MetCard: View {
    let record: PetRecord
    let sessions: Int

    var body: some View {
        let activity = record.pet.activity
        let sleepy = activity == .onTimeSleep || activity == .earlyRise
        VStack(spacing: 6) {
            PetPicture(pet: record.pet)
                .frame(width: 96, height: 96)
                .background(alignment: .bottom) {
                    Ellipse().fill(Jade.ink.opacity(0.08)).frame(width: 84, height: 16).offset(y: 4)
                }
            Text(record.pet.name).font(.rounded(16, .bold)).foregroundStyle(Jade.ink).padding(.top, 6)
            Text("Lv \(record.level)")
                .font(.rounded(11, .heavy))
                .foregroundStyle(sleepy ? Jade.onSleep : Jade.onAccent)
                .padding(.horizontal, 9)
                .frame(height: 20)
                .background(Capsule().fill(sleepy ? Jade.sleep : Jade.accent))
            if let activity {
                Text(activity == .onTimeSleep ? "Early nights · \(sessions) of them" : "\(activity.title) · \(activity.sessions(sessions))")
                    .font(.rounded(12, .medium))
                    .foregroundStyle(Jade.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous).fill(Jade.card))
        .accessibilityElement(children: .combine)
    }
}

/// The half-hour steps the sleep targets can take.
enum SleepOptions {
    /// 20:00 … 23:30, then 00:00 … 02:00 (after midnight).
    static let bedtimes: [Int] = Array(stride(from: 20 * 60, through: 23 * 60 + 30, by: 30)) + Array(stride(from: 0, through: 2 * 60, by: 30))
    /// 04:00 … 11:00.
    static let wakes: [Int] = Array(stride(from: 4 * 60, through: 11 * 60, by: 30))
}
