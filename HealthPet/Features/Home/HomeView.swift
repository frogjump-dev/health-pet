import SwiftUI
import PetCore

/// The home screen shows the pet and one friendly line. No scores here on purpose:
/// the numbers live one tap deeper, in `TodayDetailsView`.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showingDetails = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                model.skin.makeView(state: model.petState)
                    .frame(maxHeight: 360)
                    .padding(.horizontal, 32)
                    .onTapGesture { showingDetails = true }

                Text(model.skin.greeting(for: model.petState))
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let error = model.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { if model.isLoading { ProgressView() } }
            .navigationTitle(model.skin.displayName)
            .toolbar {
                Button("Today", systemImage: "chart.bar") { showingDetails = true }
            }
            .sheet(isPresented: $showingDetails) {
                TodayDetailsView(state: model.petState, today: model.today)
                    .presentationDetents([.medium])
            }
            .refreshable { await model.refresh() }
        }
    }
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
