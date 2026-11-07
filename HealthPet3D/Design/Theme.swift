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
    static let ink2 = dynamic(0x6B7466, 0xA3A99C)
    static let ink3 = dynamic(0xA9ADA2, 0x646C5F)
    /// Workouts, check marks, today.
    static let accent = dynamic(0x4B6844, 0x8FAE85)
    /// Sleep, and the rest bars on home.
    static let sleep = dynamic(0xBDB65A, 0xD9D387)
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
    /// SF Pro Rounded, the app's only typeface.
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Corner radii and spacing shared by every page.
enum Metrics {
    static let card: CGFloat = 28
    static let tile: CGFloat = 22
    static let gutter: CGFloat = 16
    static let gap: CGFloat = 12
}
