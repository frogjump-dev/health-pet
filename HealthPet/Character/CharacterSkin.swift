import SwiftUI
import PetCore

/// A character is only a "skin" over `PetState`. The health logic never knows which
/// character is shown, so the toast can be redesigned or replaced without touching it.
protocol CharacterSkin {
    var id: String { get }
    var displayName: String { get }
    /// Renders the character for a state. Today: static images; later: a Rive rig.
    func makeView(state: PetState) -> AnyView
    /// One short, warm line for the home screen. Never a number.
    func greeting(for state: PetState) -> String
}

enum CharacterCatalog {
    static let all: [any CharacterSkin] = [ToastSkin()]
    static let defaultSkin: any CharacterSkin = ToastSkin()

    static func skin(id: String) -> any CharacterSkin {
        all.first { $0.id == id } ?? defaultSkin
    }
}
