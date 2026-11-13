import SwiftUI
import PetCore

/// Settings, from home's 「…」: data sources, sleep targets (half-hour steps, weekends apart), the
/// two notifications, appearance, the clock style, name on share cards, About (version, privacy
/// policy, feedback), and a few switches for trying the test build (demo data, the pet's energy,
/// replay the wake-up or the first open, regrow food).
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
                    // Nothing for a few days: access may be off, and only the Health app can
                    // turn it back on (PRD v0.3 §6).
                    if model.appleHealthQuiet {
                        RowDivider()
                        SettingsNote("Nothing from Apple Health for \(model.daysWithoutData) days. To check access, open the Health app, tap your picture, then Apps › \(Bundle.main.displayName).")
                    }
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

            SettingsGroup("Sleep") {
                TimeRow("Asleep by", minutes: $model.sleepSchedule.bedtimeMinutes, options: SleepOptions.bedtimes)
                RowDivider()
                TimeRow("Up by", minutes: $model.sleepSchedule.wakeMinutes, options: SleepOptions.wakes)
                RowDivider()
                Toggle(isOn: weekendsApart) { SettingsLabel("Weekends apart") }
                    .frame(minHeight: 54)
                if model.sleepSchedule.weekendBedtimeMinutes != nil {
                    RowDivider()
                    TimeRow("Fri & Sat asleep by", minutes: weekendBinding(\.weekendBedtimeMinutes, \.bedtimeMinutes),
                            options: SleepOptions.bedtimes)
                    RowDivider()
                    TimeRow("Sat & Sun up by", minutes: weekendBinding(\.weekendWakeMinutes, \.wakeMinutes),
                            options: SleepOptions.wakes)
                }
            }

            SettingsGroup("Notifications") {
                Toggle(isOn: notification(\.notifyBedtime)) { SettingsLabel("Bedtime") }
                    .frame(minHeight: 54)
                RowDivider()
                Toggle(isOn: notification(\.notifyMorning)) { SettingsLabel("Morning") }
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
                SettingsRow("Time format") { TimeFormatMenu() }
                RowDivider()
                TextField("Name on share cards", text: $home.userName)
                    .textInputAutocapitalization(.words)
                    .scaledFont(16, .medium)
                    .foregroundStyle(Jade.ink)
                    .frame(minHeight: 54)
            }

            SettingsGroup("About") {
                SettingsRow("Version") { SettingsValue(Bundle.main.versionText) }
                RowDivider()
                LinkRow("Privacy policy", url: Bundle.main.url(forInfoKey: "PrivacyPolicyURL"))
                RowDivider()
                LinkRow("Send feedback", url: Bundle.main.url(forInfoKey: "FeedbackURL"))
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
                SettingsRow("Pet energy") {
                    Picker("Pet energy", selection: $home.energyOverride) {
                        Text("From data").tag(PetEnergy?.none)
                        Text("Lively").tag(PetEnergy?.some(.lively))
                        Text("Normal").tag(PetEnergy?.some(.normal))
                        Text("Low").tag(PetEnergy?.some(.low))
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                RowDivider()
                SettingsButton("Play the wake-up again") { home.replayMorning() }
                RowDivider()
                SettingsButton("Show the first open again") { home.onboarded = false }
                RowDivider()
                SettingsButton("Grow the food back") { model.regrowFood() }
                RowDivider()
                SettingsButton("Refresh now") { Task { await model.refresh() } }
            }

            if let error = model.errorMessage {
                Text(error)
                    .scaledFont(14, .medium)
                    .foregroundStyle(Jade.ink2)
                    .card()
                    .padding(.top, 10)
            }
        }
        .onChange(of: model.dataMode) { Task { await model.refresh() } }
        .onChange(of: model.sleepSchedule) {
            Task { await model.refresh() }
            // 点点头 (PRD §5.3): the pet nods when it is next on screen
            PetStage.shared.react("nod")
        }
    }

    /// Weekend targets start as a copy of the weekday ones; off = the same every night.
    private var weekendsApart: Binding<Bool> {
        Binding(get: { model.sleepSchedule.weekendBedtimeMinutes != nil }, set: { on in
            model.sleepSchedule.weekendBedtimeMinutes = on ? model.sleepSchedule.bedtimeMinutes : nil
            model.sleepSchedule.weekendWakeMinutes = on ? model.sleepSchedule.wakeMinutes : nil
        })
    }

    private func weekendBinding(_ weekend: WritableKeyPath<SleepSchedule, Int?>, _ weekday: KeyPath<SleepSchedule, Int>) -> Binding<Int> {
        Binding(get: { model.sleepSchedule[keyPath: weekend] ?? model.sleepSchedule[keyPath: weekday] },
                set: { model.sleepSchedule[keyPath: weekend] = $0 })
    }

    /// Turning a notification on asks for permission first; a "no" leaves it off.
    private func notification(_ key: ReferenceWritableKeyPath<HomeState, Bool>) -> Binding<Bool> {
        Binding(get: { home[keyPath: key] }, set: { on in
            guard on else { home[keyPath: key] = false; return }
            Task { @MainActor in
                home[keyPath: key] = await PetNotifications.requestPermission()
            }
        })
    }
}

/// A sleep target: the label on the left, a menu of half-hour times on the right.
private struct TimeRow: View {
    let title: String
    @Binding var minutes: Int
    let options: [Int]

    init(_ title: String, minutes: Binding<Int>, options: [Int]) {
        self.title = title
        _minutes = minutes
        self.options = options
    }

    var body: some View {
        SettingsRow(title) {
            Picker(title, selection: $minutes) {
                // a time saved before half-hour steps (or out of range) still shows
                ForEach(options.contains(minutes) ? options : [minutes] + options, id: \.self) { value in
                    Text(SleepSchedule.clock(value)).tag(value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
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
                .scaledFont(13, .semibold)
                .foregroundStyle(Jade.ink2)
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
        Text(text).scaledFont(16, .medium).foregroundStyle(Jade.ink)
    }
}

/// 24-hour or 12-hour (PRD v0.3 §6): each choice shows an example, the row shows the choice.
private struct TimeFormatMenu: View {
    private let clock = ClockStyle.shared

    var body: some View {
        Menu {
            choice("24-hour", example: "22:48", twelveHour: false)
            choice("12-hour", example: "10:48 PM", twelveHour: true)
        } label: {
            HStack(spacing: 5) {
                Text(clock.twelveHour ? "12-hour" : "24-hour")
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold))
            }
            .scaledFont(16, .medium)
            .foregroundStyle(Jade.accent)
        }
        .accessibilityLabel("Time format, \(clock.twelveHour ? "12-hour" : "24-hour")")
    }

    private func choice(_ title: String, example: String, twelveHour: Bool) -> some View {
        Button { clock.twelveHour = twelveHour } label: {
            if clock.twelveHour == twelveHour {
                Label { Text(title); Text(example) } icon: { Image(systemName: "checkmark") }
            } else {
                Text(title)
                Text(example)
            }
        }
    }
}

/// A row that opens a web page or an email; until there is one, it says "Soon".
private struct LinkRow: View {
    let title: String
    let url: URL?
    @Environment(\.openURL) private var openURL

    init(_ title: String, url: URL?) {
        self.title = title
        self.url = url
    }

    var body: some View {
        if let url {
            Button { openURL(url) } label: {
                HStack {
                    SettingsLabel(title)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Jade.ink2)
                }
                .frame(minHeight: 54)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            SettingsRow(title) { SettingsValue("Soon") }
        }
    }
}

/// A short grey explanation under a row.
private struct SettingsNote: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .scaledFont(13, .medium)
            .foregroundStyle(Jade.ink2)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }
}

private struct SettingsValue: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).scaledFont(16, .medium).foregroundStyle(Jade.ink2)
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
                .scaledFont(16, .medium)
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

extension Bundle {
    /// The app's name under its icon ("Ovenpals"), as the Health app lists it.
    var displayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Ovenpals"
    }

    /// "0.3.0 (1)": the version and the build.
    var versionText: String {
        let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    /// A link set in Info.plist; nil while it is empty.
    func url(forInfoKey key: String) -> URL? {
        guard let text = object(forInfoDictionaryKey: key) as? String, !text.isEmpty else { return nil }
        return URL(string: text)
    }
}
