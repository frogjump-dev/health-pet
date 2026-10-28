import SwiftUI
import PetCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                Section {
                    Button("Connect Apple Health") { Task { await model.connectAppleHealth() } }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Steps, sleep and heart data are read on your phone and never leave it.")
                }

                whoopSection

                Section("Bedtime") {
                    Stepper("Sleeps at \(model.sleepSchedule.bedtimeHour):00", value: $model.sleepSchedule.bedtimeHour, in: 18...23)
                    Stepper("Wakes at \(model.sleepSchedule.wakeHour):00", value: $model.sleepSchedule.wakeHour, in: 4...11)
                }

                if let error = model.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.secondary)
                    }
                }

                #if DEBUG
                Section("Debug") {
                    Picker("Data", selection: $model.dataMode) {
                        Text("Live").tag(DataMode.live)
                        Text("Demo").tag(DataMode.demo)
                    }
                    Picker("Demo mood", selection: $model.demoScenario) {
                        ForEach(PetMood.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .disabled(model.dataMode != .demo)
                    Button("Refresh now") { Task { await model.refresh() } }
                }
                #endif
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
            .onChange(of: model.dataMode) { Task { await model.refresh() } }
            .onChange(of: model.demoScenario) { Task { await model.refresh() } }
        }
    }

    @ViewBuilder
    private var whoopSection: some View {
        Section {
            switch model.whoopStatus {
            case .unavailable:
                Text("Not available in this build").foregroundStyle(.secondary)
            case .notConnected:
                Button("Connect Whoop") { Task { await model.connectWhoop() } }
            case .connected:
                LabeledContent("Status", value: "Connected")
                Button("Disconnect Whoop", role: .destructive) { Task { await model.disconnectWhoop() } }
            }
        } header: {
            Text("Whoop")
        } footer: {
            Text("Whoop recovery, sleep and HRV come through the HealthPet server. Steps still come from your phone.")
        }
    }
}
