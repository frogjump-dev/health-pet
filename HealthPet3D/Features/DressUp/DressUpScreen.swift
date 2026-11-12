import SwiftUI
import PetCore

/// Dress up (PRD v0.3 §5.4, design v1 of 2026-11-12, D03–D09): the pet on its stage in what it
/// wears now, five slot tabs, the wardrobe (None first, then the fixed order; items not drawn yet
/// are grey silhouettes), and at the bottom the points and Draw · 5. A tap puts an item on (the
/// one in the same slot comes off) and the pet puffs up proudly; a second tap or None takes it off.
/// The wardrobe is shared, each pet keeps its own outfit.
struct DressUpScreen: View {
    let petID: String
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var slot: DecorSlot = .head
    @State private var note: Note?
    @State private var gift: GiftReveal?
    /// Bumped to make a tile bounce (the item just drawn, after Later).
    @State private var bounce: [String: Int] = [:]

    private enum Note: Hashable { case points, draw, locked(String) }

    private var wardrobe: DressUpStore { model.dressUp }
    /// Larger text (PRD v0.3 §8.2): three columns, a lower stage, the page scrolls.
    private var large: Bool { typeSize > .large }

    var body: some View {
        let pet = Pet3D.with(id: petID) ?? .toast
        ScrollView {
            VStack(spacing: 12) {
                PageHeader(title: "") {
                    Button { note = .points } label: { RoundIcon(systemName: "info") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("How points work")
                        .infoNote(isPresented: shown(.points)) { PointsNote() }
                }
                stage(pet)
                tabs(pet)
                    .padding(.top, 2)
                grid(pet)
                    .padding(.top, 2)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar(pet)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(Jade.canvas)
        }
        .background(Jade.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if let gift {
                GiftSheet(gift: gift, collected: wardrobe.collected, pointsLeft: wardrobe.points,
                          wear: { wearGift(gift, on: pet) }, later: { putAway(gift) })
            }
        }
        .animation(.easeOut(duration: 0.25), value: gift)
        .sensoryFeedback(.selection, trigger: wardrobe.outfit(for: pet.id))
        // leaving: the new look's pictures for the Pets tile and share cards are taken now
        .onDisappear {
            let outfit = wardrobe.outfit(for: pet.id)
            guard !outfit.isEmpty else { return }
            Task {
                await PetSnapper.shared.prepare([.neutral, .happy, .proud].map {
                    PetSnapper.Key(pet: pet.id, decor: outfit, pose: $0)
                })
            }
        }
        #if DEBUG
        .task { await debugLaunch(pet) }
        #endif
    }

    // MARK: - Stage

    private func stage(_ pet: Pet3D) -> some View {
        let isMain = model.mainPet3D.id == pet.id
        let dark = scheme == .dark
        return GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let side = min(w * 0.62, h * 0.74)
            if w > 1, h > 1 {
                // 10 pt lower than centred, so a hat has room
                LivePet(config: PetStageConfig(
                    pet: pet.id, rug: false, dark: dark, canvas: Jade.cardHex(dark: dark),
                    energy: isMain ? (home.energyOverride ?? model.energy).rawValue : "normal",
                    decor: wardrobe.outfit(for: pet.id),
                    box: .init(x: Double((w - side) / 2 / w), y: Double(((h - side) / 2 + 10) / h), size: Double(side / w))))
            }
        }
        .frame(height: large ? 200 : 256)
        .background(Jade.card)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(wardrobe.wearingLabel(pet))
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Slot tabs

    private func tabs(_ pet: Pet3D) -> some View {
        HStack(spacing: 0) {
            ForEach(DecorSlot.allCases) { s in
                let on = s == slot
                let worn = wardrobe.worn(s, on: pet.id).flatMap(Decor.with(id:))
                Button { slot = s; note = nil } label: {
                    VStack(spacing: 3) {
                        Group {
                            if let worn {
                                Image(worn.icon).resizable().interpolation(.high).scaledToFit()
                            } else {
                                Circle()
                                    .strokeBorder(Jade.ink3, style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2.5]))
                                    .padding(4)
                            }
                        }
                        .frame(width: 26, height: 26)
                        Text(s.title)
                            .scaledFont(12, .semibold)
                            .foregroundStyle(on ? Jade.ink : Jade.ink2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Jade.card.opacity(on ? 1 : 0))
                            .shadow(color: .black.opacity(on ? 0.06 : 0), radius: 4, y: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(s.title), \(worn.map { "wearing \($0.name)" } ?? "nothing on")")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .frame(minHeight: 62)
        .fixedSize(horizontal: false, vertical: true)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Jade.fill))
        .animation(.easeOut(duration: 0.15), value: slot)
    }

    // MARK: - Wardrobe

    private func grid(_ pet: Pet3D) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: large ? 3 : 4)
        let worn = wardrobe.worn(slot, on: pet.id)
        return LazyVGrid(columns: columns, spacing: 8) {
            noneTile(pet, worn: worn.flatMap(Decor.with(id:)))
            ForEach(Decor.of(slot)) { decor in
                if wardrobe.owns(decor.id) {
                    ownedTile(decor, pet: pet, worn: worn == decor.id)
                } else {
                    lockedTile(decor)
                }
            }
        }
    }

    private func noneTile(_ pet: Pet3D, worn: Decor?) -> some View {
        Button {
            note = nil
            if worn != nil { model.dressUp.takeOff(slot, from: pet.id) }
        } label: {
            tileFace(selected: worn == nil) {
                Image(systemName: "nosign")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Jade.ink2)
                    .frame(width: 42, height: 42)
                    .background(Circle().strokeBorder(Jade.ink3, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
                    .frame(width: 46, height: 46)
            } name: {
                Text("None").foregroundStyle(Jade.ink)
            }
        }
        .buttonStyle(TilePress())
        .accessibilityLabel(worn.map { "Take off \($0.name)" } ?? "Nothing on \(slot.title.lowercased())")
        .accessibilityAddTraits(worn == nil ? .isSelected : [])
    }

    private func ownedTile(_ decor: Decor, pet: Pet3D, worn: Bool) -> some View {
        let new = wardrobe.isNew(decor.id) && !worn
        return Button {
            note = nil
            if worn {
                model.dressUp.takeOff(decor.slot, from: pet.id)
            } else {
                model.dressUp.wear(decor.id, on: pet.id)
                PetStage.shared.celebrate("proud")
            }
        } label: {
            tileFace(selected: worn) {
                Image(decor.icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Wardrobe.well))
            } name: {
                Text(decor.name).foregroundStyle(Jade.ink)
            }
            .overlay(alignment: .topTrailing) {
                if worn { CheckBadge(size: 18).padding(5).accessibilityHidden(true) }
            }
            .overlay(alignment: .topLeading) {
                if new { Circle().fill(Jade.sleep).frame(width: 8, height: 8).padding(9) }
            }
        }
        .buttonStyle(TilePress())
        .pulse(bounce[decor.id] ?? 0, amount: 1.08)
        .accessibilityLabel(decor.name + (worn ? ", worn" : "") + (new ? ", new" : ""))
        .accessibilityAddTraits(worn ? .isSelected : [])
    }

    private func lockedTile(_ decor: Decor) -> some View {
        Button { note = .locked(decor.id) } label: {
            tileFace(selected: false, dim: true) {
                Image(decor.icon)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(Wardrobe.silhouette)
                    .frame(width: 46, height: 46)
            } name: {
                Text(" ")
            }
        }
        .buttonStyle(TilePress())
        .infoNote(isPresented: shown(.locked(decor.id))) { LockedNote(points: wardrobe.points) }
        .accessibilityLabel("Not drawn yet")
    }

    /// A wardrobe tile: 86 pt tall (taller with larger text), 20 pt corners, the picture over its
    /// name; the one worn gets a 2.5 pt jade edge.
    private func tileFace<Picture: View, Name: View>(selected: Bool, dim: Bool = false,
                                                     @ViewBuilder picture: () -> Picture,
                                                     @ViewBuilder name: () -> Name) -> some View {
        VStack(spacing: 4) {
            picture()
            name()
                .scaledFont(11.5, .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 86)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Jade.card.opacity(dim ? 0.5 : 1)))
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Jade.accent, lineWidth: 2.5)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Points and Draw

    @ViewBuilder
    private func bottomBar(_ pet: Pet3D) -> some View {
        if wardrobe.allCollected {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Jade.onSleep)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Jade.sleep))
                VStack(alignment: .leading, spacing: 2) {
                    Text("All \(Decor.all.count) collected")
                        .scaledFont(17, .bold)
                        .foregroundStyle(Jade.ink)
                    Text("Daily points stop here. New items will start them again.")
                        .scaledFont(13, .medium)
                        .foregroundStyle(Jade.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 56)
            .accessibilityElement(children: .combine)
        } else {
            let short = wardrobe.pointsShort
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(wardrobe.points)").scaledFont(24, .bold).foregroundStyle(Jade.ink)
                        Text("pts").scaledFont(13, .semibold).foregroundStyle(Jade.ink2)
                    }
                    HStack(spacing: 6) {
                        if wardrobe.gotPointToday {
                            Text("+1 today")
                                .scaledFont(11, .bold)
                                .foregroundStyle(Jade.onSleep)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Jade.sleep))
                        }
                        Text(short > 0 ? "\(short) more day\(short == 1 ? "" : "s") to draw"
                                       : "\(wardrobe.collected) of \(Decor.all.count) collected")
                            .scaledFont(13, .medium)
                            .foregroundStyle(Jade.ink2)
                            // one line beside "+1 today" (it shrinks a little rather than wrap); two at large text
                            .lineLimit(large ? 2 : 1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                Button { draw(for: pet) } label: {
                    Label("Draw · \(DressUp.drawCost)", systemImage: "gift")
                        .scaledFont(17, .bold)
                        .foregroundStyle(short > 0 ? Jade.ink2 : Jade.onPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        .frame(width: large ? 150 : 168, height: 52)
                        .background(Capsule().fill(short > 0 ? Jade.fill : Jade.primary))
                }
                .buttonStyle(TilePress())
                .infoNote(isPresented: shown(.draw)) { PointsNote() }
                .accessibilityLabel(short > 0
                    ? "Draw, dimmed. \(wardrobe.points) of \(DressUp.drawCost) points, \(short) more day\(short == 1 ? "" : "s")"
                    : "Draw, \(DressUp.drawCost) points")
            }
        }
    }

    private func draw(for pet: Pet3D) {
        guard wardrobe.canDraw, let id = model.dressUp.draw() else {
            note = .draw
            return
        }
        note = nil
        gift = GiftReveal(item: id, petName: pet.name)
    }

    private func wearGift(_ gift: GiftReveal, on pet: Pet3D) {
        if let decor = Decor.with(id: gift.item) { slot = decor.slot }
        model.dressUp.wear(gift.item, on: pet.id)
        self.gift = nil
        PetStage.shared.celebrate("proud")
    }

    private func putAway(_ gift: GiftReveal) {
        if let decor = Decor.with(id: gift.item) { slot = decor.slot }
        self.gift = nil
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            bounce[gift.item, default: 0] += 1
        }
    }

    private func shown(_ which: Note) -> Binding<Bool> {
        Binding(get: { note == which }, set: { if !$0, note == which { note = nil } })
    }

    #if DEBUG
    /// For screenshots on the simulator: -hp3dDressSlot eyes opens that tab; -hp3dDressNote
    /// points|locked opens that note; -hp3dDressGift YES draws (the gift card's box; add
    /// -hp3dGiftOpen YES to open it).
    private func debugLaunch(_ pet: Pet3D) async {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "hp3dDressSlot"), let s = DecorSlot(rawValue: raw) { slot = s }
        try? await Task.sleep(for: .seconds(1.5))
        switch defaults.string(forKey: "hp3dDressNote") {
        case "points": note = .points
        case "locked":
            if let first = Decor.of(slot).first(where: { !wardrobe.owns($0.id) }) { note = .locked(first.id) }
        default: break
        }
        if defaults.bool(forKey: "hp3dDressGift") {
            let id = (wardrobe.canDraw ? model.dressUp.draw() : nil) ?? "butterfly"
            gift = GiftReveal(item: id, petName: pet.name)
        }
    }
    #endif
}

/// 「How points work」 (D05): the info button and a short Draw button both open it.
struct PointsNote: View {
    var body: some View {
        InfoNote(title: "How points work") {
            VStack(alignment: .leading, spacing: 8) {
                line("1", Text("You get ") + Text("1 pt").bold().foregroundStyle(Jade.ink)
                     + Text(" the first time you open Ovenpals each day."))
                line("5", Text("5 pts").bold().foregroundStyle(Jade.ink)
                     + Text(" = one draw. Every draw is an item you don’t have yet."))
                line("♥", Text("Items fit every pet, and each pet keeps its own look."))
            }
        }
    }

    private func line(_ mark: String, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(mark)
                .font(.rounded(10, .bold))
                .foregroundStyle(Jade.ink2)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Jade.fill))
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                .accessibilityHidden(true)
            text
        }
    }
}

/// 「Not drawn yet」 (D04) on a silhouette.
private struct LockedNote: View {
    let points: Int

    var body: some View {
        let short = max(0, DressUp.drawCost - points)
        InfoNote(title: "Not drawn yet") {
            Text("Every draw brings an item you don’t have yet. ")
                + (short > 0
                   ? Text("You have ") + Text("\(points) of \(DressUp.drawCost) pts").bold().foregroundStyle(Jade.ink) + Text(".")
                   : Text("You can draw now."))
        }
    }
}

/// A light press for the wardrobe's tiles and the Draw button.
private struct TilePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
