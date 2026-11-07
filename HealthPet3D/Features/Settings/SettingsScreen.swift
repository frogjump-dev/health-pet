import SwiftUI
import PetCore

/// Settings, from home's 「…」: data sources, bedtime, appearance, name on share cards, and
/// a few switches for trying the test build (demo data, replay the wake-up, regrow food).
/// Built from the v3 cards rather than a Form, so it scrolls like every other page.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home

    var body: some View {
        @Bindable var model = model
        @Bindable var home = home
        PageScroll {
            PageHeader(title: "Settings")

            SettingsGroup("Apple Health") {
                if model.appleHealthConnected {
                    SettingsRow("Status") { SettingsValue("Connected") }
                } else {
                    SettingsButton("Connect Apple Health") { Task { await model.connectAppleHealth() } }
                }
            }

            SettingsGroup("Whoop") {
                switch model.whoopStatus {
                case .unavailable:
                    SettingsRow("Status") { SettingsValue("Not in this build") }
                case .notConnected:
                    SettingsButton("Connect Whoop") { Task { await model.connectWhoop() } }
                case .connected:
                    SettingsRow("Status") { SettingsValue("Connected") }
                    RowDivider()
                    SettingsButton("Disconnect Whoop", quiet: true) { Task { await model.disconnectWhoop() } }
                }
            }

            SettingsGroup("Bedtime") {
                Stepper(value: $model.sleepSchedule.bedtimeHour, in: 18...23) {
                    SettingsLabel("Asleep by \(model.sleepSchedule.bedtimeHour):00")
                }
                .frame(minHeight: 54)
                RowDivider()
                Stepper(value: $model.sleepSchedule.wakeHour, in: 4...11) {
                    SettingsLabel("Up by \(model.sleepSchedule.wakeHour):00")
                }
                .frame(minHeight: 54)
            }

            SettingsGroup("Look") {
                SettingsRow("Appearance") {
                    Picker("Appearance", selection: $home.appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                RowDivider()
                TextField("Name on share cards", text: $home.userName)
                    .textInputAutocapitalization(.words)
                    .font(.rounded(16, .medium))
                    .foregroundStyle(Jade.ink)
                    .frame(minHeight: 54)
            }

            SettingsGroup("Test build") {
                SettingsRow("Data") {
                    Picker("Data", selection: $model.dataMode) {
                        Text("Apple Health").tag(DataMode.live)
                        Text("Demo").tag(DataMode.demo)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                RowDivider()
                SettingsRow("Demo day") {
                    Picker("Demo day", selection: $model.demoScenario) {
                        Text("Good").tag(PetMood.golden)
                        Text("Fully rested").tag(PetMood.fresh)
                        Text("Short night").tag(PetMood.burnt)
                        Text("Low recovery").tag(PetMood.soggy)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .disabled(model.dataMode != .demo)
                .opacity(model.dataMode == .demo ? 1 : 0.45)
                RowDivider()
                SettingsButton("Play the wake-up again") { home.replayMorning() }
                RowDivider()
                SettingsButton("Grow the food back") { home.regrowFood() }
                RowDivider()
                SettingsButton("Refresh now") { Task { await model.refresh() } }
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.rounded(14, .medium))
                    .foregroundStyle(Jade.ink2)
                    .card()
                    .padding(.top, 10)
            }
        }
        .onChange(of: model.dataMode) { Task { await model.refresh() } }
        .onChange(of: model.demoScenario) { Task { await model.refresh() } }
    }
}

/// A small grey title over one card of rows.
private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.rounded(13, .semibold))
                .foregroundStyle(Jade.ink3)
                .padding(.leading, 18)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 18)
                .background(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous).fill(Jade.card))
        }
        .padding(.top, 12)
    }
}

/// A row: a label on the left, a value or a control on the right.
private struct SettingsRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            SettingsLabel(title)
            Spacer(minLength: 8)
            trailing()
        }
        .frame(minHeight: 54)
    }
}

private struct SettingsLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.rounded(16, .medium)).foregroundStyle(Jade.ink)
    }
}

private struct SettingsValue: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.rounded(16, .medium)).foregroundStyle(Jade.ink2)
    }
}

/// A whole-row action in the accent colour (quiet = grey, for the rare undo-style action).
private struct SettingsButton: View {
    let title: String
    var quiet = false
    let action: () -> Void

    init(_ title: String, quiet: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.quiet = quiet
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.rounded(16, .medium))
                .foregroundStyle(quiet ? Jade.ink2 : Jade.accent)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Jade.fill).frame(height: 1)
    }
}
