import SwiftUI
import PetCore

/// v1 character 「面包人」: a slice of toast. Art from the final state sheet
/// (character/toast-final-v1-wink.png), cut into one image per mood.
struct ToastSkin: CharacterSkin {
    let id = "toast-v1"
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

    func moodLabel(for state: PetState) -> String {
        if state.isAsleep { return "Sleeping" }
        switch state.mood {
        case .golden: return "Golden"
        case .burnt:  return "A bit crispy"
        case .soggy:  return "Soggy"
        case .fresh:  return "Fresh"
        }
    }

    static func imageName(for mood: PetMood) -> String {
        "toast_\(mood.rawValue)"
    }
}

private struct ToastView: View {
    let state: PetState
    @State private var bob = false

    var body: some View {
        Image(ToastSkin.imageName(for: state.mood))
            .resizable()
            .scaledToFit()
            // The art sits on white paper; multiply lets the warm room show through it.
            .blendMode(.multiply)
            // Fade the paper's edges so no rectangle shows on tinted backgrounds.
            .mask { Rectangle().padding(10).blur(radius: 8) }
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
