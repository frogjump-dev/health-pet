import SwiftUI

/// The four breakfast families of the roster, one per MBTI temperament and RPG class.
enum PetFamily: String, CaseIterable, Identifiable {
    case grain, brew, sweet, fruit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grain: "Grain Guards"
        case .brew: "Brew Mages"
        case .sweet: "Sweet Healers"
        case .fruit: "Fruit Fighters"
        }
    }

    /// Short class name for chips.
    var className: String {
        switch self {
        case .grain: "Grain Guard"
        case .brew: "Brew Mage"
        case .sweet: "Sweet Healer"
        case .fruit: "Fruit Fighter"
        }
    }

    var tagline: String {
        switch self {
        case .grain: "steady routine"
        case .brew: "night owls turned early birds"
        case .sweet: "rest & recovery"
        case .fruit: "high energy"
        }
    }

    /// Card fill for pets of this family.
    var tint: Color {
        switch self {
        case .grain: Color(red: 1.00, green: 0.91, blue: 0.65)
        case .brew: Color(red: 0.89, green: 0.84, blue: 0.98)
        case .sweet: Color(red: 1.00, green: 0.83, blue: 0.80)
        case .fruit: Color(red: 0.80, green: 0.92, blue: 0.78)
        }
    }

    /// Title colour for this family's section.
    var accent: Color {
        switch self {
        case .grain: Color(red: 0.73, green: 0.51, blue: 0.10)
        case .brew: Color(red: 0.48, green: 0.36, blue: 0.78)
        case .sweet: Color(red: 0.82, green: 0.38, blue: 0.35)
        case .fruit: Color(red: 0.31, green: 0.60, blue: 0.36)
        }
    }
}

/// A pet from the breakfast roster (side-facing chibi art, template v2).
/// Art faces screen-right; the home scene mirrors pets standing on the right.
/// `image` is nil while the pet's side-facing art isn't drawn yet.
struct RosterPet: Identifiable, Equatable {
    let id: String
    let name: String
    let image: String?
    let mbti: String
    /// nil for Toast, the guide, who sits outside the 16.
    let family: PetFamily?

    /// Art for places that always need a picture (the guide never lacks one).
    var art: String { image ?? "pet_toast" }

    static let toast = RosterPet(id: "toast", name: "Toast", image: "pet_toast", mbti: "guide", family: nil)
    static let coffee = RosterPet(id: "coffee", name: "Coffee Bean", image: "pet_coffee", mbti: "INTJ", family: .brew)
    static let pudding = RosterPet(id: "pudding", name: "Pudding", image: "pet_pudding", mbti: "INFJ", family: .sweet)
    static let chili = RosterPet(id: "chili", name: "Chili", image: "pet_chili", mbti: "ESTP", family: .fruit)
    static let onigiri = RosterPet(id: "onigiri", name: "Onigiri", image: "pet_onigiri", mbti: "ISTJ", family: .grain)

    static let starters = [toast, coffee, pudding, chili, onigiri]

    /// All 16 collectable pets, four per family. English names are placeholders until naming is decided.
    static let roster: [RosterPet] = [
        onigiri,
        RosterPet(id: "mantou", name: "Mantou", image: nil, mbti: "ISFJ", family: .grain),
        RosterPet(id: "baguette", name: "Baguette", image: nil, mbti: "ESTJ", family: .grain),
        RosterPet(id: "waffle", name: "Waffle", image: nil, mbti: "ESFJ", family: .grain),
        coffee,
        RosterPet(id: "matcha", name: "Matcha", image: nil, mbti: "INTP", family: .brew),
        RosterPet(id: "espresso", name: "Espresso", image: nil, mbti: "ENTJ", family: .brew),
        RosterPet(id: "darkchoco", name: "Dark Choco", image: nil, mbti: "ENTP", family: .brew),
        pudding,
        RosterPet(id: "marshmallow", name: "Marshmallow", image: nil, mbti: "INFP", family: .sweet),
        RosterPet(id: "strawberrycake", name: "Strawberry Cake", image: nil, mbti: "ENFJ", family: .sweet),
        RosterPet(id: "mochi", name: "Mochi", image: nil, mbti: "ENFP", family: .sweet),
        RosterPet(id: "avocado", name: "Avocado", image: nil, mbti: "ISTP", family: .fruit),
        RosterPet(id: "lemon", name: "Lemon", image: nil, mbti: "ISFP", family: .fruit),
        chili,
        RosterPet(id: "pineapple", name: "Pineapple", image: nil, mbti: "ESFP", family: .fruit),
    ]

    static func pet(id: String) -> RosterPet? {
        id == toast.id ? toast : roster.first { $0.id == id }
    }
}
