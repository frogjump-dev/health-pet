import SwiftUI
import PetCore

/// "More": everything that doesn't need to sit on the home screen, including the numbers.
struct MoreSheet: View {
    @Environment(AppModel.self) private var model
    let open: (HomeSheet) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        TodayDetailsView(state: model.petState, today: model.today)
                    } label: {
                        Label("Today's numbers", systemImage: "chart.bar")
                    }
                    Button { open(.world) } label: {
                        Label { Text("World") } icon: { Image("ic_world").resizable().scaledToFit() }
                    }
                    Button { open(.settings) } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

/// One tap deeper: the actual numbers behind today's mood.
struct TodayDetailsView: View {
    let state: PetState
    let today: HealthSnapshot?

    var body: some View {
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
    }

    private func row(_ title: String, _ value: String?) -> some View {
        LabeledContent(title, value: value ?? "—")
    }
}

struct ComingSoonView: View {
    let title: String
    let image: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(image).resizable().scaledToFit().frame(height: 120)
            Text(title).font(.system(.title2, design: .rounded).weight(.bold))
            Text(message)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Coming soon")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.honey.opacity(0.4)))
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}
