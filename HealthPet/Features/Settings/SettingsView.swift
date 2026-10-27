import SwiftUI
import PetCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                Section {
                    Picker("Data source", selection: $model.sourceChoice) {
                        ForEach(DataSourceChoice.allCases) { Text($0.title).tag($0) }
                    }
                    Button("Connect") { Task { await model.connect() } }
                } header: {
                    Text("Health data")
                } footer: {
                    Text("Apple Health data is read on your phone. Whoop connects through our server.")
                }

                Section("Bedtime") {
                    Stepper("Sleeps at \(model.sleepSchedule.bedtimeHour):00", value: $model.sleepSchedule.bedtimeHour, in: 18...23)
                    Stepper("Wakes at \(model.sleepSchedule.wakeHour):00", value: $model.sleepSchedule.wakeHour, in: 4...11)
                }

                #if DEBUG
                Section("Debug") {
                    Picker("Demo mood", selection: $model.demoScenario) {
                        ForEach(PetMood.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .disabled(model.sourceChoice != .demo)
                    Button("Refresh now") { Task { await model.refresh() } }
                }
                #endif
            }
            .navigationTitle("Settings")
            .onChange(of: model.sourceChoice) { Task { await model.refresh() } }
            .onChange(of: model.demoScenario) { Task { await model.refresh() } }
        }
    }
}
