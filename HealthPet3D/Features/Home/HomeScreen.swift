import SwiftUI
import PetCore

/// Home (v3.1): pet name, the week, the living pet on its flat oval with today's food bubbles
/// around it, three rest bars, and the dock (Pets · Today · Memories).
struct HomeScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home
    @Environment(Router.self) private var router
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var stage = PetStageController()
    @State private var line: String?
    @State private var lineTask: Task<Void, Never>?
    /// Bubbles on their way to the pet's mouth: id → 0...1 along the arc.
    @State private var flights: [String: CGFloat] = [:]
    @State private var bites = 0
    @State private var onScreen = false

    var body: some View {
        let pet = model.mainPet3D
        VStack(spacing: 0) {
            topBar(pet)
                .padding(.horizontal, 24)
                .padding(.top, 6)
            WeekStrip(days: model.weekStrip)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 18)
            GeometryReader { geo in
                scene(pet: pet, size: geo.size)
            }
            StatusBars(rows: model.statusRows)
                .padding(.horizontal, 44)
            dock
                .padding(.top, 26)
                .padding(.bottom, 6)
        }
        .background(Jade.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .light), trigger: bites)
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "hp3dRegrow") { home.regrowFood() }
            #endif
            onScreen = true
            stage.pause(false)
            greet()
        }
        .onDisappear {
            onScreen = false
            stage.pause(true)
        }
        .onChange(of: scenePhase) { _, phase in
            stage.pause(phase != .active || !onScreen)
            if phase == .active { greet() }
        }
        .onChange(of: stage.isReady) { greet() }
        .onChange(of: model.today) { greet() }
        .onChange(of: stage.tapCount) {
            say(stage.lastTapMode == "awake" ? model.petLine() : "Mm… so sleepy.")
        }
    }

    // MARK: - Top: name (switch the main pet) and more

    private func topBar(_ pet: Pet3D) -> some View {
        HStack {
            Menu {
                Picker("Main pet", selection: Binding(get: { model.mainPetID }, set: { model.mainPetID = $0 })) {
                    ForEach(model.unlockedPets) { p in
                        Text(p.name).tag(p.rosterID)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(pet.name)
                        .font(.rounded(28, .bold))
                        .foregroundStyle(Jade.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Jade.ink3)
                }
            }
            .accessibilityLabel("Main pet: \(pet.name)")
            Spacer()
            Menu {
                Button {} label: { Label("Friends · Coming soon", systemImage: "person.2") }
                    .disabled(true)
                Button { router.path.append(.settings) } label: { Label("Settings", systemImage: "gearshape") }
            } label: {
                RoundIcon(systemName: "ellipsis")
            }
            .accessibilityLabel("More")
        }
    }

    // MARK: - The stage: pet, rug, food bubbles, a short line

    @ViewBuilder
    private func scene(pet: Pet3D, size: CGSize) -> some View {
        if size.width > 1, size.height > 1 {
            let layout = HomeLayout(size: size, anchors: stage.anchors ?? .standard)
            let bubbles = model.foodBubbles { home.eatenValue($0) }
            ZStack(alignment: .topLeading) {
                PetStageView(controller: stage, config: stageConfig(pet: pet, box: layout.box))
                    .frame(width: size.width, height: size.height)
                    .accessibilityLabel("\(pet.name). Tap, tap again, or hold.")

                if let line {
                    SpeechBubble(text: line)
                        .frame(maxWidth: size.width * 0.7)
                        .position(x: size.width / 2, y: max(26, layout.headTop - 34))
                        .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                        .allowsHitTesting(false)
                }

                ForEach(Array(bubbles.enumerated()), id: \.element.id) { index, bubble in
                    let from = layout.slot(bubble.slot)
                    Button { harvest(bubble, all: bubbles, from: from, to: layout.mouth, lift: size.width * 0.16) } label: {
                        FoodBubbleView(bubble: bubble, index: index)
                    }
                    .buttonStyle(.plain)
                    .disabled(flights[bubble.id] != nil)
                    .modifier(FlyEffect(progress: flights[bubble.id] ?? 0, from: from, to: layout.mouth, lift: size.width * 0.16))
                    .position(from)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .accessibilityLabel("Feed \(bubble.spoken)")
                }
            }
            .animation(.spring(duration: 0.45, bounce: 0.35), value: bubbles.map(\.id))
            #if DEBUG
            .task(id: stage.isReady) {
                // For screenshots on the simulator: -hp3dFeed all (or a bubble id prefix such as steps)
                guard stage.isReady, let which = UserDefaults.standard.string(forKey: "hp3dFeed") else { return }
                try? await Task.sleep(for: .seconds(9))
                for bubble in model.foodBubbles(eaten: { home.eatenValue($0) }) where which == "all" || bubble.id.hasPrefix(which) {
                    harvest(bubble, all: bubbles, from: layout.slot(bubble.slot), to: layout.mouth, lift: size.width * 0.16)
                    try? await Task.sleep(for: .seconds(0.9))
                }
            }
            #endif
        }
    }

    private func stageConfig(pet: Pet3D, box: PetStageConfig.Box) -> PetStageConfig {
        PetStageConfig(pet: pet.id, rug: true, dark: scheme == .dark,
                       bedtime: model.petState.isAsleep, mood: model.stageMood, box: box)
    }

    private func harvest(_ bubble: FoodBubble, all: [FoodBubble], from: CGPoint, to: CGPoint, lift: CGFloat) {
        guard flights[bubble.id] == nil else { return }
        stage.activity()
        flights[bubble.id] = 0
        withAnimation(.easeInOut(duration: 0.62)) {
            flights[bubble.id] = 1
        } completion: {
            stage.eat()
            bites += 1
            var noAnimation = Transaction()
            noAnimation.disablesAnimations = true
            withTransaction(noAnimation) {
                home.eat(bubble.id, value: bubble.value)
                flights[bubble.id] = nil
            }
            // the last one eaten: a happy hop
            if model.foodBubbles(eaten: { home.eatenValue($0) }).isEmpty {
                Task {
                    try? await Task.sleep(for: .seconds(1.3))
                    stage.celebrate("hop")
                }
            }
        }
    }

    // MARK: - Greeting: wake-up once a day, cheers for new check-ins

    private func greet() {
        guard stage.isReady, onScreen, scenePhase == .active, !model.petState.isAsleep else { return }
        var delay = 0.0
        if home.takeMorning() {
            stage.morning()
            delay = 5.2
        }
        if model.today != nil, home.takeCelebration(checkIns: model.checkInsToday) {
            stage.celebrate("cheer")
            let text = model.petLine(afterCheckIn: true)
            Task {
                try? await Task.sleep(for: .seconds(delay + 0.4))
                say(text)
            }
        }
    }

    private func say(_ text: String) {
        lineTask?.cancel()
        withAnimation(.spring(duration: 0.3)) { line = text }
        lineTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { line = nil }
        }
    }

    // MARK: - Dock

    private var dock: some View {
        HStack(spacing: 40) {
            NavigationLink(value: Route.pets) {
                RoundSurface(size: 50) { PetFaceIcon(size: 24) }
                    .overlay(alignment: .topTrailing) {
                        if home.hasUnseen(model.unlockedPets) {
                            Circle().fill(Jade.accent).frame(width: 7, height: 7).offset(x: 2, y: -2)
                        }
                    }
            }
            .accessibilityLabel("Pets")
            NavigationLink(value: Route.today) {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Jade.onPrimary)
                    .frame(width: 66, height: 66)
                    .background(Circle().fill(Jade.primary))
                    .softShadow(2.2)
            }
            .accessibilityLabel("Today")
            NavigationLink(value: Route.memories) {
                RoundSurface(size: 50) {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Jade.ink)
                }
            }
            .accessibilityLabel("Memories")
        }
        .buttonStyle(.plain)
    }
}

/// Where things sit on the home stage, in the stage area's own points (the v3.1 mock is 402 wide).
struct HomeLayout {
    let size: CGSize
    let anchors: PetAnchors

    /// The pet's 100 × 100 box: about 63% of the width, feet at 87% of the height.
    var stageSide: CGFloat { min(size.width * 0.63, size.height * 0.62) }

    var stageRect: CGRect {
        let side = stageSide
        let feet = size.height * 0.87
        return CGRect(x: (size.width - side) / 2, y: feet - side * anchors.bottom / 100, width: side, height: side)
    }

    var box: PetStageConfig.Box {
        let rect = stageRect
        return .init(x: Double(rect.minX / size.width), y: Double(rect.minY / size.height), size: Double(stageSide / size.width))
    }

    var mouth: CGPoint {
        let rect = stageRect
        return CGPoint(x: rect.minX + anchors.mouth.x * rect.width, y: rect.minY + anchors.mouth.y * rect.height)
    }

    var headTop: CGFloat { stageRect.minY + anchors.top / 100 * stageSide }

    /// Food bubble places: steps, energy, workout, load, a second workout.
    static let slots: [CGPoint] = [
        CGPoint(x: 0.219, y: 0.2), CGPoint(x: 0.781, y: 0.2),
        CGPoint(x: 0.147, y: 0.6), CGPoint(x: 0.853, y: 0.6),
        CGPoint(x: 0.5, y: 0.07),
    ]

    func slot(_ index: Int) -> CGPoint {
        let p = Self.slots[min(index, Self.slots.count - 1)]
        return CGPoint(x: p.x * size.width, y: p.y * size.height)
    }
}

/// A food bubble flying into the pet's mouth: up a little, then down, shrinking as it goes.
struct FlyEffect: GeometryEffect {
    var progress: CGFloat
    let from: CGPoint
    let to: CGPoint
    let lift: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard progress > 0 else { return ProjectionTransform() }
        let t = progress, u = 1 - t
        let control = CGPoint(x: (from.x + to.x) / 2, y: min(from.y, to.y) - lift)
        let x = u * u * from.x + 2 * u * t * control.x + t * t * to.x
        let y = u * u * from.y + 2 * u * t * control.y + t * t * to.y
        let scale = 1 - 0.78 * t
        let transform = CGAffineTransform(translationX: x - from.x + size.width / 2, y: y - from.y + size.height / 2)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(transform)
    }
}

struct FoodBubbleView: View {
    let bubble: FoodBubble
    let index: Int
    @State private var up = false

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: bubble.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Jade.onAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Jade.accent))
            Text(bubble.label)
                .font(.rounded(13, .bold))
                .foregroundStyle(Jade.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 66, height: 66)
        .background(Circle().fill(Jade.card))
        .softShadow(1.3)
        .offset(y: up ? -3 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true).delay(Double(index) * 0.45)) {
                up = true
            }
        }
        .contentShape(Circle())
    }
}

struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.rounded(14, .semibold))
            .foregroundStyle(Jade.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Jade.card))
            .softShadow(1)
    }
}

struct WeekStrip: View {
    let days: [WeekDay]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(day.letter)
                        .font(.rounded(11, .semibold))
                        .foregroundStyle(Jade.ink3)
                    Text("\(day.number)")
                        .font(.rounded(17, .bold))
                        .foregroundStyle(day.isToday ? Jade.onAccent : day.isFuture ? Jade.ink3 : Jade.ink)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(day.isToday ? Jade.accent : Color.clear))
                    marks(day)
                        .frame(height: 6)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label(day))
            }
        }
    }

    @ViewBuilder
    private func marks(_ day: WeekDay) -> some View {
        if day.rest {
            Capsule().fill(Jade.ink3.opacity(0.7)).frame(width: 8, height: 2)
        } else {
            HStack(spacing: 3) {
                if day.workout { Circle().fill(Jade.accent).frame(width: 5, height: 5) }
                if day.night { Circle().fill(Jade.sleep).frame(width: 5, height: 5) }
            }
        }
    }

    private func label(_ day: WeekDay) -> String {
        var parts = [day.id.formatted(.dateTime.weekday(.wide).day())]
        if day.workout { parts.append("workout") }
        if day.night { parts.append("on-time night") }
        if day.rest { parts.append("rest") }
        return parts.joined(separator: ", ")
    }
}

struct StatusBars: View {
    let rows: [StatusRow]

    var body: some View {
        VStack(spacing: 15) {
            ForEach(rows) { row in
                HStack(spacing: 14) {
                    Image(systemName: row.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Jade.ink2)
                        .frame(width: 22)
                    Track(fraction: row.fill, color: Jade.sleep)
                    Text(row.label)
                        .font(.rounded(13, .bold))
                        .foregroundStyle(Jade.ink)
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(row.name) \(row.label)")
            }
        }
    }
}
