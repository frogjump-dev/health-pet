import SwiftUI
import PetCore

/// A character is only a "skin" over `PetState`. The health logic never knows which
/// character is shown, so the toast can be redesigned or replaced without touching it.
protocol CharacterSkin {
    var id: String { get }
    var displayName: String { get }
    /// Renders the character for a state. `reactions` goes up by one on every pat or
    /// treat, so a skin can play its own reaction (a hop, a happy clip, …).
    func makeView(state: PetState, reactions: Int) -> AnyView
    /// One short, warm line for the home screen. Never a number.
    func greeting(for state: PetState) -> String
}

enum CharacterCatalog {
    static let all: [any CharacterSkin] = [Toast3DSkin(), ToastSkin()]
    static let defaultSkin: any CharacterSkin = Toast3DSkin()

    static func skin(id: String) -> any CharacterSkin {
        all.first { $0.id == id } ?? defaultSkin
    }
}
