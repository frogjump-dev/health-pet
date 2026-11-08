import Foundation
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
}

/// A pet from the breakfast roster: its name, family and activity. How it looks in the 3D
/// app is in Pet3D. Each of the 16 is bound to one activity (2026-11-02): do it once to
/// unlock the pet, and the pet's level shows how much of it you've done. MBTI is personality
/// text only.
struct RosterPet: Identifiable, Equatable {
    let id: String
    let name: String
    let mbti: String
    /// nil for Toast, the guide, who sits outside the 16.
    let family: PetFamily?
    /// nil for Toast, who is with you from day one.
    var activity: Activity? = nil

    static let toast = RosterPet(id: "toast", name: "Toast", mbti: "guide", family: nil)
    static let coffee = RosterPet(id: "coffee", name: "Coffee Bean", mbti: "INTJ", family: .brew, activity: .earlyRise)
    static let pudding = RosterPet(id: "pudding", name: "Pudding", mbti: "INFJ", family: .sweet, activity: .yoga)
    static let chili = RosterPet(id: "chili", name: "Chili", mbti: "ESTP", family: .fruit, activity: .running)
    static let onigiri = RosterPet(id: "onigiri", name: "Onigiri", mbti: "ISTJ", family: .grain, activity: .walking)

    /// All collectable pets: 16 in four families of four, plus the 3 Whoop-only pets. English names are placeholders until naming is decided.
    static let roster: [RosterPet] = [
        onigiri,
        RosterPet(id: "mantou", name: "Mantou", mbti: "ISFJ", family: .grain, activity: .onTimeSleep),
        RosterPet(id: "baguette", name: "Baguette", mbti: "ESTJ", family: .grain, activity: .strength),
        RosterPet(id: "waffle", name: "Waffle", mbti: "ESFJ", family: .grain, activity: .other),
        coffee,
        RosterPet(id: "matcha", name: "Matcha", mbti: "INTP", family: .brew, activity: .mindfulness),
        RosterPet(id: "espresso", name: "Espresso", mbti: "ENTJ", family: .brew, activity: .hiit),
        RosterPet(id: "darkchoco", name: "Dark Choco", mbti: "ENTP", family: .brew, activity: .climbing),
        pudding,
        RosterPet(id: "marshmallow", name: "Marshmallow", mbti: "INFP", family: .sweet, activity: .swimming),
        RosterPet(id: "strawberrycake", name: "Strawberry Cake", mbti: "ENFJ", family: .sweet, activity: .dance),
        RosterPet(id: "mochi", name: "Mochi", mbti: "ENFP", family: .sweet, activity: .pilates),
        RosterPet(id: "avocado", name: "Avocado", mbti: "ISTP", family: .fruit, activity: .cycling),
        RosterPet(id: "lemon", name: "Lemon", mbti: "ISFP", family: .fruit, activity: .hiking),
        chili,
        RosterPet(id: "pineapple", name: "Pineapple", mbti: "ESFP", family: .fruit, activity: .ballSports),
        // Whoop only, no MBTI.
        RosterPet(id: "honey", name: "Honey", mbti: "", family: .supply, activity: .recoveryMatch),
        RosterPet(id: "warmmilk", name: "Warm Milk", mbti: "", family: .supply, activity: .sleepNeedMet),
        RosterPet(id: "proteinbar", name: "Protein Bar", mbti: "", family: .supply, activity: .balancedStreak),
    ]

    static func pet(for activity: Activity) -> RosterPet {
        roster.first { $0.activity == activity }!
    }

    static func pet(id: String) -> RosterPet? {
        id == toast.id ? toast : roster.first { $0.id == id }
    }
}
