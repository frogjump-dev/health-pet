import SwiftUI
import PetCore

/// Pets 图鉴: the 16 breakfast pets by family. Pets you have show their art; the rest are
/// "?" cards until they're baked with a 出炉券 earned from a 自律周.
struct PetsView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedID: String?
    @State private var showBakeInfo = false

    private static let featuredID = "featured"

    private var owned: Set<String> { Set(model.ownedPets.map(\.id)) }
    private var selected: RosterPet { selectedID.flatMap(RosterPet.pet(id:)) ?? model.mainPet }

    var body: some View {
        let ownedCount = RosterPet.roster.filter { owned.contains($0.id) }.count
        ChibiPage(title: "Pets", subtitle: "\(ownedCount) of \(RosterPet.roster.count) baked") {
            HStack(spacing: 5) {
                TicketGlyph()
                Text("×\(model.bakeTickets)").font(ChibiFont.title(15)).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(red: 1, green: 0.90, blue: 0.63)))
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
            .accessibilityLabel("\(model.bakeTickets) bake tickets")
        } content: {
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        FeaturedPet(pet: selected, weeks: model.disciplinedWeekCount)
                            .padding(.top, 12)
                            .id(Self.featuredID)
                        if selected.id == model.mainPet.id {
                            Label("Main pet · stands in the middle of your kitchen", systemImage: "star.fill")
                                .font(ChibiFont.bold(12))
                                .foregroundStyle(Palette.inkSoft)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .padding(.top, 10)
                        } else {
                            ChibiButton(title: "Set as main pet", primary: false, height: 38) {
                                model.mainPetID = selected.id
                            }
                            .padding(.top, 10)
                        }

                        ForEach(PetFamily.allCases) { family in
                            section(family)
                        }
                        guideRow
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
                // Picking a pet further down brings its big card into view.
                .onChange(of: selectedID) {
                    withAnimation(.easeInOut(duration: 0.3)) { scroller.scrollTo(Self.featuredID, anchor: .top) }
                }
            }
            .overlay(alignment: .bottom) {
                // Bright yellow only when there's a ticket to spend.
                ChibiButton(title: "Bake a new friend",
                            detail: model.bakeTickets > 0
                                ? "· \(model.bakeTickets) ticket\(model.bakeTickets == 1 ? "" : "s")"
                                : "· finish a Discipline Week",
                            primary: model.bakeTickets > 0) {
                    showBakeInfo = true
                }
                .padding(.horizontal, 16)
                .padding(.top, 30)
                .padding(.bottom, 8)
                .background(LinearGradient(colors: [Color(red: 0.94, green: 0.81, blue: 0.61).opacity(0),
                                                     Color(red: 0.94, green: 0.81, blue: 0.61)],
                                           startPoint: .top, endPoint: .center))
            }
        }
        .alert("Baking opens soon", isPresented: $showBakeInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Every Discipline Week gives you a bake ticket. Soon you can spend it here to bake a new friend from the family you pick.")
        }
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
        let isSelected = pet.id == selected.id
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button {
            if have { selectedID = pet.id }
        } label: {
            VStack(spacing: 0) {
                ZStack {
                    if have, let image = pet.image {
                        Image(image).resizable().scaledToFit().padding(.top, 5).padding(.horizontal, 4)
                    } else if have {
                        Image(pet.art).resizable().scaledToFit().padding(.top, 5).padding(.horizontal, 4)
                    } else {
                        Text("?").font(ChibiFont.title(38)).foregroundStyle(Color(red: 0.73, green: 0.66, blue: 0.56))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(have ? pet.name : pet.mbti)
                    .font(ChibiFont.bold(10.5))
                    .foregroundStyle(have ? Palette.ink : Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
        .disabled(!have)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(have ? pet.name : "Not baked yet, \(pet.mbti)")
    }
}

/// The selected pet, big: family, MBTI and how far it is along the 3 evolution stages.
private struct FeaturedPet: View {
    let pet: RosterPet
    let weeks: Int

    var body: some View {
        let stage = Evolution.stage(forDisciplinedWeeks: weeks)
        HStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                Ellipse().fill(Palette.ink.opacity(0.15)).frame(width: 104, height: 24)
                Image(pet.art).resizable().scaledToFit().frame(height: 142).padding(.bottom, 6)
            }
            .frame(width: 118)

            VStack(alignment: .leading, spacing: 0) {
                Text(pet.name).font(ChibiFont.title(24)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 5) {
                    if let family = pet.family {
                        ChibiChip(text: family.className, fill: family.tint)
                        ChibiChip(text: pet.mbti)
                    } else {
                        ChibiChip(text: "Your guide", fill: Palette.honey)
                    }
                }
                .padding(.top, 5)
                // One line for every pet so the card keeps its height when the selection changes.
                Text(pet.family.map { $0.tagline.capitalizedFirst } ?? "Shows you around the kitchen")
                    .font(ChibiFont.body(12)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.top, 7)
                Text(stage == 0 ? Self.stageName(0) : "Stage \(stage) · \(Self.stageName(stage))")
                    .font(ChibiFont.body(12)).foregroundStyle(Palette.inkSoft)
                    .padding(.top, 6)
                StageTrack(weeks: weeks).padding(.top, 4)
                Text(nextLine).font(ChibiFont.body(12)).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.top, 3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .chibiPanel(RoundedRectangle(cornerRadius: 20, style: .continuous),
                    fill: pet.family?.tint ?? Palette.creamDeep)
    }

    static func stageName(_ stage: Int) -> String {
        ["Fresh out of the oven", "Food Buddy", "Apprentice", "Hero"][min(max(stage, 0), 3)]
    }

    private var nextLine: String {
        let stage = Evolution.stage(forDisciplinedWeeks: weeks)
        guard let left = Evolution.weeksToNextStage(from: weeks) else { return "Fully grown. Legendary!" }
        return "\(Self.stageName(stage + 1)) after \(left) more Discipline Week\(left == 1 ? "" : "s")"
    }
}

/// ①—②—③ with the segments filled by cumulative 自律周 (thresholds 1 / 4 / 12).
private struct StageTrack: View {
    let weeks: Int

    var body: some View {
        let t = Evolution.thresholds
        HStack(spacing: 0) {
            ForEach(t.indices, id: \.self) { i in
                if i > 0 {
                    segment(fill: Double(weeks - t[i - 1]) / Double(t[i] - t[i - 1]))
                }
                Text("\(i + 1)")
                    .font(ChibiFont.title(11))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(weeks >= t[i] ? Palette.butter : Palette.empty))
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5))
            }
        }
    }

    private func segment(fill: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Palette.empty
                Palette.butter.frame(width: geo.size.width * min(max(fill, 0), 1))
            }
        }
        .frame(height: 6)
        .overlay(VStack { Palette.ink.frame(height: 2.5); Spacer(minLength: 0); Palette.ink.frame(height: 2.5) })
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
