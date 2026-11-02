import SwiftUI
import PetCore

/// Pets 图鉴: the breakfast pets (and the Whoop-only Supply Squad) by family. Each pet is bound to one activity: do it once
/// to unlock the pet, and its level shows how much of it you've done. Locked pets show the
/// activity that unlocks them.
struct PetsView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedID: String?

    private static let featuredID = "featured"

    private var owned: Set<String> { Set(model.ownedPets.map(\.id)) }
    private var selected: RosterPet { selectedID.flatMap(RosterPet.pet(id:)) ?? model.mainPet }

    var body: some View {
        let ownedCount = RosterPet.roster.filter { owned.contains($0.id) }.count
        ChibiPage(title: "Pets", subtitle: "\(ownedCount) of \(RosterPet.roster.count) unlocked") {
            if let top = model.topPets.first {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.system(size: 12, weight: .black))
                    Text("Top Lv \(top.progress.level)").font(ChibiFont.title(15))
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Capsule().fill(Palette.butter))
                .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
                .accessibilityLabel("Highest level \(top.progress.level), \(top.pet.name)")
            }
        } content: {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        FeaturedPet(pet: selected,
                                    progress: selected.activity.map(model.progress(for:)),
                                    have: owned.contains(selected.id))
                            .padding(.top, 12)
                            .id(Self.featuredID)
                        mainPetRow.padding(.top, 10)

                        ForEach(PetFamily.allCases) { family in
                            section(family)
                        }
                        guideRow
                        Text("A day counts once per activity. Sessions in a Discipline Week earn double.")
                            .font(ChibiFont.body(12))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 18)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                // Picking a pet further down brings its big card into view.
                .onChange(of: selectedID) {
                    withAnimation(.easeInOut(duration: 0.3)) { scroller.scrollTo(Self.featuredID, anchor: .top) }
                }
            }
        }
    }

    @ViewBuilder
    private var mainPetRow: some View {
        let have = owned.contains(selected.id) || selected.family == nil
        if selected.id == model.mainPet.id {
            note("Main pet · stands in the middle of your kitchen", icon: "star.fill")
        } else if !have {
            note("Not unlocked yet · do it once and it's yours", icon: "lock.fill")
        } else if selected.image == nil {
            note("Moves into your kitchen when its art is ready", icon: "paintbrush.fill")
        } else {
            ChibiButton(title: "Set as main pet", primary: false, height: 38) {
                model.mainPetID = selected.id
            }
        }
    }

    private func note(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(ChibiFont.bold(12))
            .foregroundStyle(Palette.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
    }

    private func section(_ family: PetFamily) -> some View {
        let pets = RosterPet.roster.filter { $0.family == family }
        let have = pets.filter { owned.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(family.title).font(ChibiFont.title(16)).foregroundStyle(family.accent)
                Text("\(have)/\(pets.count) · \(family.tagline)").font(ChibiFont.body(12)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 2)
            HStack(spacing: 9) {
                ForEach(pets) { pet in
                    card(pet, family: family)
                }
                // Keep card widths the same in shorter rows (the Whoop family has three).
                ForEach(pets.count..<4, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
            }
        }
        .padding(.top, 14)
    }

    private var guideRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Guide").font(ChibiFont.title(16)).foregroundStyle(Palette.crust)
                Text("with you from day one").font(ChibiFont.body(12)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 2)
            HStack(spacing: 9) {
                card(.toast, family: nil)
                ForEach(0..<3, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
            }
        }
        .padding(.top, 14)
    }

    @ViewBuilder
    private func card(_ pet: RosterPet, family: PetFamily?) -> some View {
        let have = pet.family == nil || owned.contains(pet.id)
        let level = pet.activity.map { model.progress(for: $0).level } ?? 0
        let isSelected = pet.id == selected.id
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button {
            selectedID = pet.id
        } label: {
            VStack(spacing: 0) {
                ZStack {
                    if have, let image = pet.image {
                        Image(image).resizable().scaledToFit().padding(.top, 5).padding(.horizontal, 4)
                    } else {
                        // Locked, or unlocked before its art is drawn: the activity stands in.
                        Image(systemName: pet.activity?.symbol ?? "questionmark")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(have ? Palette.ink : Color(red: 0.73, green: 0.66, blue: 0.56))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    if have && level > 0 {
                        Text("Lv\(level)")
                            .font(ChibiFont.title(10))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 4)
                            .background(Capsule().fill(Palette.butter))
                            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 1.5))
                            .padding(4)
                    }
                }
                Text(have ? pet.name : (pet.activity?.title ?? "?"))
                    .font(ChibiFont.bold(10.5))
                    .foregroundStyle(have ? Palette.ink : Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background(have ? Palette.cream : Color(red: 0.87, green: 0.82, blue: 0.72))
                    .overlay(alignment: .top) { Rectangle().fill(Palette.ink).frame(height: 2.5) }
            }
            .frame(height: 96)
            .clipShape(shape)
            .chibiPanel(shape, fill: have ? (family?.tint ?? Palette.creamDeep) : Color(red: 0.91, green: 0.86, blue: 0.78), shadow: 3)
            .overlay(shape.strokeBorder(Palette.ink, lineWidth: 3))
            .overlay {
                if isSelected {
                    shape.inset(by: -4).strokeBorder(.white, lineWidth: 3)
                    shape.inset(by: -6.5).strokeBorder(Palette.ink, lineWidth: 2.5)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .frame(maxWidth: .infinity)
        .accessibilityLabel(have ? "\(pet.name), level \(level)" : "Locked. \(pet.activity?.unlockHint ?? "")")
    }
}

/// The selected pet, big: its activity, level, progress to the next level and the day it
/// was unlocked (its 出炉证书 date, to remember when you started). Locked pets show how to get them.
private struct FeaturedPet: View {
    let pet: RosterPet
    /// nil for Toast, who has no activity.
    let progress: ActivityProgress?
    let have: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                Ellipse().fill(Palette.ink.opacity(0.15)).frame(width: 104, height: 24)
                if have || pet.family == nil, let image = pet.image {
                    Image(image).resizable().scaledToFit().frame(height: 142).padding(.bottom, 6)
                } else {
                    Image(systemName: pet.activity?.symbol ?? "questionmark")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundStyle(have ? Palette.ink : Color(red: 0.73, green: 0.66, blue: 0.56))
                        .frame(height: 142)
                        .padding(.bottom, 6)
                }
            }
            .frame(width: 118)

            VStack(alignment: .leading, spacing: 0) {
                Text(have || pet.family == nil ? pet.name : "Locked")
                    .font(ChibiFont.title(24)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 5) {
                    if let activity = pet.activity {
                        ChibiChip(text: activity.title, fill: pet.family?.tint ?? Palette.cream)
                        ChibiChip(text: pet.mbti.isEmpty ? "Whoop" : pet.mbti)
                    } else {
                        ChibiChip(text: "Your guide", fill: Palette.honey)
                    }
                }
                .padding(.top, 5)

                // Same number of lines for every pet so the card keeps its height when the selection changes.
                Text(lines.0).font(ChibiFont.body(12)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.top, 7)
                Text(lines.1).font(ChibiFont.body(12)).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.top, 6)
                LevelBar(level: progress?.level ?? 0, fraction: progress?.levelFraction ?? 0)
                    .padding(.top, 4)
                    .opacity(progress == nil ? 0 : 1)
                Text(lines.2).font(ChibiFont.body(12)).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.top, 3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .chibiPanel(RoundedRectangle(cornerRadius: 20, style: .continuous),
                    fill: have || pet.family == nil ? (pet.family?.tint ?? Palette.creamDeep) : Color(red: 0.91, green: 0.86, blue: 0.78))
    }

    /// Top line, level line, next-level line.
    private var lines: (String, String, String) {
        guard let progress, let activity = pet.activity else {
            return ("Shows you around the kitchen", "With you from day one", " ")
        }
        guard progress.isUnlocked else {
            return ("How to unlock:", activity.unlockHint, " ")
        }
        let since = progress.unlockedOn.map { "Since \($0.formatted(.dateTime.month(.abbreviated).day().year()))" } ?? ""
        return ("\(activity.sessions(progress.sessions)) · \(since)",
                "Level \(progress.level)",
                "\(progress.experienceToNext) more to Lv \(progress.level + 1)")
    }
}

/// Lv N with a bar filling towards the next level.
private struct LevelBar: View {
    let level: Int
    let fraction: Double

    var body: some View {
        HStack(spacing: 0) {
            Text("\(level)")
                .font(ChibiFont.title(11))
                .foregroundStyle(Palette.ink)
                .frame(width: 22, height: 22)
                .background(Circle().fill(level > 0 ? Palette.butter : Palette.empty))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Palette.empty
                    Palette.butter.frame(width: geo.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 6)
            .overlay(VStack { Palette.ink.frame(height: 2.5); Spacer(minLength: 0); Palette.ink.frame(height: 2.5) })
            Text("\(level + 1)")
                .font(ChibiFont.title(11))
                .foregroundStyle(Palette.inkSoft)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Palette.empty))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5))
        }
    }
}
