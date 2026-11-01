import SwiftUI
import PetCore

/// 「面包人」: a slice of toast, the tutorial guide. Side-facing chibi art (template v2);
/// moods show through the bubble line and motion until the expression layer lands.
struct ToastSkin: CharacterSkin {
    let id = "toast-v2"
    let displayName = "Toast"

    func makeView(state: PetState) -> AnyView {
        AnyView(ToastView(state: state))
    }

    func greeting(for state: PetState) -> String {
        if state.isAsleep { return "Shh… toasting quietly till morning." }
        switch state.mood {
        case .golden: return "Perfectly golden today. Let's go."
        case .burnt:  return "A little crispy around the edges. Early night together?"
        case .soggy:  return "Bit soggy today. Taking it easy is the move."
        case .fresh:  return "Fresh out of the toaster! Fully charged."
        }
    }
}

private struct ToastView: View {
    let state: PetState
    @State private var bob = false

    var body: some View {
        Image(RosterPet.toast.image)
            .resizable()
            .scaledToFit()
            .saturation(state.isAsleep ? 0.4 : 1)
            .opacity(state.isAsleep ? 0.75 : 1)
            .offset(y: bob ? -6 : 6)
            .animation(.easeInOut(duration: state.mood == .soggy ? 2.4 : 1.2).repeatForever(autoreverses: true), value: bob)
            .overlay(alignment: .topTrailing) {
                if state.isAsleep {
                    Text("z z z")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .onAppear { bob = true }
            .accessibilityLabel("Toast, feeling \(state.mood.rawValue)")
    }
}
