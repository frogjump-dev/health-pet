import SwiftUI

/// Colours of the pet's room, taken from the toast art (crust, honey, ink) plus warm walls.
enum Palette {
    static let ink = Color(red: 0.20, green: 0.14, blue: 0.09)
    static let crust = Color(red: 0.78, green: 0.47, blue: 0.20)
    static let honey = Color(red: 0.98, green: 0.78, blue: 0.36)
    static let wallTop = Color(red: 0.97, green: 0.91, blue: 0.82)
    static let wallBottom = Color(red: 0.88, green: 0.76, blue: 0.60)
    static let floor = Color(red: 0.93, green: 0.84, blue: 0.71)
    static let night = Color(red: 0.12, green: 0.13, blue: 0.27)
}

/// Warm room with soft window light. Dims to night while the pet sleeps.
struct RoomBackground: View {
    var isNight: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Palette.wallTop, Palette.wallBottom], startPoint: .top, endPoint: .bottom)

                // Floor: a lighter band where the pet stands.
                Ellipse()
                    .fill(Palette.floor)
                    .frame(width: geo.size.width * 2.2, height: geo.size.height * 0.7)
                    .offset(y: geo.size.height * 0.42)
                    .blur(radius: 30)

                // Window light beams.
                ForEach(0..<3) { i in
                    Rectangle()
                        .fill(.white.opacity(0.22))
                        .frame(width: geo.size.width * 0.16, height: geo.size.height * 1.2)
                        .rotationEffect(.degrees(-28))
                        .offset(x: geo.size.width * (CGFloat(i) * 0.22 - 0.05), y: -geo.size.height * 0.1)
                        .blur(radius: 22)
                }

                Palette.night.opacity(isNight ? 0.35 : 0)
            }
            .animation(.easeInOut(duration: 1.2), value: isNight)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Frosted, slightly milky panel used for the top bar and the action cards.
    func glass<S: Shape>(_ shape: S) -> some View {
        background(shape.fill(.white.opacity(0.38)))
            .overlay(shape.stroke(.white.opacity(0.75), lineWidth: 1.2))
            .shadow(color: Palette.ink.opacity(0.08), radius: 10, y: 4)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
