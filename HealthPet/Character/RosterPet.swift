import Foundation

/// A pet from the breakfast roster (side-facing chibi art, template v2).
/// Art faces screen-right; the home scene mirrors pets standing on the right.
struct RosterPet: Identifiable, Equatable {
    let id: String
    let name: String
    let image: String
    let mbti: String

    static let toast = RosterPet(id: "toast", name: "Toast", image: "pet_toast", mbti: "guide")
    static let coffee = RosterPet(id: "coffee", name: "Coffee Bean", image: "pet_coffee", mbti: "INTJ")
    static let pudding = RosterPet(id: "pudding", name: "Pudding", image: "pet_pudding", mbti: "INFJ")
    static let chili = RosterPet(id: "chili", name: "Chili", image: "pet_chili", mbti: "ESTP")
    static let onigiri = RosterPet(id: "onigiri", name: "Onigiri", image: "pet_onigiri", mbti: "ISTJ")

    static let starters = [toast, coffee, pudding, chili, onigiri]
}
