import SwiftUI
import PetCore

/// Share: swipe between cards (This week · Today · My pets); the options button holds the two
/// privacy switches; one Share button (the system sheet has Save Image).
struct ShareScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home
    @Environment(\.colorScheme) private var scheme
    @AppStorage("3d.share.numbers") private var showNumbers = true
    @AppStorage("3d.share.bedtimes") private var showBedtimes = false
    @State private var page = ShareCard.Kind.week
    @State private var image: Image?

    var body: some View {
        let data = ShareCard.Facts(model: model, userName: home.userName, showNumbers: showNumbers, showBedtimes: showBedtimes)
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
                    ShareCard(kind: kind, data: data)
                        .padding(.horizontal, Metrics.gutter)
                        .tag(kind)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: ShareCard.side + 20)
            .padding(.top, 18)
            PageDots(count: ShareCard.Kind.allCases.count, current: page.rawValue)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            Spacer(minLength: 16)
            Group {
                if let image {
                    ShareLink(item: image, preview: SharePreview("HealthPet", image: image)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {} label: { Label("Share", systemImage: "square.and.arrow.up") }.disabled(true)
                }
            }
            .buttonStyle(PillButtonStyle(primary: true))
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .background(Jade.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: "\(page.rawValue)-\(showNumbers)-\(showBedtimes)-\(scheme == .dark)") {
            image = render(ShareCard(kind: page, data: data))
        }
    }

    private func render(_ card: ShareCard) -> Image? {
        let renderer = ImageRenderer(content: card
            .frame(width: ShareCard.side, height: ShareCard.side)
            .padding(14)
            .background(Jade.canvas)
            .environment(\.colorScheme, scheme))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
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

/// One share card. Only the title + check, the pets, three numbers, and the name/date line.
struct ShareCard: View {
    enum Kind: Int, CaseIterable, Identifiable {
        case week, today, pets
        var id: Int { rawValue }
    }

    struct Facts {
        var weekNumber: Int
        var weekDone: Bool
        var workouts: Int
        var workoutsGoal: Int
        var nights: Int
        var nightsGoal: Int
        var weekSteps: Int
        var todayDone: Bool
        var onset: Date?
        var onTime: Bool
        var workoutMinutes: Int?
        var workoutName: String?
        var todaySteps: Int?
        var main: Pet3D
        /// Unlocked pets, main first, then highest level.
        var pets: [SharePet]
        var weekFooter: String
        var todayFooter: String
        var showNumbers: Bool
        var showBedtimes: Bool

        @MainActor
        init(model: AppModel, userName: String, showNumbers: Bool, showBedtimes: Bool) {
            let rules = model.discipline.rules
            weekNumber = model.weekNumber
            weekDone = model.week?.isDisciplined ?? false
            workouts = min(model.week?.workouts ?? 0, rules.workoutsPerWeek)
            workoutsGoal = rules.workoutsPerWeek
            nights = min(model.week?.onTimeNights ?? 0, rules.onTimeNightsPerWeek)
            nightsGoal = rules.onTimeNightsPerWeek
            weekSteps = model.weekSteps
            todayDone = model.checkInsToday > 0
            onset = model.today?.sleepOnset
            onTime = model.sleptOnTime
            workoutMinutes = model.mainWorkout.map { Int($0.minutes.rounded()) }
            workoutName = model.mainWorkout?.name
            todaySteps = model.today?.steps
            main = model.mainPet3D
            let records = model.petRecords.filter(\.isUnlocked)
            let mainRecord = records.first { $0.pet.id == model.mainPet3D.id }
            pets = ([mainRecord].compactMap { $0 } + records.filter { $0.pet.id != model.mainPet3D.id })
                .map { SharePet(pet: $0.pet, level: $0.level) }
            let name = userName.trimmingCharacters(in: .whitespaces)
            let prefix = name.isEmpty ? "" : "\(name) · "
            let range = model.weekRange
            weekFooter = prefix + Format.range(range.start, range.end)
            todayFooter = prefix + Date().formatted(.dateTime.month(.abbreviated).day())
            self.showNumbers = showNumbers
            self.showBedtimes = showBedtimes
        }
    }

    static let side: CGFloat = 340

    let kind: Kind
    let data: Facts

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(title).font(.rounded(34, .bold)).foregroundStyle(Jade.ink)
                Spacer()
                if done { CheckBadge(color: Jade.sleep, size: 26) }
            }
            Spacer(minLength: 8)
            pictures
                .frame(maxWidth: .infinity)
            Rectangle().fill(Jade.fill).frame(height: 1).padding(.top, 6)
            stats
                .padding(.top, 14)
            HStack {
                Text(kind == .today ? data.todayFooter : data.weekFooter)
                    .font(.rounded(10, .medium))
                    .foregroundStyle(Jade.ink2)
                Spacer()
                Text("HealthPet").font(.rounded(12, .bold)).foregroundStyle(Jade.ink)
            }
            .padding(.top, 16)
        }
        .padding(22)
        .frame(height: Self.side)
        .background(RoundedRectangle(cornerRadius: Metrics.card, style: .continuous).fill(Jade.card))
    }

    private var title: String {
        switch kind {
        case .week: "Week \(data.weekNumber)"
        case .today: "Today"
        case .pets: data.pets.count == 1 ? "1 pet" : "\(data.pets.count) pets"
        }
    }

    private var done: Bool {
        switch kind {
        case .week: data.weekDone
        case .today: data.todayDone
        case .pets: false
        }
    }

    @ViewBuilder
    private var pictures: some View {
        switch kind {
        case .week, .today:
            let friends = data.pets.dropFirst().prefix(kind == .week ? 2 : 0).map(\.pet)
            HStack(alignment: .bottom, spacing: -6) {
                if let left = friends.first { PetPicture(pet: left).frame(width: 74, height: 74) }
                PetPicture(pet: data.main, happy: true).frame(width: 124, height: 124).zIndex(1)
                if friends.count > 1 { PetPicture(pet: friends[1]).frame(width: 74, height: 74) }
            }
        case .pets:
            let shown = Array(data.pets.prefix(8))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                ForEach(shown) { item in
                    VStack(spacing: 1) {
                        PetPicture(pet: item.pet, happy: item.pet.id == data.main.id).frame(width: 52, height: 52)
                        Text("Lv \(item.level)").font(.rounded(9, .bold)).foregroundStyle(Jade.ink2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stats: some View {
        HStack(spacing: 22) {
            switch kind {
            case .week:
                Stat(icon: "waveform.path.ecg", text: "\(data.workouts)/\(data.workoutsGoal)")
                Stat(icon: "moon", text: "\(data.nights)/\(data.nightsGoal)")
                if data.showNumbers { Stat(icon: "shoeprints.fill", text: Format.short(data.weekSteps)) }
            case .today:
                if let onset = data.onset {
                    if data.showBedtimes { Stat(icon: "moon", text: Format.time(onset)) }
                    else if data.onTime { Stat(icon: "moon", text: "✓") }
                }
                if let minutes = data.workoutMinutes {
                    Stat(icon: workoutIcon(data.workoutName), text: data.showNumbers ? "\(minutes)m" : "✓")
                }
                if data.showNumbers, let steps = data.todaySteps { Stat(icon: "shoeprints.fill", text: Format.short(steps)) }
            case .pets:
                Stat(icon: "star", text: "Lv \(data.pets.map(\.level).max() ?? 1)")
                Stat(icon: "pawprint", text: "\(data.pets.count)/\(Pet3D.all.count)")
            }
        }
    }
}

struct SharePet: Identifiable {
    let pet: Pet3D
    let level: Int
    var id: String { pet.id }
}

private struct Stat: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(Jade.ink2)
            Text(text).font(.rounded(18, .bold)).foregroundStyle(Jade.ink).monospacedDigit()
        }
    }
}
