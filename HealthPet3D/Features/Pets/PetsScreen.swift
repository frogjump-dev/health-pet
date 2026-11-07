import SwiftUI
import PetCore

/// Pets: all 20 in one grid, unlocked first. Locked pets are only a silhouette;
/// tapping any pet opens its page.
struct PetsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(HomeState.self) private var home

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        let records = model.petRecords
        PageScroll {
            PageHeader(title: "Pets", count: "\(records.filter(\.isUnlocked).count)/\(records.count)")
                .padding(.bottom, 4)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(records, id: \.pet.id) { record in
                    NavigationLink(value: Route.pet(record.pet.id)) {
                        PetTile(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { home.markSeen(model.unlockedPets) }
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
    @Environment(\.colorScheme) private var scheme
    @State private var stage = PetStageController()
    @State private var dressUpSoon = false

    var body: some View {
        let pet = Pet3D.with(id: petID) ?? .toast
        let record = model.record(pet)
        let isMain = model.mainPet3D.id == pet.id
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "")
            stageCard(pet: pet, unlocked: record.isUnlocked)
                .padding(.top, 14)
            VStack(alignment: .leading, spacing: 8) {
                Text(pet.name)
                    .font(.rounded(30, .bold))
                    .foregroundStyle(Jade.ink)
                if let activity = pet.activity {
                    Label(activity.title, systemImage: activity.icon)
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
    private func stageCard(pet: Pet3D, unlocked: Bool) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let side = min(w * 0.62, h * 0.74)
            ZStack {
                if unlocked, w > 1 {
                    PetStageView(controller: stage, config: PetStageConfig(
                        pet: pet.id, rug: false, dark: scheme == .dark, canvas: Jade.cardHex(dark: scheme == .dark),
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
