import SwiftUI
import PetCore

/// A pet of the 3D方案 roster: one SVG outline turned into slices, with the 26 expressions.
/// Same 20 pets as `RosterPet` (plus Toast), except Espresso is Bubble Tea here; the
/// health side keeps calling it "espresso", so `rosterID` is what AppModel stores.
struct Pet3D: Identifiable, Hashable {
    /// The id in the 3D pet set (and in pet.html).
    let id: String
    /// The id AppModel and RosterPet use for this pet.
    let rosterID: String
    let name: String
    /// nil for Toast, the guide, who is there from day one.
    let activity: Activity?

    /// A still, front-facing picture (rendered from the same 3D pet), for grids and share cards.
    var still: String { "pet3d_\(id)" }
    /// The same picture with ^^ eyes.
    var happyStill: String { "pet3d_\(id)_happy" }

    /// In the order of the 3D roster: Toast, then the families.
    static let all: [Pet3D] = {
        let order = ["toast", "onigiri", "mantou", "baguette", "waffle", "coffee", "matcha", "espresso", "darkchoco",
                     "pudding", "marshmallow", "strawberrycake", "mochi", "avocado", "lemon", "chili", "pineapple",
                     "honey", "warmmilk", "proteinbar"]
        return order.compactMap { rosterID in
            guard let roster = RosterPet.pet(id: rosterID) else { return nil }
            if rosterID == "espresso" {
                return Pet3D(id: "bubbletea", rosterID: rosterID, name: "Bubble Tea", activity: roster.activity)
            }
            return Pet3D(id: rosterID, rosterID: rosterID, name: roster.name, activity: roster.activity)
        }
    }()

    static let toast = all[0]

    static func with(id: String) -> Pet3D? { all.first { $0.id == id } }
    static func with(rosterID: String) -> Pet3D? { all.first { $0.rosterID == rosterID } }
}

/// What the user has of one pet.
struct PetRecord {
    let pet: Pet3D
    let isUnlocked: Bool
    let level: Int
    /// 0...1 through the current level.
    let levelFraction: Double
    /// When the pet was unlocked (Toast: the adoption day).
    let unlockedOn: Date?
}

extension AppModel {
    func record(_ pet: Pet3D) -> PetRecord {
        guard let activity = pet.activity else {
            // Toast's level is your friendship with it (pats and treats).
            let progress = bond.progress
            return PetRecord(pet: pet, isUnlocked: true, level: max(1, bond.level),
                             levelFraction: progress.needed > 0 ? Double(progress.current) / Double(progress.needed) : 0,
                             unlockedOn: store.adoptedOn)
        }
        let p = progress(for: activity)
        return PetRecord(pet: pet, isUnlocked: p.isUnlocked, level: p.level, levelFraction: p.levelFraction, unlockedOn: p.unlockedOn)
    }

    /// Every pet, unlocked first (Toast, then highest level), locked ones after in roster order.
    var petRecords: [PetRecord] {
        let all = Pet3D.all.map(record)
        let unlocked = all.filter(\.isUnlocked).sorted { a, b in
            if a.pet.activity == nil { return true }
            if b.pet.activity == nil { return false }
            return a.level > b.level
        }
        return unlocked + all.filter { !$0.isUnlocked }
    }

    var unlockedPets: [Pet3D] { petRecords.filter(\.isUnlocked).map(\.pet) }

    /// The pet on the home stage. Any unlocked pet can be the main one (all 20 have 3D art).
    var mainPet3D: Pet3D {
        guard let pet = Pet3D.with(rosterID: mainPetID), record(pet).isUnlocked else { return .toast }
        return pet
    }
}

/// A pet's still picture; locked pets show only their silhouette.
struct PetPicture: View {
    let pet: Pet3D
    var locked = false
    var happy = false

    var body: some View {
        if locked {
            Image(pet.still)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(Jade.fill)
                .accessibilityLabel("Locked pet")
        } else {
            Image(happy ? pet.happyStill : pet.still)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .accessibilityLabel(pet.name)
        }
    }
}

extension Activity {
    /// SF Symbol for the activity, in the icon language of the v3 design.
    var icon: String {
        switch self {
        case .walking: "shoeprints.fill"
        case .onTimeSleep: "moon"
        case .earlyRise: "sunrise"
        case .mindfulness: "leaf"
        case .running: "figure.run"
        case .strength: "dumbbell"
        case .hiit: "bolt.heart"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .hiking: "figure.hiking"
        case .yoga: "figure.yoga"
        case .pilates: "figure.pilates"
        case .dance: "figure.dance"
        case .ballSports: "figure.basketball"
        case .climbing: "figure.climbing"
        case .other: "figure.mixed.cardio"
        case .recoveryMatch: "battery.75percent"
        case .sleepNeedMet: "bed.double"
        case .highStrain: "flame"
        }
    }
}

/// SF Symbol for a workout by its short name ("Run", "Yoga").
func workoutIcon(_ name: String?) -> String {
    guard let name else { return "figure.mixed.cardio" }
    if name.lowercased() == "walk" { return "figure.walk" }
    return Activity(workoutName: name).icon
}
