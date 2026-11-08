import SwiftUI
import PetCore

/// The first open (PRD v0.2 §6): the app reads the last 30 days anyway, so the pets those days
/// already earned are shown as a moment of their own ("Chili Lv 3, Mantou Lv 6"), then the user
/// picks a bedtime, then home. Three steps, one button each.
struct FirstOpenScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home

    private enum Step { case hello, lastDays, bedtime }
    @State private var step: Step = {
        #if DEBUG
        // For screenshots on the simulator: -hp3dFirstOpenStep lastDays|bedtime
        switch UserDefaults.standard.string(forKey: "hp3dFirstOpenStep") {
        case "lastDays": return .lastDays
        case "bedtime": return .bedtime
        default: break
        }
        #endif
        return .hello
    }()
    @State private var connecting = false

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .hello: hello
            case .lastDays: lastDays
            case .bedtime: bedtime
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Jade.canvas.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - 1. Hello

    private var needsHealth: Bool { model.dataMode == .live && !model.appleHealthConnected }

    private var hello: some View {
        VStack(spacing: 0) {
            Spacer()
            PetPicture(pet: .toast, happy: true).frame(width: 190, height: 190)
            Text("HealthPet")
                .font(.rounded(34, .heavy))
                .foregroundStyle(Jade.ink)
                .padding(.top, 18)
            Spacer()
            Button {
                Task {
                    if needsHealth {
                        connecting = true
                        await model.connectAppleHealth()
                        connecting = false
                    }
                    step = .lastDays
                }
            } label: {
                if connecting { ProgressView().tint(Jade.onPrimary) }
                else { Label(needsHealth ? "Connect Apple Health" : "Start", systemImage: needsHealth ? "heart" : "arrow.right") }
            }
            .buttonStyle(PillButtonStyle(primary: true))
            .disabled(connecting)
            if needsHealth {
                Button("Not now") { step = .bedtime }
                    .font(.rounded(15, .bold))
                    .foregroundStyle(Jade.ink2)
                    .frame(height: 44)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - 2. The last 30 days

    private var earned: [PetRecord] {
        model.petRecords.filter { $0.isUnlocked && $0.pet.activity != nil }
    }

    private var lastDays: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your last 30 days")
                .font(.rounded(32, .bold))
                .foregroundStyle(Jade.ink)
                .padding(.top, 24)
            if model.isLoading && earned.isEmpty {
                Spacer()
                ProgressView().frame(maxWidth: .infinity)
                Spacer()
            } else if earned.isEmpty {
                Spacer()
                PetPicture(pet: .toast, happy: true).frame(width: 150, height: 150).frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(earned, id: \.pet.id) { record in
                            PetTile(record: record)
                        }
                    }
                    .padding(.top, 20)
                }
                .scrollIndicators(.hidden)
            }
            Button("Next") { step = .bedtime }
                .buttonStyle(PillButtonStyle(primary: true))
                .padding(.top, 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(earned.isEmpty ? "Your last 30 days" :
            "Your last 30 days: " + earned.map { "\($0.pet.name) level \($0.level)" }.joined(separator: ", "))
    }

    // MARK: - 3. Bedtime

    private var bedtime: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "moon").font(.system(size: 22, weight: .semibold)).foregroundStyle(Jade.sleep)
                Text("Asleep by").font(.rounded(32, .bold)).foregroundStyle(Jade.ink)
            }
            .padding(.top, 24)
            Spacer()
            Picker("Asleep by", selection: $model.sleepSchedule.bedtimeMinutes) {
                ForEach(SleepOptions.bedtimes, id: \.self) { minutes in
                    Text(SleepSchedule.clock(minutes)).font(.rounded(22, .semibold)).tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            Spacer()
            Button("Start") {
                home.welcomeQuietly(model.unlockedPets)
                home.onboarded = true
            }
            .buttonStyle(PillButtonStyle(primary: true))
        }
    }
}

/// The half-hour steps the sleep targets can take.
enum SleepOptions {
    /// 20:00 … 23:30, then 00:00 … 02:00 (after midnight).
    static let bedtimes: [Int] = Array(stride(from: 20 * 60, through: 23 * 60 + 30, by: 30)) + Array(stride(from: 0, through: 2 * 60, by: 30))
    /// 04:00 … 11:00.
    static let wakes: [Int] = Array(stride(from: 4 * 60, through: 11 * 60, by: 30))
}
