import SwiftUI
import UIKit
import Photos
import PetCore

/// Share: turns the week (or today, or the pet crew) into a card worth showing off.
/// Bedtimes stay off the card unless the user turns them on.
struct ShareView: View {
    @Environment(AppModel.self) private var model
    @State private var template: ShareTemplate = .week
    @State private var showNumbers = true
    @State private var showBedtimes = false
    @State private var saved = false
    @State private var saveFailed = false

    var body: some View {
        let card = ShareCard(content: content)
        ChibiPage(title: "Share", subtitle: "Turn your week into a card") {
            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        ForEach(ShareTemplate.allCases) { option in
                            Button { template = option } label: {
                                Text(option.title)
                                    .font(ChibiFont.bold(12.5))
                                    .foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 4)
                                    .padding(.bottom, 3)
                                    .chibiPanel(Capsule(), fill: template == option ? Palette.butter : Palette.cream,
                                                shadow: template == option ? 3 : 0, line: 2.5)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.top, 14)

                    card
                        .rotationEffect(.degrees(-1.5))
                        .padding(.top, 20)

                    // Only the switches that change this card: pet cards have none.
                    if template != .pets {
                        VStack(spacing: 0) {
                            toggle("Show exact numbers", "Off shows ticks only", isOn: $showNumbers)
                            if template == .today {
                                Rectangle()
                                    .stroke(Color(red: 0.88, green: 0.83, blue: 0.74), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                                    .frame(height: 1)
                                toggle("Show bedtime", "Kept private by default", isOn: $showBedtimes)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .chibiPanel(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.top, 24)
                    }
                }
                // Full width even without the switches panel, so the buttons below don't shrink.
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .overlay(alignment: .bottom) {
                let image = render(card)
                HStack(spacing: 10) {
                    ChibiButton(title: saved ? "Saved!" : "Save image", primary: false) {
                        if let image { save(image) }
                    }
                    .frame(width: 130)
                    if let image {
                        ShareLink(item: Image(uiImage: image),
                                  preview: SharePreview("My HealthPet card", image: Image(uiImage: image))) {
                            HStack { OutlinedText(text: "Share card", font: ChibiFont.title(19), outline: 1.8, tracking: 1.4) }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .chibiPanel(RoundedRectangle(cornerRadius: 18, style: .continuous), fill: Palette.butter)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 30)
                .padding(.bottom, 8)
                .background(LinearGradient(colors: [Color(red: 0.94, green: 0.81, blue: 0.61).opacity(0),
                                                     Color(red: 0.94, green: 0.81, blue: 0.61)],
                                           startPoint: .top, endPoint: .center))
            }
        }
        .alert("Couldn't save the card", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow HealthPet to add photos in Settings → Privacy & Security → Photos, then try again.")
        }
        .onChange(of: template) { saved = false }
        .onChange(of: showNumbers) { saved = false }
        .onChange(of: showBedtimes) { saved = false }
    }

    private func toggle(_ title: String, _ caption: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(ChibiFont.bold(14)).foregroundStyle(Palette.ink)
                Text(caption).font(ChibiFont.body(12)).foregroundStyle(Palette.inkSoft)
            }
        }
        .tint(Palette.mintDeep)
        .padding(.vertical, 7)
    }

    /// Adds the card to Photos (add-only access) and only says "Saved!" when it really was.
    private func save(_ image: UIImage) {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else { saveFailed = true; return }
            guard let data = image.pngData() else { saveFailed = true; return }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
                }
                saved = true
            } catch {
                saveFailed = true
            }
        }
    }

    @MainActor
    private func render(_ card: ShareCard) -> UIImage? {
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .light))
        renderer.scale = 3
        return renderer.uiImage
    }

    // MARK: - Card content

    private var content: ShareCard.Content {
        let tracker = model.discipline
        let rules = tracker.rules
        // Main pet in the middle of the line-up.
        let crew = model.homePets
        let pets = crew.count >= 3 ? [crew[1], crew[0], crew[2]] : crew
        let footer = "Week \(model.weekInBlock) of \(rules.weeksPerBlock) · \(Date().formatted(.dateTime.month(.abbreviated).year()))"

        switch template {
        case .week:
            let workouts = model.week?.workouts ?? 0
            let nights = model.week?.onTimeNights ?? 0
            let done = model.week?.isDisciplined ?? false
            return .init(
                ribbon: done ? "DISCIPLINE WEEK ✓" : "THIS WEEK",
                lead: "I'm \(article(identity)) ", title: identity, pets: pets,
                stats: [
                    stat(workouts, "workouts", met: workouts >= rules.workoutsPerWeek, color: .workout),
                    stat(nights, "on-time nights", met: nights >= rules.onTimeNightsPerWeek, color: .sleep),
                    .init(value: showNumbers ? shortSteps(model.weekSteps) : "✓", label: "steps", color: .steps),
                ],
                footer: footer)

        case .today:
            let today = model.today
            let onTime = today.flatMap(tracker.isOnTimeNight) == true
            let worked = today.map(tracker.countsAsWorkout) ?? false
            let sleepValue = showBedtimes ? (today?.sleepOnset?.formatted(date: .omitted, time: .shortened) ?? "–")
                                          : (onTime ? "✓" : "–")
            let minutes = Int(today?.workoutMinutes ?? 0)
            return .init(
                ribbon: onTime && worked ? "TWO TICKS TODAY ✓" : "TODAY",
                lead: "I'm \(article(identity)) ", title: identity, pets: pets,
                stats: [
                    .init(value: sleepValue, label: onTime ? "on-time sleep" : "sleep", color: .sleep),
                    .init(value: showNumbers && minutes > 0 ? "\(minutes)m" : (worked ? "✓" : "–"),
                          label: today?.workoutType?.lowercased() ?? "workout", color: .workout),
                    .init(value: showNumbers ? shortSteps(today?.steps ?? 0) : ((today?.steps ?? 0) >= rules.activeDaySteps ? "✓" : "–"),
                          label: "steps", color: .steps),
                ],
                footer: Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))

        case .pets:
            return .init(
                ribbon: "MY BREAKFAST CREW", lead: "Raised with ", title: model.mainPet.name, pets: pets,
                stats: [
                    .init(value: "\(model.ownedPets.count)", label: "pets", color: .steps),
                    .init(value: "\(model.disciplinedWeekCount)", label: "discipline weeks", color: .workout),
                    .init(value: "\(model.daysTogether)", label: "days together", color: .sleep),
                ],
                footer: footer)
        }
    }

    private func stat(_ value: Int, _ label: String, met: Bool, color: ShareCard.StatColor) -> ShareCard.Stat {
        .init(value: showNumbers ? "\(value)" : (met ? "✓" : "–"), label: label, color: color)
    }

    /// e.g. "Early-to-bed Runner": built from the week's habits. Always something nice.
    private var identity: String {
        let rules = model.discipline.rules
        let nights = model.week?.onTimeNights ?? 0
        let workouts = model.week?.workouts ?? 0
        let prefix = nights >= rules.onTimeNightsPerWeek - 1 ? "Early-to-bed"
            : workouts >= rules.workoutsPerWeek ? "Consistent" : "Steady"
        let noun: String
        switch model.favouriteWorkout?.lowercased() {
        case "run"?, "running"?: noun = "Runner"
        case "walk"?, "walking"?, "hike"?, "hiking"?: noun = "Walker"
        case "ride"?, "cycling"?: noun = "Rider"
        case "yoga"?: noun = "Yogi"
        case "strength"?, "lifting"?: noun = "Lifter"
        case "swim"?, "swimming"?: noun = "Swimmer"
        default: noun = "Mover"
        }
        return "\(prefix) \(noun)"
    }

    private func article(_ word: String) -> String {
        "aeiou".contains(word.lowercased().first ?? "x") ? "an" : "a"
    }

    private func shortSteps(_ steps: Int) -> String {
        steps >= 10_000 ? "\(steps / 1000)k" : steps.formatted()
    }
}

enum ShareTemplate: String, CaseIterable, Identifiable {
    case week, today, pets
    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "This week"
        case .today: "Today"
        case .pets: "My pets"
        }
    }
}

/// The card itself, drawn the same on screen and in the saved image.
struct ShareCard: View {
    enum StatColor {
        case workout, sleep, steps

        var color: Color {
            switch self {
            case .workout: Color(red: 0.89, green: 0.38, blue: 0.25)
            case .sleep: Color(red: 0.48, green: 0.36, blue: 0.78)
            case .steps: Palette.mintDeep
            }
        }
    }

    struct Stat {
        var value: String
        var label: String
        var color: StatColor
    }

    struct Content {
        var ribbon: String
        var lead: String
        var title: String
        var pets: [RosterPet]
        var stats: [Stat]
        var footer: String
    }

    let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        VStack(spacing: 0) {
            scene
            VStack(spacing: 0) {
                Text(content.lead.trimmingCharacters(in: .whitespaces))
                    .font(ChibiFont.bold(12))
                    .foregroundStyle(Palette.inkSoft)
                Text(content.title)
                    .font(ChibiFont.title(25))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.top, 9)
            .padding(.horizontal, 12)
            HStack {
                ForEach(content.stats.indices, id: \.self) { i in
                    let stat = content.stats[i]
                    VStack(spacing: 0) {
                        statValue(stat).frame(height: 30)
                        Text(stat.label).font(ChibiFont.body(10.5)).foregroundStyle(Palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 8)
            Spacer(minLength: 0)
            HStack {
                Text(content.footer).font(ChibiFont.body(10.5)).foregroundStyle(Palette.inkSoft)
                Spacer()
                Text("HealthPet").font(ChibiFont.bold(10.5)).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(alignment: .top) {
                Rectangle()
                    .stroke(Color(red: 0.80, green: 0.75, blue: 0.66), style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                    .frame(height: 1)
            }
        }
        .frame(width: 300, height: 372)
        .background(Palette.cream)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.ink, lineWidth: 3))
        .background(shape.fill(Palette.ink).offset(y: 5))
        .padding(.bottom, 5)
    }

    /// "✓" and "–" have no glyph in the game font and fall back to a thin system one,
    /// so they're drawn as heavy symbols that match the chunky numbers.
    @ViewBuilder
    private func statValue(_ stat: Stat) -> some View {
        switch stat.value {
        case "✓":
            Image(systemName: "checkmark").font(.system(size: 22, weight: .black)).foregroundStyle(stat.color.color)
        case "–":
            Capsule().fill(Palette.empty).frame(width: 18, height: 5)
        default:
            Text(stat.value).font(ChibiFont.title(24)).foregroundStyle(stat.color.color)
        }
    }

    private var ribbon: Text {
        guard content.ribbon.hasSuffix(" ✓") else { return Text(content.ribbon) }
        return Text(content.ribbon.dropLast(2)) + Text(" ")
            + Text(Image(systemName: "checkmark")).font(.system(size: 16, weight: .black))
    }

    private var scene: some View {
        ZStack(alignment: .bottom) {
            // Zoom into the rug so the pets stand on it: shows roughly 28%–61% of the picture's height.
            Image("bg_home")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 380, height: 675)
                .offset(y: 37)
                .frame(width: 300, height: 220)
                .clipped()
                // clipped() only trims the drawing: without this the full 675 pt picture
                // swallows taps on the template chips and switches around the card.
                .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: -6) {
                ForEach(Array(content.pets.enumerated()), id: \.element.id) { index, pet in
                    Image(pet.art)
                        .resizable()
                        .scaledToFit()
                        .frame(height: index == 1 || content.pets.count == 1 ? 120 : 100)
                        .scaleEffect(x: index == 2 ? -1 : 1)
                        .padding(.bottom, index == 1 ? 26 : 46)
                }
            }

            ribbon
                .font(ChibiFont.title(20))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .padding(.top, 5)
                .padding(.bottom, 3)
                .chibiPanel(RoundedRectangle(cornerRadius: 12, style: .continuous), fill: Palette.butter, shadow: 3)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 14)
        }
        .frame(width: 300, height: 220)
        .overlay(alignment: .bottom) { Palette.ink.frame(height: 3) }
    }
}

