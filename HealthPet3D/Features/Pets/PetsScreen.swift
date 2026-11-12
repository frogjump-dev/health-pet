import SwiftUI
import PetCore

/// Pets (PRD v0.2): only the pets the user has, Toast first, then highest level. Everyone still to
/// meet sits behind one tile of grey silhouettes. The Whoop pets only show up for Whoop users.
struct PetsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        let records = model.petRecords
        let unlocked = records.filter(\.isUnlocked)
        let locked = records.filter { !$0.isUnlocked }
        PageScroll {
            PageHeader(title: "Pets", count: "\(unlocked.count)")
                .padding(.bottom, 4)
            // enough points for a draw: straight into the main pet's Dress up (PRD v0.3 §5.4, D01)
            if model.dressUp.canDraw {
                NavigationLink(value: Route.dressUp(model.mainPet3D.id)) {
                    DrawRow(points: model.dressUp.points, petName: model.mainPet3D.name)
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(unlocked, id: \.pet.id) { record in
                    NavigationLink(value: Route.pet(record.pet.id)) {
                        PetTile(record: record, decor: model.dressUp.outfit(for: record.pet.id),
                                wearing: model.dressUp.wearing(record.pet))
                    }
                    .buttonStyle(.plain)
                }
                if !locked.isEmpty {
                    NavigationLink(value: Route.lockedPets) {
                        StillToMeetTile(locked: locked.map(\.pet))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { home.markSeen(model.unlockedPets) }
    }
}

/// 「Draw a new item · 7 pts」 at the top of Pets while a draw is possible.
struct DrawRow: View {
    let points: Int
    let petName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Jade.ink)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Jade.fill))
            VStack(alignment: .leading, spacing: 1) {
                Text("Draw a new item")
                    .scaledFont(15, .bold)
                    .foregroundStyle(Jade.ink)
                Text("\(points) pts · in Dress up")
                    .scaledFont(12, .medium)
                    .foregroundStyle(Jade.ink2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Jade.ink2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous).fill(Jade.card))
        .contentShape(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Draw a new item, \(points) points")
        .accessibilityHint("Opens Dress up for \(petName)")
    }
}

/// 「还能遇见谁」: the one way in to the pets not met yet, a few silhouettes. No count and no
/// progress (PRD v0.3 §5.2): meeting them is a surprise, not a list to finish.
struct StillToMeetTile: View {
    let locked: [Pet3D]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: -14) {
                ForEach(locked.prefix(3), id: \.id) { pet in
                    PetPicture(pet: pet, locked: true).frame(width: 40, height: 40)
                }
            }
            .frame(height: 62)
            Text("Still to meet")
                .font(.rounded(12, .semibold))
                .foregroundStyle(Jade.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.top, 22)
        .padding(.bottom, 12)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous).fill(Jade.card.opacity(0.5)))
        .contentShape(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pets still to meet")
    }
}

/// The pets not met yet, as silhouettes; each opens its page, which says how to meet it.
struct LockedPetsScreen: View {
    @Environment(AppModel.self) private var model

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        let locked = model.petRecords.filter { !$0.isUnlocked }
        PageScroll {
            PageHeader(title: "Still to meet")
                .padding(.bottom, 4)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(locked, id: \.pet.id) { record in
                    NavigationLink(value: Route.pet(record.pet.id)) {
                        PetTile(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct PetTile: View {
    let record: PetRecord
    /// What it wears (PRD v0.3 §5.4): a dressed pet shows its photographed picture.
    var decor: [String] = []
    /// "Cowboy hat and Bandana" for VoiceOver (nil = nothing on).
    var wearing: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            PetPicture(pet: record.pet, locked: !record.isUnlocked, decor: record.isUnlocked ? decor : [])
                .frame(height: 62)
            Text(record.isUnlocked ? record.pet.name : " ")
                .font(.rounded(12, .semibold))
                .foregroundStyle(Jade.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.top, 22)
        .padding(.bottom, 12)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous)
            .fill(Jade.card.opacity(record.isUnlocked ? 1 : 0.5)))
        .overlay(alignment: .topLeading) {
            if record.isUnlocked {
                Text("Lv \(record.level)")
                    .font(.rounded(10, .bold))
                    .foregroundStyle(Jade.ink2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Jade.fill))
                    .padding(8)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(record.isUnlocked
            ? "\(record.pet.name), level \(record.level)" + (wearing.map { ", wearing \($0)" } ?? "")
            : "Locked pet")
    }
}

/// One pet: big and alive in what it wears (or a silhouette), its activity and level, Set as main
/// and Dress up (PRD v0.3 §5.4; a dot on it while a draw is possible).
struct PetDetailScreen: View {
    let petID: String
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home
    @Environment(\.colorScheme) private var scheme
    /// 「Toast is wearing the Party hat」, after the welcome gift was put on from home (D13).
    @State private var wornLine: String?

    var body: some View {
        let pet = Pet3D.with(id: petID) ?? .toast
        let record = model.record(pet)
        let isMain = model.mainPet3D.id == pet.id
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "")
            stageCard(pet: pet, unlocked: record.isUnlocked, isMain: isMain)
                .padding(.top, 14)
            VStack(alignment: .leading, spacing: 8) {
                Text(pet.name)
                    .font(.rounded(30, .bold))
                    .foregroundStyle(Jade.ink)
                if let activity = pet.activity {
                    Label(activity.title, systemImage: activity.icon)
                        .font(.rounded(15, .semibold))
                        .foregroundStyle(Jade.ink2)
                } else {
                    // Toast's level is every 自律周 so far
                    Label("Disciplined weeks", systemImage: "checkmark.seal")
                        .font(.rounded(15, .semibold))
                        .foregroundStyle(Jade.ink2)
                }
            }
            .padding(.top, 22)
            if record.isUnlocked {
                level(record)
                    .padding(.top, 22)
            } else if let activity = pet.activity {
                Label(activity.unlockHint, systemImage: "lock")
                    .font(.rounded(15, .medium))
                    .foregroundStyle(Jade.ink2)
                    .padding(.top, 18)
            }
            Spacer(minLength: 20)
            if record.isUnlocked {
                VStack(spacing: 10) {
                    Button(isMain ? "Main pet" : "Set as main") { model.mainPetID = pet.rosterID }
                        .buttonStyle(PillButtonStyle(primary: true))
                        .disabled(isMain)
                        .opacity(isMain ? 0.55 : 1)
                    NavigationLink(value: Route.dressUp(pet.id)) {
                        Text("Dress up")
                    }
                    .buttonStyle(PillButtonStyle(primary: false))
                    .overlay(alignment: .trailing) {
                        if model.dressUp.canDraw {
                            Circle().fill(Jade.accent).frame(width: 8, height: 8).padding(.trailing, 26)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel(model.dressUp.canDraw ? "Dress up, you can draw a new item" : "Dress up")
                    .overlay(alignment: .center) {
                        if let wornLine {
                            Text(wornLine)
                                .scaledFont(14, .bold)
                                .foregroundStyle(Jade.onPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Jade.primary))
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Jade.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await sayWorn(pet) }
    }

    /// The welcome gift went on from home: say so once and puff up proudly.
    private func sayWorn(_ pet: Pet3D) async {
        guard let worn = model.dressUp.justWorn, worn.pet == pet.id, let decor = Decor.with(id: worn.item) else { return }
        model.dressUp.justWorn = nil
        let text = "\(pet.name) is wearing the \(decor.name)"
        withAnimation(.spring(duration: 0.3)) { wornLine = text }
        AccessibilityNotification.Announcement(text).post()
        try? await Task.sleep(for: .seconds(0.6))
        PetStage.shared.celebrate("proud")
        try? await Task.sleep(for: .seconds(2.2))
        withAnimation(.easeOut(duration: 0.25)) { wornLine = nil }
    }

    @ViewBuilder
    private func stageCard(pet: Pet3D, unlocked: Bool, isMain: Bool) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let side = min(w * 0.62, h * 0.74)
            ZStack {
                if unlocked, w > 1 {
                    // the main pet carries the week's energy here too (PRD v0.2 §5.5)
                    LivePet(config: PetStageConfig(
                        pet: pet.id, rug: false, dark: scheme == .dark, canvas: Jade.cardHex(dark: scheme == .dark),
                        energy: isMain ? (home.energyOverride ?? model.energy).rawValue : "normal",
                        decor: model.dressUp.outfit(for: pet.id),
                        box: .init(x: Double((w - side) / 2 / w), y: Double((h - side) / 2 / h), size: Double(side / w))))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(model.dressUp.wearingLabel(pet))
                } else {
                    PetPicture(pet: pet, locked: true)
                        .frame(width: side, height: side)
                }
            }
            .frame(width: w, height: h)
        }
        .frame(height: 300)
        .background(Jade.card)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.card, style: .continuous))
    }

    private func level(_ record: PetRecord) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Lv \(record.level)").font(.rounded(20, .bold)).foregroundStyle(Jade.ink)
                Spacer()
                Text("\(record.level + 1)").font(.rounded(13, .semibold)).foregroundStyle(Jade.ink2)
            }
            Track(fraction: record.levelFraction, color: Jade.accent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(record.level), \(Int(record.levelFraction * 100)) percent to level \(record.level + 1)")
    }
}
