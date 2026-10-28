import SwiftUI
import PetCore

/// The home screen is the pet's little kitchen: the toast on its plate, a daily pat,
/// and three big buttons. No scores here on purpose: the numbers live one tap deeper,
/// in `TodayDetailsView`.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: HomeSheet?

    var body: some View {
        ZStack {
            KitchenBackground()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ZStack(alignment: .bottomLeading) {
                    petStage
                    if model.canPatToday {
                        PatBubble { withAnimation(.spring) { model.pat() } }
                            .padding(.leading, 20)
                            .padding(.bottom, 170)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxHeight: .infinity)

                nameAndLevel
                    .padding(.bottom, 28)

                actionButtons
                    .padding(.horizontal, 16)

                MoreDrawerHandle { sheet = .settings }
                    .padding(.top, 14)
            }
            .overlay { if model.isLoading { ProgressView() } }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .today:
                TodayDetailsView(state: model.petState, today: model.today)
                    .presentationDetents([.medium])
            case .wardrobe:
                WardrobeView()
                    .presentationDetents([.medium])
            case .memories:
                MemoriesView()
            case .settings:
                SettingsView()
            }
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            HStack(spacing: 10) {
                Image(ToastSkin.imageName(for: .golden))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .background(.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Day \(model.daysTogether)")
                        .font(.headline)
                        .foregroundStyle(Color.toastInk)
                    Text("together")
                        .font(.caption)
                        .foregroundStyle(Color.toastInk.opacity(0.6))
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 18)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            CircleIconButton(systemImage: "chart.bar.fill", label: "Today's numbers") { sheet = .today }
            CircleIconButton(systemImage: "ellipsis", label: "Settings") { sheet = .settings }
        }
    }

    private var petStage: some View {
        VStack(spacing: 12) {
            Text(model.skin.greeting(for: model.petState))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.toastInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 48)

            ZStack(alignment: .bottom) {
                Plate()
                    .frame(width: 260, height: 54)
                model.skin.makeView(state: model.petState)
                    .frame(maxHeight: 280)
                    .padding(.bottom, 22)
                    .onTapGesture { sheet = .today }
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var nameAndLevel: some View {
        let level = model.level
        return VStack(spacing: 8) {
            Text(model.skin.displayName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.toastInk)
            LevelBar(level: level.number, current: level.current, needed: level.needed)
                .frame(width: 220)
        }
    }

    private var actionButtons: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ActionCard(title: "Dress up", subtitle: nil, height: 104) {
                Image(systemName: "tshirt.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient(colors: [.crustLight, .crust], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .crust.opacity(0.4), radius: 6, y: 4)
            } action: { sheet = .wardrobe }

            ActionCard(title: "Today", subtitle: model.skin.moodLabel(for: model.petState), height: 128) {
                ButterPat()
                    .frame(width: 76, height: 60)
            } action: { sheet = .today }

            ActionCard(title: "Memories", subtitle: nil, height: 104) {
                Toaster()
                    .frame(width: 60, height: 52)
            } action: { sheet = .memories }
        }
    }
}

private enum HomeSheet: String, Identifiable {
    case today, wardrobe, memories, settings
    var id: String { rawValue }
}

/// One tap deeper: the actual numbers behind today's mood.
struct TodayDetailsView: View {
    let state: PetState
    let today: HealthSnapshot?

    var body: some View {
        NavigationStack {
            List {
                Section("How your pet feels") {
                    LabeledContent("Energy", value: state.energy.formatted(.percent.precision(.fractionLength(0))))
                    LabeledContent("Sleep debt", value: state.sleepDebt.formatted(.percent.precision(.fractionLength(0))))
                    LabeledContent("Activity vs. your normal", value: state.activity.formatted(.percent.precision(.fractionLength(0))))
                }
                Section("Today's data") {
                    row("Sleep", today?.sleepHours.map { String(format: "%.1f h", $0) })
                    row("HRV", today?.hrvMs.map { String(format: "%.0f ms", $0) })
                    row("Resting heart rate", today?.restingHeartRate.map { String(format: "%.0f bpm", $0) })
                    row("Steps", today?.steps.map { $0.formatted() })
                    row("Recovery (Whoop)", today?.vendorRecovery.map { String(format: "%.0f%%", $0) })
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ title: String, _ value: String?) -> some View {
        LabeledContent(title, value: value ?? "—")
    }
}

#Preview {
    HomeView().environment(AppModel())
}
