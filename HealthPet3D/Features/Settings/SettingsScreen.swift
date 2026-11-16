import SwiftUI
import PetCore

/// Settings, from home's 「…」 (B 卡片版, decided 2026-11-16): two source tiles, then one card per
/// topic, each with an icon heading. Sleep shows the two targets as big numbers over a night bar
/// whose moon and sun can be dragged in half-hour steps (a tap on a number opens the time wheel);
/// Look shows the three appearances as small screens and a strip of how the name sits on a share
/// card; the switches are the app's own 小脸开关. The app's icon, name and version close the page,
/// and the test build's switches sit in a dashed card under it.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home
    @AppStorage(FeelSettings.soundKey) private var soundEffects = true
    @AppStorage(FeelSettings.hapticsKey) private var haptics = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The target whose time wheel is open.
    @State private var editing: SleepTarget?
    /// A target while its knob is being dragged on the night bar; saved when the finger lifts.
    @State private var preview: [SleepTarget: Int] = [:]
    /// Counts sound switching on: a small ♪ hops off the switch each time.
    @State private var notes = 0
    @FocusState private var nameFocused: Bool

    var body: some View {
        @Bindable var model = model
        @Bindable var home = home
        PageScroll {
            PageHeader(title: "Settings")
            sources
            // Nothing for a few days: access may be off, and only the Health app can turn it
            // back on (PRD v0.3 §6).
            if model.appleHealthConnected && model.appleHealthQuiet {
                Text("Nothing from Apple Health for \(model.daysWithoutData) days. To check access, open the Health app, tap your picture, then Apps › \(Bundle.main.displayName).")
                    .scaledFont(13, .medium)
                    .foregroundStyle(Jade.ink2)
                    .lineSpacing(2)
                    .card(padding: 14, radius: Metrics.tile)
            }
            sleepCard
            remindersCard
            lookCard(name: $home.userName)
            feelCard
            AboutFooter()
            testBuild(data: $model.dataMode, energy: $home.energyOverride)
            if let error = model.errorMessage {
                Text(error)
                    .scaledFont(14, .medium)
                    .foregroundStyle(Jade.ink2)
                    .card()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $editing) { target in
            TargetWheelSheet(title: target.title, icon: target.icon, options: target.options, minutes: binding(target))
        }
        .onChange(of: model.dataMode) { Task { await model.refresh() } }
        .onChange(of: model.sleepSchedule) {
            Task { await model.refresh() }
            // 点点头 (PRD §5.3): the pet nods when it is next on screen
            PetStage.shared.react("nod")
        }
        .onChange(of: soundEffects) { _, on in if on { notes += 1 } }
    }

    // MARK: Sources

    private var sources: some View {
        HStack(alignment: .top, spacing: Metrics.gap) {
            SourceTile(icon: "heart.fill", name: "Apple Health") {
                if model.appleHealthConnected {
                    SourceOn(detail: readDetail)
                } else {
                    Button("Connect") { Task { await model.connectAppleHealth() } }
                        .buttonStyle(SmallPillStyle())
                }
            }
            SourceTile(icon: "waveform.path.ecg", name: "Whoop") {
                switch model.whoopStatus {
                case .unavailable:
                    Text("Not in this build").scaledFont(12.5, .semibold).foregroundStyle(Jade.ink2)
                case .notConnected:
                    Button("Connect") { Task { await model.connectWhoop() } }
                        .buttonStyle(SmallPillStyle())
                case .connected:
                    SourceOn(detail: readDetail)
                    Button("Disconnect") { Task { await model.disconnectWhoop() } }
                        .buttonStyle(SmallPillStyle(primary: false))
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// "Read at 21:02": when the app last brought something in.
    private var readDetail: String {
        if model.dataMode == .demo { return "Demo data" }
        return model.lastReadAt.map { "Read at \(Format.time($0))" } ?? "Connected"
    }

    // MARK: Sleep

    private var apart: Bool { model.sleepSchedule.weekendBedtimeMinutes != nil }

    private var sleepCard: some View {
        TopicCard(icon: "moon.fill", title: "Sleep") {
            ChoiceChips(options: [(false, "Every night"), (true, "Weekends apart")], selection: weekendsApart)
        } content: {
            HStack(alignment: .top, spacing: 8) {
                BigTime(label: "Asleep by", icon: "moon.fill", minutes: shown(.bed)) { editing = .bed }
                BigTime(label: "Up by", icon: "sun.max.fill", minutes: shown(.wake)) { editing = .wake }
            }
            NightBar(bed: shown(.bed), wake: shown(.wake), bedTarget: .bed, wakeTarget: .wake,
                     onDrag: { preview[$0] = $1 }, onEnd: commit)
                .padding(.top, 4)
            if apart {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        BigTime(label: "Fri & Sat", icon: "moon.fill", minutes: shown(.weekendBed), small: true,
                                spoken: SleepTarget.weekendBed.title) { editing = .weekendBed }
                        BigTime(label: "Sat & Sun", icon: "sun.max.fill", minutes: shown(.weekendWake), small: true,
                                spoken: SleepTarget.weekendWake.title) { editing = .weekendWake }
                    }
                    NightBar(bed: shown(.weekendBed), wake: shown(.weekendWake), bedTarget: .weekendBed,
                             wakeTarget: .weekendWake, mini: true, onDrag: { preview[$0] = $1 }, onEnd: commit)
                }
                .padding(.top, 12)
                .overlay(alignment: .top) { Rectangle().fill(Jade.fill).frame(height: 1) }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.8), value: apart)
    }

    private func stored(_ target: SleepTarget) -> Int {
        let s = model.sleepSchedule
        switch target {
        case .bed: return s.bedtimeMinutes
        case .wake: return s.wakeMinutes
        case .weekendBed: return s.weekendBedtimeMinutes ?? s.bedtimeMinutes
        case .weekendWake: return s.weekendWakeMinutes ?? s.wakeMinutes
        }
    }

    private func shown(_ target: SleepTarget) -> Int { preview[target] ?? stored(target) }

    private func binding(_ target: SleepTarget) -> Binding<Int> {
        Binding(get: { stored(target) }, set: { value in
            switch target {
            case .bed: model.sleepSchedule.bedtimeMinutes = value
            case .wake: model.sleepSchedule.wakeMinutes = value
            case .weekendBed: model.sleepSchedule.weekendBedtimeMinutes = value
            case .weekendWake: model.sleepSchedule.weekendWakeMinutes = value
            }
        })
    }

    /// The finger lifted off a knob: the dragged time is saved (once, so the pet nods once).
    private func commit(_ target: SleepTarget) {
        guard let value = preview.removeValue(forKey: target), value != stored(target) else { return }
        binding(target).wrappedValue = value
    }

    /// Weekend targets start as a copy of the weekday ones; off = the same every night.
    private var weekendsApart: Binding<Bool> {
        Binding(get: { apart }, set: { on in
            model.sleepSchedule.weekendBedtimeMinutes = on ? model.sleepSchedule.bedtimeMinutes : nil
            model.sleepSchedule.weekendWakeMinutes = on ? model.sleepSchedule.wakeMinutes : nil
        })
    }

    // MARK: Reminders

    private var remindersCard: some View {
        TopicCard(icon: "bell.fill", title: "Reminders", bottom: 4) {
            Toggle(isOn: notification(\.notifyBedtime)) {
                RowLabel("Bedtime", sub: Format.time(minutes: model.sleepSchedule.bedtimeMinutes - 30))
            }
            .toggleStyle(.face)
            .frame(minHeight: 54)
            CardDivider()
            Toggle(isOn: notification(\.notifyMorning)) { RowLabel("Morning", sub: "When you wake") }
                .toggleStyle(.face)
                .frame(minHeight: 54)
        }
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

    // MARK: Look

    private func lookCard(name: Binding<String>) -> some View {
        let clock = ClockStyle.shared
        return TopicCard(icon: "circle.lefthalf.filled", title: "Look") {
            HStack(spacing: 10) {
                ForEach(Appearance.allCases) { look in
                    AppearanceThumb(appearance: look, picked: home.appearance == look, still: model.mainPet3D.still) {
                        home.appearance = look
                    }
                }
            }
            .padding(.bottom, 8)
            ChipRow("Time") {
                ChoiceChips(options: [(false, "22:48"), (true, "10:48 PM")],
                            selection: Binding(get: { clock.twelveHour }, set: { clock.twelveHour = $0 }))
            }
            CardDivider()
            HStack(spacing: 10) {
                RowLabel("Name on cards")
                Spacer(minLength: 8)
                TextField("Your name", text: name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .multilineTextAlignment(.trailing)
                    .scaledFont(16, .semibold)
                    .foregroundStyle(nameFocused ? Jade.ink : Jade.ink2)
                    .focused($nameFocused)
                    .frame(maxWidth: 160)
                    .accessibilityLabel("Name on share cards")
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Jade.ink3)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 54)
            .contentShape(Rectangle())
            .onTapGesture { nameFocused = true }
            NameStrip(name: name.wrappedValue, range: model.weekRange(starting: nil))
                .padding(.top, 2)
        }
    }

    // MARK: Sounds & Haptics

    // PRD v0.3 §8.4: the app's own sounds and taps, each on its own; the ring/silent switch
    // still mutes the sounds, and notifications follow iOS
    private var feelCard: some View {
        TopicCard(icon: "speaker.wave.2.fill", title: "Sounds & Haptics", bottom: 4) {
            Toggle(isOn: $soundEffects) { RowLabel("Sound effects") }
                .toggleStyle(.face)
                .frame(minHeight: 54)
                .overlay(alignment: .trailing) { NoteHop(trigger: notes).offset(x: -6, y: -14) }
            CardDivider()
            Toggle(isOn: $haptics) { RowLabel("Haptics") }
                .toggleStyle(.face)
                .frame(minHeight: 54)
        }
    }

    // MARK: Test build

    private static let energies: [(value: PetEnergy?, title: String)] =
        [(nil, "From data"), (.lively, "Lively"), (.normal, "Normal"), (.low, "Low")]

    private func testBuild(data: Binding<DataMode>, energy: Binding<PetEnergy?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Test build")
            } icon: {
                Image(systemName: "flask").font(.system(size: 12, weight: .bold))
            }
            .scaledFont(13, .bold)
            .foregroundStyle(Jade.ink2)
            .padding(.leading, 18)
            .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                // Real data = Apple Health plus Whoop when it is connected
                ChipRow("Data") {
                    ChoiceChips(options: [(DataMode.live, "Real data"), (.demo, "Demo")], selection: data)
                }
                CardDivider()
                VStack(alignment: .leading, spacing: 8) {
                    RowLabel("Pet energy")
                    ChoiceChips(options: Self.energies, selection: energy)
                }
                .padding(.vertical, 12)
                CardDivider()
                TestAction("Play the wake-up again") { home.replayMorning() }
                CardDivider()
                TestAction("Show the first open again") { home.onboarded = false }
                CardDivider()
                TestAction("Grow the food back") { model.regrowFood() }
                CardDivider()
                TestAction("Refresh now") { Task { await model.refresh() } }
            }
            .padding(.horizontal, 18)
            .background(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous)
                .strokeBorder(Jade.ink3, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        }
        .padding(.top, 4)
    }
}

// MARK: - The sleep targets

/// The four times the sleep card can set; each opens its own wheel.
private enum SleepTarget: String, Identifiable {
    case bed, wake, weekendBed, weekendWake
    var id: String { rawValue }

    var title: String {
        switch self {
        case .bed: "Asleep by"
        case .wake: "Up by"
        case .weekendBed: "Fri & Sat asleep by"
        case .weekendWake: "Sat & Sun up by"
        }
    }

    var icon: String { isBed ? "moon.fill" : "sun.max.fill" }
    var options: [Int] { isBed ? SleepOptions.bedtimes : SleepOptions.wakes }
    var isBed: Bool { self == .bed || self == .weekendBed }
}

/// A target as a big number with its name over it; a tap opens the wheel. The period (12-hour
/// clock) follows smaller, in grey, like home's Asleep row.
private struct BigTime: View {
    let label: String
    let icon: String
    let minutes: Int
    var small = false
    /// What VoiceOver says, when the label is short ("Fri & Sat" → "Fri & Sat asleep by").
    var spoken: String? = nil
    let action: () -> Void

    var body: some View {
        let parts = Format.timeParts(minutes: minutes)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(Jade.sleepText)
                    Text(label).scaledFont(12.5, .bold).foregroundStyle(Jade.ink2)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(parts.clock)
                        .scaledFont(small ? 24 : 36, .heavy)
                        .monospacedDigit()
                        .foregroundStyle(Jade.ink)
                        .contentTransition(.numericText())
                    if let period = parts.period {
                        Text(period).scaledFont(small ? 12 : 15, .heavy).foregroundStyle(Jade.ink2)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: minutes)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken ?? label)
        .accessibilityValue(Format.time(minutes: minutes))
        .accessibilityHint("Opens a time wheel")
        .accessibilityAddTraits(.isButton)
    }
}

/// The night from 20:00 to 11:00 the next morning: a lime span from bedtime to waking up, a moon
/// knob and a sun knob that drag in half-hour steps (bedtimes 20:00–02:00, wake-ups 04:00–11:00),
/// and four hour marks under it. VoiceOver uses the big numbers above instead.
private struct NightBar: View {
    let bed: Int
    let wake: Int
    let bedTarget: SleepTarget
    let wakeTarget: SleepTarget
    var mini = false
    let onDrag: (SleepTarget, Int) -> Void
    let onEnd: (SleepTarget) -> Void

    @State private var held: SleepTarget?
    private static let start = 20 * 60
    private static let span = 15 * 60
    private static let space = "nightBar"

    var body: some View {
        let trackY: CGFloat = mini ? 14 : 17
        let trackHeight: CGFloat = mini ? 8 : 10
        let knob: CGFloat = mini ? 22 : 28
        GeometryReader { geo in
            let width = geo.size.width
            let a = Self.fraction(bed) * width
            let b = Self.fraction(wake) * width
            ZStack(alignment: .topLeading) {
                Capsule().fill(Jade.fill)
                    .frame(width: width, height: trackHeight)
                    .position(x: width / 2, y: trackY)
                Capsule().fill(Jade.sleep)
                    .overlay(Capsule().strokeBorder(Jade.limeStroke, lineWidth: 1))
                    .frame(width: max(trackHeight, b - a), height: trackHeight)
                    .position(x: a + max(trackHeight, b - a) / 2, y: trackY)
                if !mini {
                    ForEach([20 * 60, 24 * 60, 28 * 60, 32 * 60], id: \.self) { mark in
                        Text(Format.hourMark(minutes: mark))
                            .font(.rounded(10.5, .bold))
                            .monospacedDigit()
                            .foregroundStyle(Jade.ink2)
                            .fixedSize()
                            .position(x: CGFloat(mark - Self.start) / CGFloat(Self.span) * width, y: 40)
                    }
                }
                knobView("moon.fill", size: knob, target: bedTarget)
                    .gesture(drag(bedTarget, width: width))
                    .position(x: a, y: trackY)
                knobView("sun.max.fill", size: knob, target: wakeTarget)
                    .gesture(drag(wakeTarget, width: width))
                    .position(x: b, y: trackY)
            }
            .coordinateSpace(.named(Self.space))
        }
        .frame(height: mini ? 28 : 48)
        .padding(.horizontal, 6)
        .sensoryFeedback(.selection, trigger: bed) { _, _ in held != nil && FeelSettings.haptics }
        .sensoryFeedback(.selection, trigger: wake) { _, _ in held != nil && FeelSettings.haptics }
        .accessibilityHidden(true)
    }

    private func knobView(_ icon: String, size: CGFloat, target: SleepTarget) -> some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(Jade.sleepText)
            .frame(width: size, height: size)
            .background(Circle().fill(Jade.card).shadow(color: .black.opacity(0.2), radius: 3, y: 2))
            // a lime ring: a card-coloured knob would vanish into the night card
            .overlay(Circle().strokeBorder(Jade.sleep, lineWidth: 1.5))
            .scaleEffect(held == target ? 1.12 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: held == target)
            // a finger is wider than the knob
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    private func drag(_ target: SleepTarget, width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                held = target
                let f = Double(min(1, max(0, value.location.x / max(1, width))))
                var minutes = Int(((Double(Self.start) + f * Double(Self.span)) / 30).rounded()) * 30
                minutes = target.isBed ? min(26 * 60, max(20 * 60, minutes)) : min(35 * 60, max(28 * 60, minutes))
                onDrag(target, minutes % 1440)
            }
            .onEnded { _ in
                held = nil
                onEnd(target)
            }
    }

    /// Where a time sits on the bar, 0 (20:00) to 1 (11:00 the next day).
    static func fraction(_ minutes: Int) -> CGFloat {
        let m = ((minutes % 1440) + 1440) % 1440
        let t = m < 12 * 60 ? m + 1440 : m
        return min(1, max(0, CGFloat(t - start) / CGFloat(span)))
    }
}

// MARK: - Pieces

/// A topic card: an icon and a name at the top (with an optional control on the right), then
/// its rows.
private struct TopicCard<Accessory: View, Content: View>: View {
    let icon: String
    let title: String
    /// Less room under a card that ends in a row of its own height.
    let bottom: CGFloat
    let accessory: () -> Accessory
    let content: () -> Content

    init(icon: String, title: String, bottom: CGFloat = 18, @ViewBuilder accessory: @escaping () -> Accessory,
         @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.title = title
        self.bottom = bottom
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { heading; Spacer(minLength: 8); accessory() }
                VStack(alignment: .leading, spacing: 10) { heading; accessory() }
            }
            VStack(alignment: .leading, spacing: 0) { content() }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, bottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.card, style: .continuous).fill(Jade.card))
    }

    private var heading: some View {
        Label {
            Text(title).scaledFont(15, .bold)
        } icon: {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
        }
        .labelStyle(TightLabel())
        .foregroundStyle(Jade.ink)
        .accessibilityAddTraits(.isHeader)
    }
}

extension TopicCard where Accessory == EmptyView {
    init(icon: String, title: String, bottom: CGFloat = 18, @ViewBuilder content: @escaping () -> Content) {
        self.init(icon: icon, title: title, bottom: bottom, accessory: { EmptyView() }, content: content)
    }
}

/// An icon and a title 7 pt apart.
private struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 7) {
            configuration.icon
            configuration.title
        }
    }
}

/// A row's name, with an optional grey line under it.
private struct RowLabel: View {
    let title: String
    var sub: String? = nil

    init(_ title: String, sub: String? = nil) {
        self.title = title
        self.sub = sub
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).scaledFont(16, .semibold).foregroundStyle(Jade.ink)
            if let sub { Text(sub).scaledFont(12.5, .semibold).foregroundStyle(Jade.ink2) }
        }
    }
}

/// A row with chips on the right, or under the name when they don't fit beside it.
private struct ChipRow<Chips: View>: View {
    let title: String
    @ViewBuilder var chips: () -> Chips

    init(_ title: String, @ViewBuilder chips: @escaping () -> Chips) {
        self.title = title
        self.chips = chips
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                RowLabel(title)
                Spacer(minLength: 8)
                chips()
            }
            .frame(minHeight: 54)
            VStack(alignment: .leading, spacing: 8) {
                RowLabel(title)
                chips()
            }
            .padding(.vertical, 12)
        }
    }
}

private struct CardDivider: View {
    var body: some View {
        Rectangle().fill(Jade.fill).frame(height: 1)
    }
}

/// One source: its name, then On with when it was last read, or Connect.
private struct SourceTile<Content: View>: View {
    let icon: String
    let name: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label {
                Text(name).scaledFont(15, .bold).lineLimit(1).minimumScaleFactor(0.8)
            } icon: {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            }
            .labelStyle(TightLabel())
            .foregroundStyle(Jade.ink)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous).fill(Jade.card))
        .accessibilityElement(children: .contain)
    }
}

private struct SourceOn: View {
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                CheckBadge(size: 20).accessibilityHidden(true)
                Text("On").scaledFont(22, .heavy).foregroundStyle(Jade.ink)
            }
            Text(detail).scaledFont(12.5, .semibold).foregroundStyle(Jade.ink2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One appearance as a small screen (Auto = the day one and the night one cut corner to corner),
/// with its name under it; the picked one has a jade ring and a check.
private struct AppearanceThumb: View {
    let appearance: Appearance
    let picked: Bool
    let still: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    switch appearance {
                    case .system:
                        // the night one whole, the day one over its upper half: no seam between them
                        ZStack {
                            MiniScreen(dark: true, still: still)
                            MiniScreen(dark: false, still: still).clipShape(HalfCut(upper: true))
                        }
                    case .light: MiniScreen(dark: false, still: still)
                    case .dark: MiniScreen(dark: true, still: still)
                    }
                    if picked { CheckBadge(size: 20).padding(6).accessibilityHidden(true) }
                }
                .aspectRatio(92 / 112, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(picked ? Jade.accent : Jade.fill, lineWidth: picked ? 2.5 : 1)
                )
                Text(title).scaledFont(13, .heavy).foregroundStyle(picked ? Jade.ink : Jade.ink2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: picked)
        .sensoryFeedback(.selection, trigger: picked) { _, now in now && FeelSettings.haptics }
        .accessibilityLabel("Appearance, \(title)")
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    private var title: String { appearance == .system ? "Auto" : appearance.title }
}

/// Home in miniature, in fixed day or night colours: a bar, the pet, a card.
private struct MiniScreen: View {
    let dark: Bool
    let still: String

    var body: some View {
        let canvas = Color(UIColor(hex: dark ? 0x121611 : 0xEBE9E3))
        let card = Color(UIColor(hex: dark ? 0x1D231B : 0xF8F6F3))
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                canvas
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(card)
                    .frame(width: w * 0.76, height: h * 0.1)
                    .offset(x: w * 0.12, y: h * 0.16)
                Image(still).resizable().scaledToFit()
                    .frame(width: w * 0.56, height: w * 0.56)
                    .offset(x: w * 0.22, y: h * 0.31)
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(card)
                    .frame(width: w * 0.76, height: h * 0.14)
                    .offset(x: w * 0.12, y: h * 0.76)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Half of a rectangle, cut from its top-right corner to its bottom-left one.
private struct HalfCut: Shape {
    let upper: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if upper {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

/// How the name sits at the foot of a share card: "Sam · Nov 9 – Nov 15 … Ovenpals".
private struct NameStrip: View {
    let name: String
    let range: (start: Date, end: Date)

    var body: some View {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let dates = Format.range(range.start, range.end)
        HStack(spacing: 8) {
            (trimmed.isEmpty ? Text(dates) : Text(trimmed).foregroundStyle(Jade.ink).fontWeight(.heavy) + Text(" · \(dates)"))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(Bundle.main.displayName).fontWeight(.heavy).foregroundStyle(Jade.ink)
        }
        .scaledFont(11.5, .bold)
        .foregroundStyle(Jade.ink2)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Jade.canvas))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("On share cards: \(trimmed.isEmpty ? "" : "\(trimmed), ")\(dates)")
    }
}

/// A small ♪ that hops up off the sound switch and fades when sound is turned on.
private struct NoteHop: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Hop {
        var y: CGFloat = 0
        var opacity: Double = 0
    }

    var body: some View {
        let still = reduceMotion
        Text("♪")
            .font(.rounded(15, .black))
            .foregroundStyle(Jade.accent)
            .keyframeAnimator(initialValue: Hop(), trigger: trigger) { view, hop in
                view.offset(y: still ? 0 : hop.y).opacity(hop.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    LinearKeyframe(0, duration: 0.01)
                    CubicKeyframe(-24, duration: 1.0)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.08)
                    LinearKeyframe(1, duration: 0.45)
                    LinearKeyframe(0, duration: 0.5)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The app's icon, name and version, then the two links (privacy policy, feedback); a link that
/// is not set yet says "Soon".
private struct AboutFooter: View {
    var body: some View {
        VStack(spacing: 6) {
            Image("about_icon")
                .resizable()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Jade.fill, lineWidth: 1))
                .softShadow(0.8)
                .accessibilityHidden(true)
            Text(Bundle.main.displayName).scaledFont(15, .heavy).foregroundStyle(Jade.ink)
            Text(Bundle.main.versionText).scaledFont(13, .semibold).foregroundStyle(Jade.ink2)
                .accessibilityLabel("Version \(Bundle.main.versionText)")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { links }
                VStack(spacing: 8) { links }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    @ViewBuilder private var links: some View {
        FooterLink(title: "Privacy policy", url: Bundle.main.url(forInfoKey: "PrivacyPolicyURL"))
        FooterLink(title: "Send feedback", url: Bundle.main.url(forInfoKey: "FeedbackURL"))
    }
}

private struct FooterLink: View {
    let title: String
    let url: URL?
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url {
            Button { openURL(url) } label: {
                HStack(spacing: 6) {
                    Text(title)
                    Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Jade.ink2)
                }
                .pill(ink: Jade.ink)
            }
            .buttonStyle(.plain)
        } else {
            Text("\(title) · Soon").pill(ink: Jade.ink2)
        }
    }
}

private extension View {
    func pill(ink: Color) -> some View {
        scaledFont(14, .bold)
            .foregroundStyle(ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(Capsule().fill(Jade.card))
    }
}

/// A test-build action: the whole row, in jade.
private struct TestAction: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .scaledFont(16, .semibold)
                .foregroundStyle(Jade.accent)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
