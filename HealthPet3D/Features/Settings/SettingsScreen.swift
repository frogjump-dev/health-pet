import SwiftUI
import PetCore

/// Settings, from home's 「…」: data sources, bedtime, appearance, name on share cards, and
/// a few switches for trying the test build (demo data, replay the wake-up, regrow food).
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home

    var body: some View {
        @Bindable var model = model
        @Bindable var home = home
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "Settings")
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 8)
            Form {
                Section("Apple Health") {
                    if model.appleHealthConnected {
                        LabeledContent("Status", value: "Connected")
                    } else {
                        Button("Connect Apple Health") { Task { await model.connectAppleHealth() } }
                    }
                }
                .listRowBackground(Jade.card)

                Section("Whoop") {
                    switch model.whoopStatus {
                    case .unavailable:
                        LabeledContent("Status", value: "Not in this build")
                    case .notConnected:
                        Button("Connect Whoop") { Task { await model.connectWhoop() } }
                    case .connected:
                        LabeledContent("Status", value: "Connected")
                        Button("Disconnect Whoop", role: .destructive) { Task { await model.disconnectWhoop() } }
                    }
                }
                .listRowBackground(Jade.card)

                Section("Bedtime") {
                    Stepper("Asleep by \(model.sleepSchedule.bedtimeHour):00", value: $model.sleepSchedule.bedtimeHour, in: 18...23)
                    Stepper("Up by \(model.sleepSchedule.wakeHour):00", value: $model.sleepSchedule.wakeHour, in: 4...11)
                }
                .listRowBackground(Jade.card)

                Section("Look") {
                    Picker("Appearance", selection: $home.appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    TextField("Name on share cards", text: $home.userName)
                        .textInputAutocapitalization(.words)
                }
                .listRowBackground(Jade.card)

                Section("Test build") {
                    Picker("Data", selection: $model.dataMode) {
                        Text("Apple Health").tag(DataMode.live)
                        Text("Demo").tag(DataMode.demo)
                    }
                    Picker("Demo day", selection: $model.demoScenario) {
                        Text("Good").tag(PetMood.golden)
                        Text("Fully rested").tag(PetMood.fresh)
                        Text("Short night").tag(PetMood.burnt)
                        Text("Low recovery").tag(PetMood.soggy)
                    }
                    .disabled(model.dataMode != .demo)
                    Button("Play the wake-up again") { home.replayMorning() }
                    Button("Grow the food back") { home.regrowFood() }
                    Button("Refresh now") { Task { await model.refresh() } }
                }
                .listRowBackground(Jade.card)

                if let error = model.errorMessage {
                    Section {
                        Text(error).foregroundStyle(Jade.ink2)
                    }
                    .listRowBackground(Jade.card)
                }
            }
            .scrollContentBackground(.hidden)
            .font(.rounded(16, .medium))
        }
        .background(Jade.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: model.dataMode) { Task { await model.refresh() } }
        .onChange(of: model.demoScenario) { Task { await model.refresh() } }
    }
}
