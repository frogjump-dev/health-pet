import SwiftUI
import PetCore

/// Home (v3.4): pet name, the week (Monday first, run / moon icons), the living pet on its flat
/// oval with today's food bubbles around it (B 轻泡), the status area (Asleep, Rest) and this
/// week's cells, and the dock (Pets · Today · Memories, with their names).
/// A tap on a bubble books it (点击 = 入账, PRD v0.2 §4.4); rows and days explain themselves with
/// a tap; the first time, the pet shows the user around.
struct HomeScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home
    @Environment(Router.self) private var router
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase

    private var stage: PetStage { PetStage.shared }
    @State private var line: String?
    @State private var lineTask: Task<Void, Never>?
    @State private var momentsTask: Task<Void, Never>?
    @State private var bites = 0
    @State private var onScreen = false
    /// The 自律周 share card, offered the moment the week counts.
    @State private var weekCard = false
    /// During the wake-up the bubbles wait, then grow.
    @State private var foodHidden = false

    // feeding
    /// Bubbles popping right now (the model already booked them).
    @State private var eating: [String: FoodBubble] = [:]
    @State private var feeds: [Feed] = []
    @State private var inFlight = 0
    /// What the rows showed before a booking, kept until its dot lands.
    @State private var held: Shown?
    @State private var workoutPulses: [Int: Int] = [:]
    @State private var nightPulses: [Int: Int] = [:]
    @State private var memoriesPulse = 0
    /// Named places on screen (cells, rows, dock…), in home coordinates.
    @State private var spots: [String: CGRect] = [:]

    // explaining
    @State private var note: Note?
    @State private var selectedDay: Date?
    @State private var tour: TourStep?
    @State private var tourTask: Task<Void, Never>?

    private enum Note: Hashable { case asleep, rest, week }

    /// The status area, this week's cells and the calendar row, as shown.
    private struct Shown {
        var status: HomeStatus
        var cells: WeekCells
        var days: [WeekDay]
    }

    var body: some View {
        let pet = model.mainPet3D
        let shown = held ?? Shown(status: model.homeStatus, cells: model.weekCells, days: model.weekStrip)
        VStack(spacing: 0) {
            topBar(pet)
                .padding(.horizontal, 24)
                .padding(.top, 6)
            WeekStrip(days: shown.days, selected: $selectedDay) { day in
                tour == nil ? model.dayNote(day) : nil
            }
            .padding(.horizontal, Metrics.gutter - 4)
            .padding(.top, 10)
            GeometryReader { geo in
                scene(pet: pet, size: geo.size)
            }
            .background(HomeSpot.mark("scene"))
            statusArea(shown)
                .padding(.horizontal, 44)
                .background(HomeSpot.mark("status"))
            dock
                .padding(.top, 26)
                .padding(.bottom, 2)
                .background(HomeSpot.mark("dock"))
        }
        .coordinateSpace(name: HomeSpot.space)
        .onPreferenceChange(HomeSpot.Key.self) { spots = $0 }
        .overlay { FeedLayer(feeds: feeds) }
        .overlay { tourOverlay }
        .background(Jade.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .light), trigger: bites)
        .sheet(isPresented: $weekCard) { WeekAchievedSheet() }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "hp3dRegrow") { model.regrowFood() }
            if UserDefaults.standard.bool(forKey: "hp3dWeekCard") { weekCard = true }
            #endif
            onScreen = true
            greet()
        }
        .onDisappear {
            onScreen = false
            if tour == .tryIt { tour = nil }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { greet() }
        }
        .onChange(of: stage.isReady) { greet() }
        .onChange(of: model.today) { greet() }
        .onChange(of: home.onboarded) { greet() }
        .onChange(of: stage.tapCount) {
            guard onScreen else { return }
            say(stage.lastTapMode == "awake" ? model.petLine() : "Mm… so sleepy.")
        }
        #if DEBUG
        .task(id: stage.isReady) { await debugLaunch() }
        #endif
    }

    /// The pet's slow condition: from the data, or the test build's override.
    private var energy: PetEnergy { home.energyOverride ?? model.energy }

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
            // No feature, no entry (PRD v0.2): Settings, and the tour again (v3.4).
            Menu {
                Button { router.path.append(.settings) } label: { Label("Settings", systemImage: "gearshape") }
                Button { startTour() } label: { Label("Show me around", systemImage: "hand.tap") }
            } label: {
                RoundIcon(systemName: "ellipsis")
            }
            .opacity(tour == nil || tour == .tryIt ? 1 : 0)
            .background(HomeSpot.mark("more"))
            .accessibilityLabel("More")
        }
    }

    // MARK: - The stage: pet, flat oval, food bubbles, a short line

    @ViewBuilder
    private func scene(pet: Pet3D, size: CGSize) -> some View {
        if size.width > 1, size.height > 1 {
            let layout = HomeLayout(size: size, anchors: stage.anchors(for: pet.id) ?? .standard)
            let waiting = foodHidden ? [] : model.foodBubbles.filter { eating[$0.id] == nil }
            let bubbles = waiting + eating.values.sorted { $0.slot < $1.slot }
            ZStack(alignment: .topLeading) {
                LivePet(config: stageConfig(pet: pet, box: layout.box))
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
                    Button { harvest(bubble, layout: layout) } label: {
                        FoodBubbleView(bubble: bubble, phase: index, eaten: eating[bubble.id] != nil)
                    }
                    .buttonStyle(BubblePress())
                    .disabled(eating[bubble.id] != nil || (tour != nil && tour != .tryIt))
                    .position(layout.slot(bubble.slot))
                    .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity), removal: .identity))
                    .accessibilityLabel("Feed \(bubble.spoken)")
                    .accessibilityHint("Books it into this week")
                }

                if tour == .tryIt, let target = tryItBubble(waiting) {
                    let center = layout.slot(target.slot)
                    TryItHint(center: center, petName: pet.name, labelOnLeft: center.x > size.width / 2)
                }
            }
            .animation(.spring(duration: 0.45, bounce: 0.35), value: bubbles.map(\.id))
        }
    }

    private func stageConfig(pet: Pet3D, box: PetStageConfig.Box) -> PetStageConfig {
        PetStageConfig(pet: pet.id, rug: true, dark: scheme == .dark, bedtime: model.petState.isAsleep,
                       mood: model.stageMood, energy: energy.rawValue, box: box)
    }

    private func bubbleColor(_ kind: FoodBubble.Kind) -> Color {
        switch kind {
        case .workout, .steps: Jade.accent
        case .moon: Jade.sleep
        case .load: Jade.load
        }
    }

    // MARK: - Feeding: 点击 = 入账

    /// The bubble is booked at once (experience, this week, the ledger); the screen then plays it:
    /// jelly → pop → crumbs into the mouth → swallow → the tag and the dot into this week's cell.
    private func harvest(_ bubble: FoodBubble, layout: HomeLayout) {
        guard eating[bubble.id] == nil, let scene = spots["scene"] else { return }
        let at = layout.slot(bubble.slot)
        if held == nil { held = Shown(status: model.homeStatus, cells: model.weekCells, days: model.weekStrip) }
        let before = model.weekCells
        let feedback = model.book(bubble.credit)
        let after = model.weekCells
        eating[bubble.id] = bubble
        if tour == .tryIt { tour = nil }
        note = nil
        selectedDay = nil

        stage.feed(at: CGPoint(x: at.x / layout.size.width, y: at.y / layout.size.height), then: feedback.expression)

        let landing = landingSpot(feedback, before: before, after: after)
        let origin = scene.origin
        func onHome(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + origin.x, y: p.y + origin.y) }
        let target = spots[landing.spot].map { CGPoint(x: $0.midX, y: $0.midY) }
            ?? CGPoint(x: scene.midX, y: scene.maxY + 60)
        let feed = Feed(id: "\(bubble.id)@\(Date().timeIntervalSince1970)", start: .now, from: onHome(at),
                        mouth: onHome(layout.mouth), feet: onHome(layout.feet), target: target,
                        color: bubbleColor(bubble.kind), tag: feedback.tag,
                        tagAt: onHome(CGPoint(x: layout.size.width / 2, y: layout.headTop - 26)))
        feeds.append(feed)
        inFlight += 1

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.34))
            var quiet = Transaction()
            quiet.disablesAnimations = true
            withTransaction(quiet) { eating[bubble.id] = nil }
            try? await Task.sleep(for: .seconds(Feed.swallowAt - 0.34))
            bites += 1
            try? await Task.sleep(for: .seconds(Feed.landsAt - Feed.swallowAt))
            land(landing)
            try? await Task.sleep(for: .seconds(Feed.endsAt - Feed.landsAt))
            feeds.removeAll { $0.id == feed.id }
            // a new pet, a level, a 自律周: the moments after the meal
            if inFlight == 0 { greet() }
        }
    }

    private struct Landing {
        var spot: String
        /// The cell fills now (bump after its 0.4 s fill); false = it was lit already, it only bumps.
        var fills: Bool
    }

    private func landingSpot(_ feedback: BookingFeedback, before: WeekCells, after: WeekCells) -> Landing {
        switch feedback.target {
        case .workouts:
            if after.workouts > before.workouts { return Landing(spot: "w\(before.workouts)", fills: true) }
            return Landing(spot: "w\(max(0, after.workouts - 1))", fills: false)
        case .nights:
            if let index = after.nights.indices.first(where: { after.nights[$0] != before.nights[$0] }) {
                return Landing(spot: "n\(index)", fills: true)
            }
            return Landing(spot: "n\(max(0, after.filledNights - 1))", fills: false)
        case .memories:
            return Landing(spot: "memories", fills: false)
        }
    }

    /// The dot is in: the held rows let go (the cell fills, the moon's check lights, today's
    /// calendar icon appears), and whatever it landed on bumps.
    private func land(_ landing: Landing) {
        inFlight -= 1
        if inFlight == 0 {
            withAnimation(.easeOut(duration: 0.4)) { held = nil }
        }
        let index = Int(landing.spot.dropFirst()) ?? 0
        let bump = {
            if landing.spot == "memories" { memoriesPulse += 1 }
            else if landing.spot.hasPrefix("w") { workoutPulses[index, default: 0] += 1 }
            else { nightPulses[index, default: 0] += 1 }
        }
        if landing.fills && inFlight == 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                bump()
            }
        } else {
            bump()
        }
        // the day's last bubble eaten: a happy hop
        if inFlight == 0, model.foodBubbles.isEmpty {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.4 - (Feed.landsAt - Feed.swallowAt)))
                stage.celebrate("hop")
            }
        }
    }

    // MARK: - Status area and this week

    private func statusArea(_ shown: Shown) -> some View {
        VStack(spacing: 16) {
            AsleepRow(status: shown.status)
                .noteHighlight(note == .asleep)
                .onTapGesture { open(.asleep) }
                .infoNote(isPresented: noteShown(.asleep)) { asleepNote }
            RestRow(status: shown.status)
                .noteHighlight(note == .rest)
                .onTapGesture { open(.rest) }
                .infoNote(isPresented: noteShown(.rest)) { restNote }
            WeekRow(cells: shown.cells, workoutPulses: workoutPulses, nightPulses: nightPulses)
                .noteHighlight(note == .week)
                .onTapGesture { open(.week) }
                .infoNote(isPresented: noteShown(.week)) {
                    WeekNote(cells: model.weekCells, bedtime: SleepSchedule.clock(model.sleepSchedule.bedtimeMinutes))
                }
        }
    }

    private func open(_ which: Note) {
        guard tour == nil || tour == .tryIt else { return }
        note = which
    }

    private func noteShown(_ which: Note) -> Binding<Bool> {
        Binding(get: { note == which }, set: { if !$0, note == which { note = nil } })
    }

    private var asleepNote: some View {
        let target = SleepSchedule.clock(model.sleepSchedule.targets(nightEnding: Date()).bed)
        let onset = model.homeStatus.onset
        return InfoNote(onset.map { "Asleep \($0)" } ?? "Asleep",
                        "When your watch saw you fall asleep. Your target is \(target); within 30 minutes counts as on time and lights the ✓.")
    }

    private var restNote: some View {
        model.restIsWhoop
            ? InfoNote("Recovery · WHOOP", "Your Whoop recovery for today. Just a bar here; the number is in Today.")
            : InfoNote("Rest", "How recovered you are, from last night’s sleep and heart rate, against your own last 30 days. Just a bar, no score.")
    }

    // MARK: - The tour (v3.4)

    private func startTour() {
        tourTask?.cancel()
        note = nil
        selectedDay = nil
        home.tourDone = false
        withAnimation(.easeOut(duration: 0.25)) { tour = .bubbles }
    }

    private func nextTourStep() {
        guard let step = tour else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            switch step {
            case .bubbles: tour = .records
            case .records: tour = .dock
            case .dock, .tryIt:
                home.tourDone = true
                // the last step needs a bubble; with none today it ends here
                tour = tryItBubble(model.foodBubbles) == nil ? nil : .tryIt
            }
        }
    }

    private func endTour() {
        home.tourDone = true
        withAnimation(.easeOut(duration: 0.25)) { tour = nil }
    }

    private func tryItBubble(_ bubbles: [FoodBubble]) -> FoodBubble? {
        bubbles.first { $0.kind == .workout } ?? bubbles.first
    }

    @ViewBuilder
    private var tourOverlay: some View {
        if let tour, tour != .tryIt, let hole = tourHole(tour) {
            TourOverlay(step: tour, hole: hole, captionBelow: tour == .bubbles, skipAt: spots["more"],
                        petName: model.mainPet3D.name, next: nextTourStep, skip: endTour)
        }
    }

    /// The lit place of each step, in home coordinates.
    private func tourHole(_ step: TourStep) -> CGRect? {
        switch step {
        case .bubbles:
            guard let scene = spots["scene"] else { return nil }
            // from just above the highest bubble down to the pet's floor
            let highest = model.foodBubbles.map { HomeLayout.slots[min($0.slot, HomeLayout.slots.count - 1)].y }.min() ?? 0.226
            let top = scene.minY + max(0, highest * scene.height - 40)
            return CGRect(x: scene.minX + 26, y: top, width: scene.width - 52, height: scene.maxY - top + 4)
        case .records:
            return spots["status"]?.insetBy(dx: 18, dy: -14)
        case .dock:
            guard let dock = spots["dock"], let scene = spots["scene"] else { return nil }
            return CGRect(x: scene.minX - 8, y: dock.minY - 10, width: scene.width + 16, height: dock.height + 16)
        case .tryIt:
            return nil
        }
    }

    // MARK: - Moments: the morning, new pets, a 自律周, the tour

    /// One expression (nil = only words) with the line the pet says as it starts.
    private struct Moment {
        let expression: String?
        let line: String?
    }

    /// How long each moment holds the stage (the expressions' lengths in engine.js).
    private static let lengths: [String: Double] = [
        "proud": 3.2, "hop": 2.76, "cheer": 3.4, "starry": 2.8, "love": 3.0, "cheerup": 3.8, "confused": 3.2,
    ]

    private func greet() {
        guard home.onboarded, stage.isReady, onScreen, scenePhase == .active, inFlight == 0 else { return }

        // The first time after the first open: the wake-up, then the pet shows the user around.
        if !home.tourDone {
            guard tour == nil, tourTask == nil else { return }
            let morning = home.takeMorning()
            if morning { wakeUp() }
            tourTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(morning ? 5.8 : 0.8))
                tourTask = nil
                guard !Task.isCancelled, onScreen, !home.tourDone else { return }
                startTour()
            }
            return
        }
        guard !model.petState.isAsleep else { return }

        var moments: [Moment] = []
        var start = 0.0

        // 醒来, then a word about last night (早上揭晓): an on-time night is said (its proud look
        // comes with the moon bubble), a level-up collected overnight hops, a cheer-up after a
        // lapse. Never sad.
        let morning = home.takeMorning()
        if morning {
            wakeUp()
            start = 5.2
            if let reveal = model.morningReveal(levelUps: home.takeLevelUps(model.petLevels)) {
                moments.append(Moment(expression: reveal.expression, line: reveal.line))
            } else if home.daysAway >= 2 || model.cameBackAfterLapse {
                moments.append(Moment(expression: "cheerup", line: "New day. Let's go again!"))
            }
            if let days = model.anniversaryToday {
                moments.append(Moment(expression: "love", line: "\(days) days together!"))
            }
        }

        if model.dataMissing, home.takeOnceToday("confused") {
            moments.append(Moment(expression: "confused", line: "No news from your watch yet."))
        }

        let newPets = home.takeNewPets(model.unlockedPets)
        if let first = newPets.first {
            moments.append(Moment(expression: "starry", line: newPets.count == 1 ? "\(first.name) joined you!" : "\(newPets.count) new pets!"))
        }

        let weekDone = model.week.map { $0.isDisciplined && home.takeWeekCelebration(weekStart: $0.weekStart) } ?? false
        if weekDone {
            moments.append(Moment(expression: "cheer", line: "Disciplined week ✓"))
            if model.disciplinedWeekTotal == 1 {
                moments.append(Moment(expression: "love", line: "Our first disciplined week!"))
            }
        }

        if !morning, moments.isEmpty, model.almostWorkout, home.takeOnceToday("almost") {
            moments.append(Moment(expression: "cheerup", line: "Almost 10k steps!"))
        }
        // no bubbles: never a blank stage, one line a day
        if moments.isEmpty, model.today != nil, model.foodBubbles.isEmpty, home.takeOnceToday("nothingToEat") {
            moments.append(Moment(expression: nil, line: "Nothing to eat yet. A walk or a workout grows a snack here."))
        }

        guard !moments.isEmpty else { return }
        // queued in the page: each plays to the end, in order, after 醒来
        moments.compactMap(\.expression).forEach { stage.celebrate($0) }
        momentsTask?.cancel()
        momentsTask = Task {
            try? await Task.sleep(for: .seconds(start + 0.4))
            for moment in moments {
                guard !Task.isCancelled else { return }
                if let text = moment.line { say(text) }
                try? await Task.sleep(for: .seconds(moment.expression.flatMap { Self.lengths[$0] } ?? 3))
            }
            // the card slides up once the celebration is over
            if weekDone, !Task.isCancelled, onScreen { weekCard = true }
        }
    }

    /// 醒来: the bubbles wait for the pet to wake up, then grow one by one.
    private func wakeUp() {
        stage.morning()
        foodHidden = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5.3))
            withAnimation(.spring(duration: 0.45, bounce: 0.35)) { foodHidden = false }
        }
    }

    private func say(_ text: String) {
        lineTask?.cancel()
        withAnimation(.spring(duration: 0.3)) { line = text }
        lineTask = Task {
            try? await Task.sleep(for: .seconds(text.count > 40 ? 4.5 : 3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { line = nil }
        }
    }

    // MARK: - Dock: three icons with their names (v3.4)

    private var dock: some View {
        HStack(alignment: .bottom, spacing: 34) {
            NavigationLink(value: Route.pets) {
                DockItem(name: "Pets") {
                    RoundSurface(size: 50) { PetFaceIcon(size: 24) }
                        .overlay(alignment: .topTrailing) {
                            if home.hasUnseen(model.unlockedPets) {
                                Circle().fill(Jade.accent).frame(width: 7, height: 7).offset(x: 2, y: -2)
                            }
                        }
                }
            }
            NavigationLink(value: Route.today) {
                DockItem(name: "Today", strong: true) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Jade.onPrimary)
                        .frame(width: 66, height: 66)
                        .background(Circle().fill(Jade.primary))
                        .softShadow(2.2)
                }
            }
            NavigationLink(value: Route.memories) {
                DockItem(name: "Memories") {
                    RoundSurface(size: 50) {
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Jade.ink)
                    }
                    .pulse(memoriesPulse, amount: 1.14)
                    .background(HomeSpot.mark("memories"))
                }
            }
        }
        .buttonStyle(.plain)
    }

    #if DEBUG
    /// For screenshots on the simulator, once the pet is ready:
    /// -hp3dFeed all (or a bubble kind: workout, steps, night, load) eats the bubbles one by one;
    /// -hp3dTour 1|2|3|tryit shows that tour step; -hp3dNote asleep|rest|week|day opens that note.
    private func debugLaunch() async {
        guard stage.isReady else { return }
        let defaults = UserDefaults.standard
        if let step = defaults.string(forKey: "hp3dTour") {
            try? await Task.sleep(for: .seconds(1.5))
            tourTask?.cancel()
            tour = step == "tryit" ? TourStep.tryIt : TourStep(rawValue: Int(step) ?? 1)
        }
        if let which = defaults.string(forKey: "hp3dNote") {
            try? await Task.sleep(for: .seconds(3))
            switch which {
            case "asleep": note = .asleep
            case "rest": note = .rest
            case "week": note = .week
            default: selectedDay = model.weekStrip.first { model.dayNote($0) != nil }?.id
            }
        }
        if let which = defaults.string(forKey: "hp3dFeed") {
            try? await Task.sleep(for: .seconds(9))
            guard let scene = spots["scene"] else { return }
            let layout = HomeLayout(size: scene.size, anchors: stage.anchors(for: model.mainPet3D.id) ?? .standard)
            for bubble in model.foodBubbles where which == "all" || bubble.credit.kind.rawValue == which {
                harvest(bubble, layout: layout)
                try? await Task.sleep(for: .seconds(2.2))
            }
        }
    }
    #endif
}

/// A dock button and its name underneath (11 pt, grey; Today's a shade darker).
private struct DockItem<Icon: View>: View {
    let name: String
    var strong = false
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        VStack(spacing: 6) {
            icon()
            Text(name)
                .font(.rounded(11, .heavy))
                .foregroundStyle(strong ? Jade.ink2 : Jade.ink3)
        }
        .frame(minWidth: 66)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
    }
}

/// Where things sit on the home stage, in the stage area's own points (the mocks are 402 wide).
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

    /// Just above the floor under the pet: where the booking dot sets off.
    var feet: CGPoint {
        CGPoint(x: size.width / 2, y: stageRect.minY + anchors.bottom / 100 * stageSide - 4)
    }

    var headTop: CGFloat { stageRect.minY + anchors.top / 100 * stageSide }

    /// Food bubble places (v3.3 mock): the moon top left, a workout top right, the 10k day middle
    /// left, a second workout middle right, Whoop strain top centre.
    static let slots: [CGPoint] = [
        CGPoint(x: 0.229, y: 0.226), CGPoint(x: 0.776, y: 0.226),
        CGPoint(x: 0.154, y: 0.607), CGPoint(x: 0.846, y: 0.607),
        CGPoint(x: 0.5, y: 0.1),
    ]

    func slot(_ index: Int) -> CGPoint {
        let p = Self.slots[min(index, Self.slots.count - 1)]
        return CGPoint(x: p.x * size.width, y: p.y * size.height)
    }
}

/// B 轻泡 (decided 2026-11-08): a 50 pt card-coloured circle with the soft v3.2 shadow, the same
/// colour inside and out; colour only on the icon (16 pt) and the number (11 pt): jade for a
/// workout or a 10k day, lime for the moon, grey for Whoop strain. A grey dot top right = not yet
/// booked. It floats 3.5 pt up and down every 3.4 s. Eaten: a jelly wobble, then it pops.
struct FoodBubbleView: View {
    let bubble: FoodBubble
    let phase: Int
    var eaten = false
    @State private var up = false

    private struct Pop {
        var sx: CGFloat = 1
        var sy: CGFloat = 1
        var scale: CGFloat = 1
        var opacity: Double = 1
    }

    private var ink: Color {
        switch bubble.kind {
        case .workout, .steps: Jade.accent
        case .moon: Jade.sleepText
        case .load: Jade.load
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: bubble.icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(height: 17)
            Text(bubble.label)
                .font(.rounded(11, .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(ink)
        .frame(width: 50, height: 50)
        .background(Circle().fill(Jade.card))
        .softShadow(1.3)
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Jade.ink3)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Jade.card, lineWidth: 2))
                .offset(x: -2, y: 2)
        }
        .keyframeAnimator(initialValue: Pop(), trigger: eaten) { view, pop in
            view.scaleEffect(x: pop.sx * pop.scale, y: pop.sy * pop.scale).opacity(pop.opacity)
        } keyframes: { _ in
            // jelly: 10% wider and 9% shorter, back in 0.18 s; then from 0.17 s up to 1.22 and gone
            KeyframeTrack(\.sx) {
                CubicKeyframe(1.10, duration: 0.045)
                CubicKeyframe(1.0, duration: 0.045)
                CubicKeyframe(0.965, duration: 0.045)
                CubicKeyframe(1.0, duration: 0.045)
            }
            KeyframeTrack(\.sy) {
                CubicKeyframe(0.91, duration: 0.045)
                CubicKeyframe(1.0, duration: 0.045)
                CubicKeyframe(1.03, duration: 0.045)
                CubicKeyframe(1.0, duration: 0.045)
            }
            KeyframeTrack(\.scale) {
                LinearKeyframe(1, duration: 0.17)
                CubicKeyframe(1.22, duration: 0.12)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(1, duration: 0.17)
                LinearKeyframe(0, duration: 0.12)
                LinearKeyframe(0, duration: 0.3)
            }
        }
        .offset(y: up ? -3.5 : 3.5)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true).delay(Double(phase) * 0.45)) {
                up = true
            }
        }
        .contentShape(Circle())
    }
}

/// A bubble sinks a little under the finger.
private struct BubblePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
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
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Jade.card))
            .softShadow(1)
    }
}
