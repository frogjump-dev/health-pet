import SwiftUI
import PetCore

/// The four breakfast families of the roster (by food type; MBTI is personality text only).
enum PetFamily: String, CaseIterable, Identifiable {
    case grain, brew, sweet, fruit
    /// 补给小队: the three Whoop-only pets.
    case supply

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grain: "Grain Guards"
        case .brew: "Brew Mages"
        case .sweet: "Sweet Healers"
        case .fruit: "Fruit Fighters"
        case .supply: "Supply Squad"
        }
    }

    /// Short class name for chips.
    var className: String {
        switch self {
        case .grain: "Grain Guard"
        case .brew: "Brew Mage"
        case .sweet: "Sweet Healer"
        case .fruit: "Fruit Fighter"
        case .supply: "Supply Squad"
        }
    }

    var tagline: String {
        switch self {
        case .grain: "bread & rice"
        case .brew: "coffee & tea"
        case .sweet: "desserts"
        case .fruit: "fruit & spice"
        case .supply: "Whoop only"
        }
    }

    /// Card fill for pets of this family.
    var tint: Color {
        switch self {
        case .grain: Color(red: 1.00, green: 0.91, blue: 0.65)
        case .brew: Color(red: 0.89, green: 0.84, blue: 0.98)
        case .sweet: Color(red: 1.00, green: 0.83, blue: 0.80)
        case .fruit: Color(red: 0.80, green: 0.92, blue: 0.78)
        case .supply: Color(red: 0.80, green: 0.90, blue: 0.97)
        }
    }

    /// Title colour for this family's section.
    var accent: Color {
        switch self {
        case .grain: Color(red: 0.73, green: 0.51, blue: 0.10)
        case .brew: Color(red: 0.48, green: 0.36, blue: 0.78)
        case .sweet: Color(red: 0.82, green: 0.38, blue: 0.35)
        case .fruit: Color(red: 0.31, green: 0.60, blue: 0.36)
        case .supply: Color(red: 0.20, green: 0.45, blue: 0.68)
        }
    }
}

/// A pet from the breakfast roster (side-facing chibi art, template v2).
/// Art faces screen-right; the home scene mirrors pets standing on the right.
/// `image` is nil while the pet's side-facing art isn't drawn yet.
/// Each of the 16 is bound to one activity (2026-11-02): do it once to unlock the pet,
/// and the pet's level shows how much of it you've done. MBTI is personality text only.
struct RosterPet: Identifiable, Equatable {
    let id: String
    let name: String
    let image: String?
    let mbti: String
    /// nil for Toast, the guide, who sits outside the 16.
    let family: PetFamily?
    /// nil for Toast, who is with you from day one.
    var activity: Activity? = nil

    /// Art for places that always need a picture (the guide never lacks one).
    var art: String { image ?? "pet_toast" }

    static let toast = RosterPet(id: "toast", name: "Toast", image: "pet_toast", mbti: "guide", family: nil)
    static let coffee = RosterPet(id: "coffee", name: "Coffee Bean", image: "pet_coffee", mbti: "INTJ", family: .brew, activity: .earlyRise)
    static let pudding = RosterPet(id: "pudding", name: "Pudding", image: "pet_pudding", mbti: "INFJ", family: .sweet, activity: .yoga)
    static let chili = RosterPet(id: "chili", name: "Chili", image: "pet_chili", mbti: "ESTP", family: .fruit, activity: .running)
    static let onigiri = RosterPet(id: "onigiri", name: "Onigiri", image: "pet_onigiri", mbti: "ISTJ", family: .grain, activity: .walking)

    /// All collectable pets: 16 in four families of four, plus the 3 Whoop-only pets. English names are placeholders until naming is decided.
    static let roster: [RosterPet] = [
        onigiri,
        RosterPet(id: "mantou", name: "Mantou", image: nil, mbti: "ISFJ", family: .grain, activity: .onTimeSleep),
        RosterPet(id: "baguette", name: "Baguette", image: nil, mbti: "ESTJ", family: .grain, activity: .strength),
        RosterPet(id: "waffle", name: "Waffle", image: nil, mbti: "ESFJ", family: .grain, activity: .other),
        coffee,
        RosterPet(id: "matcha", name: "Matcha", image: nil, mbti: "INTP", family: .brew, activity: .mindfulness),
        RosterPet(id: "espresso", name: "Espresso", image: nil, mbti: "ENTJ", family: .brew, activity: .hiit),
        RosterPet(id: "darkchoco", name: "Dark Choco", image: nil, mbti: "ENTP", family: .brew, activity: .climbing),
        pudding,
        RosterPet(id: "marshmallow", name: "Marshmallow", image: nil, mbti: "INFP", family: .sweet, activity: .swimming),
        RosterPet(id: "strawberrycake", name: "Strawberry Cake", image: nil, mbti: "ENFJ", family: .sweet, activity: .dance),
        RosterPet(id: "mochi", name: "Mochi", image: nil, mbti: "ENFP", family: .sweet, activity: .pilates),
        RosterPet(id: "avocado", name: "Avocado", image: nil, mbti: "ISTP", family: .fruit, activity: .cycling),
        RosterPet(id: "lemon", name: "Lemon", image: nil, mbti: "ISFP", family: .fruit, activity: .hiking),
        chili,
        RosterPet(id: "pineapple", name: "Pineapple", image: nil, mbti: "ESFP", family: .fruit, activity: .ballSports),
        // Whoop only, no MBTI. Art will be pet_honey / pet_warmmilk / pet_proteinbar.
        RosterPet(id: "honey", name: "Honey", image: nil, mbti: "", family: .supply, activity: .recoveryMatch),
        RosterPet(id: "warmmilk", name: "Warm Milk", image: nil, mbti: "", family: .supply, activity: .sleepNeedMet),
        RosterPet(id: "proteinbar", name: "Protein Bar", image: nil, mbti: "", family: .supply, activity: .highStrain),
    ]

    static func pet(for activity: Activity) -> RosterPet {
        roster.first { $0.activity == activity }!
    }

    static func pet(id: String) -> RosterPet? {
        id == toast.id ? toast : roster.first { $0.id == id }
    }
}

extension Activity {
    /// SF Symbol standing in for a pet whose art isn't drawn yet, and for activity chips.
    var symbol: String {
        switch self {
        case .walking: "figure.walk"
        case .onTimeSleep: "moon.zzz.fill"
        case .earlyRise: "sunrise.fill"
        case .mindfulness: "brain.head.profile"
        case .running: "figure.run"
        case .strength: "dumbbell.fill"
        case .hiit: "bolt.heart.fill"
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
        case .sleepNeedMet: "bed.double.fill"
        case .highStrain: "flame.fill"
        }
    }
}
