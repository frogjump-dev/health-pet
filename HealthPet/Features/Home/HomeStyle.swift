import SwiftUI

/// Colours of the 2D chibi style: thick ink outlines, flat fills, one hard shadow.
enum Palette {
    static let ink = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let inkSoft = Color(red: 0.47, green: 0.39, blue: 0.31)
    static let crust = Color(red: 0.78, green: 0.47, blue: 0.20)
    static let honey = Color(red: 0.98, green: 0.78, blue: 0.36)
    static let cream = Color(red: 1.00, green: 0.97, blue: 0.91)
    static let creamDeep = Color(red: 1.00, green: 0.93, blue: 0.80)
    static let butter = Color(red: 1.00, green: 0.79, blue: 0.24)
    static let empty = Color(red: 0.89, green: 0.85, blue: 0.78)
    static let mint = Color(red: 0.59, green: 0.84, blue: 0.63)
    static let mintDeep = Color(red: 0.35, green: 0.67, blue: 0.41)
    static let coral = Color(red: 1.00, green: 0.55, blue: 0.43)
    static let lavender = Color(red: 0.73, green: 0.63, blue: 0.94)
    static let alert = Color(red: 0.94, green: 0.33, blue: 0.27)
    static let night = Color(red: 0.12, green: 0.13, blue: 0.27)
}

/// Bundled game fonts (Resources/Fonts, SIL OFL). Fixed sizes: the layout is drawn for iPhone 18.
enum ChibiFont {
    /// Lilita One: titles, numbers and button labels.
    static func title(_ size: CGFloat) -> Font { .custom("LilitaOne", fixedSize: size) }
    /// Baloo 2 ExtraBold: speech bubbles and small labels.
    static func bold(_ size: CGFloat) -> Font { .custom("Baloo2-ExtraBold", fixedSize: size) }
    /// Baloo 2 SemiBold: captions.
    static func body(_ size: CGFloat) -> Font { .custom("Baloo2-SemiBold", fixedSize: size) }
}

extension View {
    /// Flat panel with a thick ink outline and a hard drop shadow.
    func chibiPanel<S: InsettableShape>(_ shape: S, fill: Color = Palette.cream, shadow: CGFloat = 4, line: CGFloat = 3) -> some View {
        background {
            ZStack {
                shape.fill(Palette.ink).offset(y: shadow)
                shape.fill(fill)
                shape.strokeBorder(Palette.ink, lineWidth: line)
            }
        }
    }
}

/// White button label with an ink outline, like a mobile game.
struct OutlinedText: View {
    let text: String
    var font: Font = ChibiFont.title(13.5)
    var outline: CGFloat = 2
    /// Extra letter spacing so the ink outline doesn't crowd the letters at big sizes.
    var tracking: CGFloat = 0

    var body: some View {
        let offsets: [CGSize] = (0..<8).map { i in
            let angle = Double(i) * .pi / 4
            return CGSize(width: cos(angle) * outline, height: sin(angle) * outline)
        }
        ZStack {
            ForEach(offsets.indices, id: \.self) { i in
                Text(text).font(font).tracking(tracking).foregroundStyle(Palette.ink).offset(offsets[i])
            }
            Text(text).font(font).tracking(tracking).foregroundStyle(.white)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Small red notification dot.
struct AlertDot: View {
    var size: CGFloat = 14

    var body: some View {
        Circle()
            .fill(Palette.alert)
            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
            .frame(width: size, height: size)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
