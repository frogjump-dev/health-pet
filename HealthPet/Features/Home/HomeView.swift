import SwiftUI
import PetCore

/// Home v3.1: a wide breakfast kitchen with the pet gang on the rug, today's auto-logged
/// check-ins and this week's 自律周 progress under them, and the main buttons at the bottom.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: HomeSheet?
    @State private var page: HomePage?

    /// Today, Pets and Share are full pages with their own back button; the rest are sheets.
    private func open(_ target: HomeSheet) {
        switch target {
        case .today: page = .today
        case .pets: page = .pets
        case .share: page = .share
        default: sheet = target
        }
    }

    var body: some View {
        ZStack {
            HomeScene(pets: model.homePets, line: model.homeLine, isAsleep: model.petState.isAsleep) {
                model.pat()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(daysTogether: model.daysTogether, pet: model.mainPet,
                       onFriends: { sheet = .friends }, onMore: { sheet = .more })
                    .padding(.horizontal, 16)

                Spacer(minLength: 0)

                VStack(spacing: 14) {
                    TodayCard(today: model.today, tracker: model.discipline)
                    WeekStrip(week: model.week, weekInBlock: model.weekInBlock)
                    Dock { open($0) }
                        .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .fullScreenCover(item: $page) { page in
            switch page {
            case .today: TodayView()
            case .pets: PetsView()
            case .share: ShareView()
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .today, .pets, .share: EmptyView() // full-screen pages, see `open`
            case .settings: SettingsView()
            case .memories: MemoriesView()
            case .more: MoreSheet(open: { self.sheet = $0 })
            case .dressUp: ComingSoonView(title: "Dress up", image: "ic_dressup",
                                          message: "Hats, bandanas and crumbs of style are on the way.")
            case .friends, .world: ComingSoonView(title: "Friends", image: "ic_friends",
                                                  message: "Soon your pets can visit your friends' kitchens.")
            }
        }
    }
}

enum HomePage: String, Identifiable {
    case today, pets, share
    var id: String { rawValue }
}

enum HomeSheet: String, Identifiable {
    case today, pets, dressUp, memories, share, friends, more, settings, world
    var id: String { rawValue }
}

// MARK: - Scene

/// Background and pets are laid out on the 402×874 design canvas and scaled by screen height,
/// the same way the background image is (aspect fill).
private struct HomeScene: View {
    let pets: [RosterPet]
    let line: String
    let isAsleep: Bool
    let onPat: () -> Void

    private static let design = CGSize(width: 402, height: 874)
    /// Where pets stand, main pet first: centre x, feet y, height. Right-hand pets face left.
    private static let slots: [Slot] = [
        Slot(x: 201, feet: 418, height: 108), Slot(x: 78, feet: 452, height: 98), Slot(x: 326, feet: 452, height: 98),
        Slot(x: 140, feet: 528, height: 98), Slot(x: 266, feet: 528, height: 98)
    ]

    private struct Slot {
        var x: CGFloat
        var feet: CGFloat
        var height: CGFloat
    }

    private struct Placement: Identifiable {
        var pet: RosterPet
        var slot: Slot
        var id: String { pet.id }
    }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.height / Self.design.height
            let shiftX = geo.size.width / 2 - Self.design.width / 2 * s
            // Back row first so pets nearer the camera are drawn on top.
            let placed = zip(pets, Self.slots).map { Placement(pet: $0, slot: $1) }.sorted { $0.slot.feet < $1.slot.feet }

            ZStack(alignment: .topLeading) {
                Image("bg_home")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                ForEach(placed) { place in
                    PetSprite(pet: place.pet, height: place.slot.height * s,
                              faceLeft: place.slot.x > Self.design.width / 2 + 20,
                              isAsleep: isAsleep, onPat: onPat)
                        .position(x: shiftX + place.slot.x * s, y: (place.slot.feet - place.slot.height / 2) * s)
                }

                SpeechBubble(text: line)
                    .frame(maxWidth: 260 * s)
                    .position(x: shiftX + Self.design.width / 2 * s, y: 284 * s)

                Palette.night.opacity(isAsleep ? 0.3 : 0)
                    .allowsHitTesting(false)
            }
            .animation(.easeInOut(duration: 1.2), value: isAsleep)
        }
    }
}

private struct PetSprite: View {
    let pet: RosterPet
    let height: CGFloat
    let faceLeft: Bool
    let isAsleep: Bool
    let onPat: () -> Void

    @State private var bob = false
    @State private var bounce = false
    @State private var hearts: [FloatingHeart] = []

    var body: some View {
        Image(pet.art)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .scaleEffect(x: faceLeft ? -1 : 1)
            .scaleEffect(y: bob ? 1.02 : 0.98, anchor: .bottom)
            .scaleEffect(bounce ? 1.12 : 1, anchor: .bottom)
            .overlay(alignment: .topTrailing) {
                if isAsleep { SleepyZ().offset(x: -height * 0.05, y: -height * 0.12) }
            }
            .overlay(alignment: .top) {
                ZStack {
                    ForEach(hearts) { heart in
                        Image("ic_heart")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22)
                            .offset(x: heart.x, y: heart.rise ? -height * 0.45 : 0)
                            .opacity(heart.rise ? 0 : 1)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: pat)
            .onAppear {
                // Each pet breathes on its own rhythm so the gang doesn't move in lockstep.
                withAnimation(.easeInOut(duration: .random(in: 1.1...1.6)).repeatForever(autoreverses: true)) { bob = true }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(pet.name)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Pat")
    }

    private func pat() {
        onPat()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { bounce = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bounce = false }
        }

        let heart = FloatingHeart(x: .random(in: -20...20))
        hearts.append(heart)
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 1.0)) {
                if let i = hearts.firstIndex(where: { $0.id == heart.id }) { hearts[i].rise = true }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            hearts.removeAll { $0.id == heart.id }
        }
    }
}

private struct FloatingHeart: Identifiable {
    let id = UUID()
    var x: CGFloat
    var rise = false
}

private struct SleepyZ: View {
    var body: some View {
        VStack(alignment: .leading, spacing: -4) {
            OutlinedText(text: "z", font: ChibiFont.title(12), outline: 1.5).offset(x: 8)
            OutlinedText(text: "z", font: ChibiFont.title(16), outline: 1.5)
        }
    }
}

private struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(ChibiFont.bold(13.5))
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .chibiPanel(Capsule(), fill: .white, shadow: 0)
            .overlay(alignment: .bottom) {
                BubbleTail()
                    .fill(.white)
                    .overlay(BubbleTail().stroke(Palette.ink, style: StrokeStyle(lineWidth: 3, lineJoin: .round)))
                    .frame(width: 16, height: 11)
                    .offset(y: 9.5)
            }
            .contentTransition(.opacity)
            .animation(.default, value: text)
    }
}

/// Downward tail; its open top edge sits on the bubble's border.
private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
    }
}

// MARK: - Top bar

private struct TopBar: View {
    let daysTogether: Int
    let pet: RosterPet
    let onFriends: () -> Void
    let onMore: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(pet.art)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)
                    .offset(x: 2, y: 8)
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
                    .padding(2)
                    .background(Circle().fill(Palette.creamDeep))
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
                VStack(alignment: .leading, spacing: -2) {
                    Text("Day \(daysTogether)")
                        .font(ChibiFont.title(19))
                        .foregroundStyle(Palette.ink)
                    Text("with \(pet.name)")
                        .font(ChibiFont.body(12))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .padding(.leading, 5)
            .padding(.trailing, 22)
            .padding(.vertical, 4)
            .chibiPanel(Capsule(), shadow: 3)

            Spacer()

            RoundButton(label: "Friends", action: onFriends) {
                Image("ic_friends").resizable().scaledToFit().frame(width: 36)
            }
            RoundButton(label: "More", action: onMore) {
                HStack(spacing: 3.5) {
                    ForEach(0..<3) { _ in Circle().fill(Palette.ink).frame(width: 6.4, height: 6.4) }
                }
            }
            .padding(.leading, 10)
        }
    }
}

private struct RoundButton<Content: View>: View {
    let label: String
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .frame(width: 48, height: 48)
                .chibiPanel(Circle(), shadow: 3)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Today card

/// What the day has logged by itself from Apple Health: sleep, workout, steps.
private struct TodayCard: View {
    let today: HealthSnapshot?
    let tracker: DisciplineTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("TODAY").font(ChibiFont.title(17)).foregroundStyle(Palette.ink)
                Text("auto-logged from Apple Health").font(ChibiFont.body(11)).foregroundStyle(Palette.inkSoft)
            }
            HStack(spacing: 4) {
                sleepTile
                workoutTile
                stepsTile
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chibiPanel(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var sleepTile: some View {
        let onTime = today.flatMap(tracker.isOnTimeNight)
        return StatTile(
            icon: "ic_sleep", iconHeight: 24,
            value: today?.sleepOnset?.formatted(date: .omitted, time: .shortened) ?? "—",
            caption: onTime == nil ? "No sleep data" : (onTime! ? "On-time sleep" : "Late night"),
            done: onTime == true
        )
    }

    private var workoutTile: some View {
        let counts = today.map(tracker.countsAsWorkout) ?? false
        let minutes = Int(today?.workoutMinutes ?? 0)
        let value: String
        let caption: String
        if minutes > 0 {
            value = "\(minutes) min"
            caption = today?.workoutType ?? "Workout"
        } else if counts {
            value = "10k+"
            caption = "Active day"
        } else {
            value = "—"
            caption = "No workout yet"
        }
        return StatTile(icon: "ic_workout", iconHeight: 22, value: value, caption: caption, done: counts)
    }

    private var stepsTile: some View {
        let steps = today?.steps ?? 0
        return StatTile(
            icon: "ic_steps", iconHeight: 16,
            value: steps.formatted(), caption: "Steps", done: false,
            progress: min(Double(steps) / Double(tracker.rules.activeDaySteps), 1)
        )
    }
}

private struct StatTile: View {
    let icon: String
    let iconHeight: CGFloat
    let value: String
    let caption: String
    let done: Bool
    var progress: Double?

    var body: some View {
        HStack(spacing: 6) {
            Image(icon).resizable().scaledToFit().frame(width: 30, height: iconHeight)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(ChibiFont.title(16))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(caption)
                    .font(ChibiFont.body(10.5))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let progress {
                    ProgressPill(value: progress).padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.creamDeep))
        .overlay(alignment: .topTrailing) {
            if done { CheckBadge().offset(x: -4, y: 4) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : "")
    }
}

private struct ProgressPill: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.empty)
                Capsule().fill(Palette.mint).frame(width: geo.size.width * value)
            }
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 1.2))
        }
        .frame(height: 6)
    }
}

private struct CheckBadge: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 7.5, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 15, height: 15)
            .background(Circle().fill(Palette.mintDeep))
            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
    }
}

// MARK: - Week strip

/// This week's 自律周: workouts out of 3 and on-time nights out of 5.
private struct WeekStrip: View {
    let week: WeekProgress?
    let weekInBlock: Int

    var body: some View {
        let rules = week?.rules ?? .standard
        HStack(spacing: 8) {
            Image("ic_trophy").resizable().scaledToFit().frame(height: 36)
            Text("Week \(weekInBlock)/\(rules.weeksPerBlock)")
                .font(ChibiFont.title(15))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Segments(label: "Workouts", total: rules.workoutsPerWeek, done: week?.workouts ?? 0, color: Palette.coral)
            Segments(label: "Nights", total: rules.onTimeNightsPerWeek, done: week?.onTimeNights ?? 0, color: Palette.lavender)
                .padding(.leading, 6)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(height: 44)
        .chibiPanel(Capsule(), shadow: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Week \(weekInBlock) of \(rules.weeksPerBlock). Workouts \(min(week?.workouts ?? 0, rules.workoutsPerWeek)) of \(rules.workoutsPerWeek), on-time nights \(min(week?.onTimeNights ?? 0, rules.onTimeNightsPerWeek)) of \(rules.onTimeNightsPerWeek).")
    }
}

private struct Segments: View {
    let label: String
    let total: Int
    let done: Int
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label).font(ChibiFont.bold(11)).foregroundStyle(Palette.inkSoft).fixedSize().padding(.trailing, 2)
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(i < done ? color : Palette.empty)
                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Palette.ink, lineWidth: 1.6))
                    .frame(width: 9, height: 12)
            }
        }
    }
}

// MARK: - Dock

private struct Dock: View {
    let open: (HomeSheet) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            DockButton(image: "ic_pets", title: "Pets") { open(.pets) }
            DockButton(image: "ic_dressup", title: "Dress up") { open(.dressUp) }
            DockButton(image: "ic_today", title: "Today", primary: true) { open(.today) }
            DockButton(image: "ic_memories", title: "Memories") { open(.memories) }
            DockButton(image: "ic_share", title: "Share") { open(.share) }
        }
    }
}

private struct DockButton: View {
    let image: String
    let title: String
    var primary = false
    let action: () -> Void

    var body: some View {
        let size: CGFloat = primary ? 82 : 62
        Button(action: action) {
            VStack(spacing: 4) {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: size * (primary ? 0.86 : 0.84))
                    .offset(y: -3)
                    .frame(width: size, height: size)
                    .chibiPanel(RoundedRectangle(cornerRadius: primary ? 22 : 18, style: .continuous),
                                fill: primary ? Palette.butter : Palette.cream, shadow: 5)
                OutlinedText(text: title, font: ChibiFont.title(primary ? 15 : 13.5))
                    .fixedSize()
                    .padding(.top, 4)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview {
    HomeView().environment(AppModel())
}
