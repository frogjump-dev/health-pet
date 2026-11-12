import SwiftUI
import UIKit

/// The v3 「干净版」 palette: Mountain Jade by day, 森林夜 by night.
/// Colour is the legend: jade = workouts, lime = sleep, grey = not yet.
enum Jade {
    static let canvas = dynamic(0xEBE9E3, 0x121611)
    static let card = dynamic(0xF8F6F3, 0x1D231B)
    /// Secondary buttons, tracks, empty dots.
    static let fill = dynamic(0xE2DFD7, 0x272F25)
    static let ink = dynamic(0x2D392A, 0xEBE9E3)
    /// Secondary text, and every always-visible label (PRD v0.3 §8.1: 4.6 on the canvas by day).
    static let ink2 = dynamic(0x626B5D, 0xA3A99C)
    /// Inactive: dividers, decoration and days still to come, never a label (night 4.9).
    static let ink3 = dynamic(0xA9ADA2, 0x7E877A)
    /// The 1 pt outline of an empty week cell (3.1 by day).
    static let cellStroke = dynamic(0x7D857A, 0x7D857A)
    /// The 1 pt outline of lime on the canvas (a filled night cell, Whoop's recovery bar): by day
    /// only, lime is bright enough on the night canvas.
    static let limeStroke = Color(UIColor { $0.userInterfaceStyle == .dark ? .clear : UIColor(hex: 0x8A8331) })
    /// Workouts, check marks, today.
    static let accent = dynamic(0x4B6844, 0x8FAE85)
    /// Sleep, and the rest bar on home.
    static let sleep = dynamic(0xBDB65A, 0xD9D387)
    /// Lime as text and small icons on a card (the moon bubble's time): the day lime is deepened
    /// so it stays readable on the card.
    static let sleepText = dynamic(0x8A8331, 0xD9D387)
    /// Whoop strain on its bubble: grey, it books into no cell.
    static let load = dynamic(0x7D857A, 0xA3A99C)
    /// The tour's dimming (58% forest by day, 66% black at night).
    static let scrim = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor.black.withAlphaComponent(0.66) : UIColor(hex: 0x2D392A).withAlphaComponent(0.58) })
    /// Text and icons on `sleep` (the share card's stamp).
    static let onSleep = dynamic(0x2D392A, 0x1A2018)
    static let primary = dynamic(0x2D392A, 0xD9D387)
    /// Text and icons on `primary`.
    static let onPrimary = dynamic(0xD9D387, 0x1D231B)
    /// Text on `accent` (the today circle, check badges).
    static let onAccent = dynamic(0xF8F6F3, 0x121611)
    static let shadow = Color.black

    /// The same colours as hex, for the pet's web view (floor and shadow tints).
    static func canvasHex(dark: Bool) -> String { dark ? "#121611" : "#EBE9E3" }
    static func cardHex(dark: Bool) -> String { dark ? "#1D231B" : "#F8F6F3" }

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Font {
    /// SF Pro Rounded, the app's only typeface, at a fixed size (the share card, the pet grid).
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// SF Pro Rounded that grows with the system text size like body text (PRD v0.3 §8.2: Today,
/// Memories, Settings and the first open follow it; home is capped two steps up).
private struct ScaledRounded: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.rounded(size, weight))
    }
}

extension View {
    /// `.font(.rounded(size, weight))` that follows Dynamic Type.
    func scaledFont(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> some View {
        modifier(ScaledRounded(size: size, weight: weight))
    }
}

/// Corner radii and spacing shared by every page.
enum Metrics {
    static let card: CGFloat = 28
    static let tile: CGFloat = 22
    static let gutter: CGFloat = 16
    static let gap: CGFloat = 12
}
