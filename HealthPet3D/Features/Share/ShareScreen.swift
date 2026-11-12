import SwiftUI
import PetCore

/// Share: swipe between cards (This week · Today · My pets); the options button holds the two
/// privacy switches; Card or 9:16 (a story picture) under the dots; one Share button (the system
/// sheet has Save Image).
/// Card v2 (PRD v0.2 §6, decided 2026-11-08): the reader is someone else, so a card has an
/// identity title and one plain line; the biggest number is every 自律周 so far.
struct ShareScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home
    @Environment(\.colorScheme) private var scheme
    @AppStorage("3d.share.numbers") private var showNumbers = true
    @AppStorage("3d.share.bedtimes") private var showBedtimes = false
    /// The picture is the 9:16 story (PRD v0.3 §6) instead of the card alone.
    @AppStorage("3d.share.story") private var story = false
    @State private var page: ShareCard.Kind = {
        #if DEBUG
        // For screenshots on the simulator: -hp3dShareCard today|pets
        switch UserDefaults.standard.string(forKey: "hp3dShareCard") {
        case "today": return .today
        case "pets": return .pets
        default: break
        }
        #endif
        return .week
    }()
    @State private var image: Image?

    var body: some View {
        let facts = ShareCard.Facts(model: model, home: home, showNumbers: showNumbers, showBedtimes: showBedtimes)
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "Share") {
                Menu {
                    Toggle("Show exact numbers", isOn: $showNumbers)
                    Toggle("Show bedtimes", isOn: $showBedtimes)
                } label: {
                    RoundIcon(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Options")
            }
            .padding(.horizontal, Metrics.gutter)
            TabView(selection: $page) {
                ForEach(ShareCard.Kind.allCases) { kind in
                    Group {
                        if story {
                            StoryPicture(card: ShareCard(kind: kind, facts: facts)).preview(height: ShareCard.height)
                        } else {
                            ShareCard(kind: kind, facts: facts)
                        }
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .tag(kind)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: ShareCard.height + 16)
            .padding(.top, 18)
            PageDots(count: ShareCard.Kind.allCases.count, current: page.rawValue)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            PictureSizePicker(story: $story)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
            Spacer(minLength: 16)
            ShareCardButton(image: image)
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .background(Jade.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: "\(page.rawValue)-\(showNumbers)-\(showBedtimes)-\(story)-\(scheme == .dark)") {
            let card = ShareCard(kind: page, facts: facts)
            image = story ? StoryPicture.render(card, scheme: scheme) : ShareCard.render(card, scheme: scheme)
        }
    }
}

/// The moment a 自律周 counts (after the cheer on home): the week's card slides up. Share / Not now.
struct WeekAchievedSheet: View {
    /// The week on the card; nil = this week. Last week's when it only counted on Monday at 04:00.
    var week: WeekProgress?
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("3d.share.numbers") private var showNumbers = true
    @AppStorage("3d.share.bedtimes") private var showBedtimes = false
    @State private var image: Image?

    var body: some View {
        let facts = ShareCard.Facts(model: model, home: home, showNumbers: showNumbers, showBedtimes: showBedtimes, week: week)
        VStack(spacing: 10) {
            ShareCard(kind: .week, facts: facts)
                .frame(width: ShareCard.exportWidth)
                .padding(.top, 20)
            ShareCardButton(image: image)
                .frame(width: ShareCard.exportWidth)
                .padding(.top, 4)
            Button("Not now") { dismiss() }
                .font(.rounded(15, .bold))
                .foregroundStyle(Jade.ink2)
                .frame(height: 36)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
        .background(Jade.canvas.ignoresSafeArea())
        .presentationDetents([.height(ShareCard.height + 150)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .task(id: scheme == .dark) {
            image = ShareCard.render(ShareCard(kind: .week, facts: facts), scheme: scheme)
        }
    }
}

/// The one Share button: the system sheet (with Save Image) for the rendered card.
struct ShareCardButton: View {
    let image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview(Bundle.main.displayName, image: image)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {} label: { Label("Share", systemImage: "square.and.arrow.up") }.disabled(true)
            }
        }
        .buttonStyle(PillButtonStyle(primary: true))
    }
}

struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Jade.ink : Jade.ink3.opacity(0.6))
                    .frame(width: i == current ? 16 : 5, height: 5)
            }
        }
        .animation(.spring(duration: 0.3), value: current)
        .accessibilityHidden(true)
    }
}

/// One share card, top to bottom: a stamp (what was achieved), the identity title, one plain line,
/// the pets on their oval (main pet in the middle, chest out, every pet with its Lv), then every
/// 自律周 so far as the biggest number, and name · date · Ovenpals with a line to find it by.
struct ShareCard: View {
    enum Kind: Int, CaseIterable, Identifiable {
        case week, today, pets
        var id: Int { rawValue }
    }

    struct Facts {
        var title: String
        var weekDone: Bool
        var workouts: Int
        var nights: Int
        var todayDone: Bool
        var onset: Date?
        var onTime: Bool
        var workoutMinutes: Int?
        var workoutName: String?
        var todaySteps: Int?
        var weeks: Int
        var left: SharePet?
        var main: SharePet
        var right: SharePet?
        /// Unlocked pets, main first, then highest level.
        var pets: [SharePet]
        var petsAvailable: Int
        /// The main pet stands proud, except in a low week (没电), when it just stands.
        var mainProud: Bool
        var weekFooter: String
        var todayFooter: String
        var showNumbers: Bool
        var showBedtimes: Bool

        /// `week`: the week card's week, nil = this one (last week's late 自律周, PRD v0.3 §4.4).
        @MainActor
        init(model: AppModel, home: HomeState, showNumbers: Bool, showBedtimes: Bool, week: WeekProgress? = nil) {
            let shownWeek = week ?? model.week
            title = model.identityTitle(onTimeNights: shownWeek?.onTimeNights ?? 0)
            weekDone = shownWeek?.isDisciplined ?? false
            workouts = shownWeek?.workouts ?? 0
            nights = shownWeek?.onTimeNights ?? 0
            todayDone = model.checkInsToday > 0
            onset = model.today?.sleepOnset
            onTime = model.sleptOnTime
            workoutMinutes = model.mainWorkout.map { Int($0.minutes.rounded()) }
            workoutName = model.mainWorkout?.name
            todaySteps = model.today?.steps
            weeks = model.disciplinedWeekTotal
            let trio = model.showOffPets
            left = trio.left.map(SharePet.init)
            main = SharePet(trio.main)
            right = trio.right.map(SharePet.init)
            let records = model.petRecords
            let unlocked = records.filter(\.isUnlocked)
            pets = ([trio.main] + unlocked.filter { $0.pet.id != trio.main.pet.id }).map(SharePet.init)
            petsAvailable = records.count
            mainProud = (home.energyOverride ?? model.energy) != .low
            let name = home.userName.trimmingCharacters(in: .whitespaces)
            let prefix = name.isEmpty ? "" : "\(name) · "
            let range = model.weekRange(starting: week?.weekStart)
            weekFooter = prefix + Format.range(range.start, range.end)
            todayFooter = prefix + Date().formatted(.dateTime.month(.abbreviated).day())
            self.showNumbers = showNumbers
            self.showBedtimes = showBedtimes
        }
    }

    /// The card's height on screen and in the exported picture.
    static let height: CGFloat = 456
    /// Width of the exported picture's card (plus a canvas margin around it).
    static let exportWidth: CGFloat = 340

    let kind: Kind
    let facts: Facts

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stamp
                .frame(height: 26)
            Text(facts.title)
                .font(.rounded(34, .heavy))
                .tracking(-1.2)
                .foregroundStyle(Jade.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .lineSpacing(-4)
                .padding(.top, 16)
            plainLine
                .padding(.top, 12)
            Spacer(minLength: 4)
            stage
                .frame(height: 168)
            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(height: Self.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Jade.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stamp: what was achieved (lime capsule + check)

    @ViewBuilder
    private var stamp: some View {
        switch kind {
        case .week:
            if facts.weekDone { Stamp(text: "Disciplined week") } else { Color.clear }
        case .today:
            if facts.todayDone { Stamp(text: "Checked in today") } else { Color.clear }
        case .pets:
            Stamp(text: facts.pets.count == 1 ? "1 pet" : "\(facts.pets.count) pets", check: false)
        }
    }

    // MARK: - One plain line

    @ViewBuilder
    private var plainLine: some View {
        HStack(spacing: 6) {
            switch kind {
            case .week:
                LineItem(icon: "waveform.path.ecg", color: Jade.accent,
                         text: facts.workouts == 1 ? "1 workout" : "\(facts.workouts) workouts")
                Dot()
                LineItem(icon: "moon", color: Jade.sleep,
                         text: facts.nights == 1 ? "1 early night" : "\(facts.nights) early nights")
            case .today:
                ForEach(Array(todayParts.enumerated()), id: \.offset) { i, part in
                    if i > 0 { Dot() }
                    LineItem(icon: part.icon, color: part.color, text: part.text)
                }
                if todayParts.isEmpty { LineItem(icon: "sun.max", color: Jade.ink2, text: "A quiet day") }
            case .pets:
                LineItem(icon: "pawprint", color: Jade.accent, text: "\(facts.pets.count) of \(facts.petsAvailable) pets")
                Dot()
                LineItem(icon: "star", color: Jade.sleep, text: "Lv \(facts.pets.map(\.level).max() ?? 0) top")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var todayParts: [(icon: String, color: Color, text: String)] {
        var parts: [(icon: String, color: Color, text: String)] = []
        if let minutes = facts.workoutMinutes, let name = facts.workoutName {
            parts.append((workoutIcon(name), Jade.accent, facts.showNumbers ? "\(name) \(minutes) min" : name))
        }
        if let onset = facts.onset {
            if facts.showBedtimes { parts.append(("moon", Jade.sleep, "Asleep \(Format.time(onset))")) }
            else if facts.onTime { parts.append(("moon", Jade.sleep, "On time")) }
        }
        if facts.showNumbers, let steps = facts.todaySteps, steps > 0 {
            parts.append(("shoeprints.fill", Jade.accent, "\(Format.short(steps)) steps"))
        }
        return Array(parts.prefix(2))
    }

    // MARK: - The pets on their oval

    @ViewBuilder
    private var stage: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Ellipse()
                    .fill(Jade.accent.opacity(0.18))
                    .frame(width: min(240, w * 0.85), height: 44)
                    .position(x: w / 2, y: h - 14 - 22)
                switch kind {
                case .week, .today:
                    trio(w: w, h: h)
                case .pets:
                    grid(w: w, h: h)
                }
            }
        }
    }

    @ViewBuilder
    private func trio(w: CGFloat, h: CGFloat) -> some View {
        if let left = facts.left {
            PetPicture(pet: left.pet).frame(width: 86, height: 86)
                .position(x: w * 0.17, y: h - 26 - 43)
            LevelChip(level: left.level).position(x: w * 0.17, y: h - 10)
        }
        if let right = facts.right {
            PetPicture(pet: right.pet).frame(width: 84, height: 84)
                .position(x: w * 0.83, y: h - 26 - 42)
            LevelChip(level: right.level).position(x: w * 0.83, y: h - 10)
        }
        PetPicture(pet: facts.main.pet, happy: !facts.mainProud, proud: facts.mainProud)
            .frame(width: 130, height: 130)
            .position(x: w / 2, y: h - 22 - 65)
        LevelChip(level: facts.main.level).position(x: w / 2, y: h - 10)
    }

    @ViewBuilder
    private func grid(w: CGFloat, h: CGFloat) -> some View {
        let shown = Array(facts.pets.prefix(5))
        let step = w / CGFloat(max(shown.count, 1))
        ForEach(Array(shown.enumerated()), id: \.element.id) { i, item in
            let main = item.id == facts.main.id
            let side: CGFloat = main ? 92 : 66
            let x = step * (CGFloat(i) + 0.5)
            PetPicture(pet: item.pet, happy: main)
                .frame(width: side, height: side)
                .position(x: x, y: h - 26 - side / 2)
            LevelChip(level: item.level).position(x: x, y: h - 10)
        }
    }

    // MARK: - Footer: every 自律周 so far · name and date · Ovenpals

    private var footer: some View {
        HStack(alignment: .bottom) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(facts.weeks)")
                    .font(.rounded(40, .heavy))
                    .foregroundStyle(Jade.ink)
                    .monospacedDigit()
                Text(facts.weeks == 1 ? "disciplined\nweek" : "disciplined\nweeks")
                    .font(.rounded(13, .semibold))
                    .foregroundStyle(Jade.ink2)
                    .lineSpacing(-2)
                    .fixedSize()
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(kind == .week ? facts.weekFooter : facts.todayFooter)
                    .font(.rounded(11, .medium))
                    .foregroundStyle(Jade.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Ovenpals").font(.rounded(14, .heavy)).foregroundStyle(Jade.ink)
                // someone who sees the card can find the app (PRD v0.3 §6): a short link once there
                // is one, until then the name above and what it is
                Text(Self.findLine)
                    .font(.rounded(10, .semibold))
                    .foregroundStyle(Jade.ink2)
                    .lineLimit(1)
            }
        }
        .padding(.top, 14)
        .overlay(alignment: .top) { Rectangle().fill(Jade.fill).frame(height: 1) }
        .padding(.top, 6)
    }

    /// "ovenpals.app" once `ShareLinkText` is set in Info.plist, else "iPhone app".
    static var findLine: String {
        let link = (Bundle.main.object(forInfoDictionaryKey: "ShareLinkText") as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return link.isEmpty ? "iPhone app" : link
    }

    // MARK: - Export

    @MainActor
    static func render(_ card: ShareCard, scheme: ColorScheme) -> Image? {
        let renderer = ImageRenderer(content: card
            .frame(width: exportWidth, height: height)
            .padding(14)
            .background(Jade.canvas)
            .environment(\.colorScheme, scheme))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// The 9:16 story picture (PRD v0.3 §6, decided 2026-11-10): the card in the middle of a
/// 1080 × 1920 canvas, clear of the bars a story app lays over the top and bottom.
struct StoryPicture: View {
    let card: ShareCard

    static let size = CGSize(width: 360, height: 640)
    /// The card at 86 %: 292 × 392 pt, from about 124 pt to 516 pt down.
    private static let cardScale: CGFloat = 0.86

    var body: some View {
        let s = Self.cardScale
        card
            .frame(width: ShareCard.exportWidth, height: ShareCard.height)
            .scaleEffect(s)
            .frame(width: ShareCard.exportWidth * s, height: ShareCard.height * s)
            .frame(width: Self.size.width, height: Self.size.height)
            .background(Jade.canvas)
    }

    /// On the Share page: the whole picture, scaled down to the card's height, with a hairline edge.
    func preview(height: CGFloat) -> some View {
        let k = height / Self.size.height
        return self
            .scaleEffect(k)
            .frame(width: Self.size.width * k, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Jade.ink3.opacity(0.5), lineWidth: 1))
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
    }

    /// 1080 × 1920.
    @MainActor
    static func render(_ card: ShareCard, scheme: ColorScheme) -> Image? {
        let renderer = ImageRenderer(content: StoryPicture(card: card).environment(\.colorScheme, scheme))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// Card or 9:16, two small capsules under the page dots.
private struct PictureSizePicker: View {
    @Binding var story: Bool

    var body: some View {
        HStack(spacing: 6) {
            chip("Card", on: !story) { story = false }
            chip("9:16", on: story) { story = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Picture size")
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.rounded(13, .bold))
                .foregroundStyle(on ? Jade.onPrimary : Jade.ink2)
                .padding(.horizontal, 14)
                .frame(minHeight: 30)
                .background(Capsule().fill(on ? Jade.primary : Jade.fill))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityLabel(title == "9:16" ? "Story, 9 by 16" : "Card")
    }
}

struct SharePet: Identifiable {
    let pet: Pet3D
    let level: Int
    var id: String { pet.id }

    init(_ record: PetRecord) {
        pet = record.pet
        level = record.level
    }
}

/// The lime capsule stamp at the top of a card.
private struct Stamp: View {
    let text: String
    var check = true

    var body: some View {
        HStack(spacing: 5) {
            if check {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .black))
            }
            Text(text.uppercased()).font(.rounded(11, .heavy)).tracking(0.7)
        }
        .foregroundStyle(Jade.onSleep)
        .padding(.leading, check ? 9 : 11)
        .padding(.trailing, 11)
        .frame(height: 26)
        .background(Capsule().fill(Jade.sleep))
    }
}

private struct LineItem: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            Text(text).font(.rounded(15, .heavy)).foregroundStyle(Jade.ink2)
        }
    }
}

private struct Dot: View {
    var body: some View {
        Text("·").font(.rounded(15, .heavy)).foregroundStyle(Jade.ink3)
    }
}

private struct LevelChip: View {
    let level: Int

    var body: some View {
        Text("Lv \(level)")
            .font(.rounded(11, .heavy))
            .foregroundStyle(Jade.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Jade.fill))
            .fixedSize()
    }
}
