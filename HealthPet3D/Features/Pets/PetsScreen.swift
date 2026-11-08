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
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(unlocked, id: \.pet.id) { record in
                    NavigationLink(value: Route.pet(record.pet.id)) {
                        PetTile(record: record)
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

/// 「还能遇见谁」: the one way in to the pets not met yet, a few silhouettes and how many there are.
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
            Text("+\(locked.count)")
                .font(.rounded(12, .semibold))
                .foregroundStyle(Jade.ink2)
        }
        .padding(.top, 22)
        .padding(.bottom, 12)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous).fill(Jade.card.opacity(0.5)))
        .contentShape(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(locked.count) pets still to meet")
    }
}

/// The pets not met yet, as silhouettes; each opens its page, which says how to meet it.
struct LockedPetsScreen: View {
    @Environment(AppModel.self) private var model

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        let locked = model.petRecords.filter { !$0.isUnlocked }
        PageScroll {
            PageHeader(title: "Still to meet", count: "\(locked.count)")
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

    var body: some View {
        VStack(spacing: 6) {
            PetPicture(pet: record.pet, locked: !record.isUnlocked)
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
        .accessibilityLabel(record.isUnlocked ? "\(record.pet.name), level \(record.level)" : "Locked pet")
    }
}

/// One pet: big and alive (or a silhouette), its activity and level, Set as main / Dress up.
struct PetDetailScreen: View {
    let petID: String
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home
    @Environment(\.colorScheme) private var scheme
    @State private var dressUpSoon = false

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
                    Button("Dress up") { dressUpSoon = true }
                        .buttonStyle(PillButtonStyle(primary: false))
                }
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Jade.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert("Dress up is coming soon", isPresented: $dressUpSoon) { Button("OK", role: .cancel) {} }
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
                        box: .init(x: Double((w - side) / 2 / w), y: Double((h - side) / 2 / h), size: Double(side / w))))
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
                Text("\(record.level + 1)").font(.rounded(13, .semibold)).foregroundStyle(Jade.ink3)
            }
            Track(fraction: record.levelFraction, color: Jade.accent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(record.level), \(Int(record.levelFraction * 100)) percent to level \(record.level + 1)")
    }
}
