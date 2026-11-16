import SwiftUI

// The app's own small controls (bubble-settings-v1, decided 2026-11-16): they replace the system
// switch, menus, spinner and sheet chrome, so every page speaks the same v3 「干净版」.

// MARK: - 小脸开关: the switch

/// A switch with a face on its knob: eyes closed when off, open when on. Flipping it slides the
/// knob with a little overshoot and squishes it softly (a light tap with it, when haptics are on).
/// Reduce Motion: it only slides.
struct FaceToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 8)
                FaceSwitch(isOn: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

extension ToggleStyle where Self == FaceToggleStyle {
    static var face: FaceToggleStyle { FaceToggleStyle() }
}

/// The switch itself, 50 × 30: jade when on, grey when off.
struct FaceSwitch: View {
    let isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Squish {
        var x: CGFloat = 1
        var y: CGFloat = 1
    }

    var body: some View {
        Capsule()
            .fill(isOn ? Jade.accent : Jade.switchOff)
            .frame(width: 50, height: 30)
            .overlay(alignment: isOn ? .trailing : .leading) {
                knob.padding(3)
            }
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.28, dampingFraction: 0.62), value: isOn)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: isOn) { _, _ in FeelSettings.haptics }
    }

    private var knob: some View {
        let still = reduceMotion
        return ZStack {
            Circle().fill(Jade.knob).shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
            HStack(spacing: 5) {
                eye
                eye
            }
        }
        .frame(width: 24, height: 24)
        .keyframeAnimator(initialValue: Squish(), trigger: isOn) { view, s in
            view.scaleEffect(x: still ? 1 : s.x, y: still ? 1 : s.y)
        } keyframes: { _ in
            KeyframeTrack(\.x) {
                LinearKeyframe(1, duration: 0.05)
                CubicKeyframe(1.22, duration: 0.12)
                CubicKeyframe(0.94, duration: 0.12)
                CubicKeyframe(1, duration: 0.12)
            }
            KeyframeTrack(\.y) {
                LinearKeyframe(1, duration: 0.05)
                CubicKeyframe(0.82, duration: 0.12)
                CubicKeyframe(1.06, duration: 0.12)
                CubicKeyframe(1, duration: 0.12)
            }
        }
    }

    /// Open: a small upright pill. Closed: a short flat line, a little lower.
    private var eye: some View {
        RoundedRectangle(cornerRadius: isOn ? 1.5 : 1)
            .fill(isOn ? Color(UIColor(hex: 0x2D392A)) : Color(UIColor(hex: 0x7D857A)))
            .frame(width: isOn ? 3 : 5, height: isOn ? 6 : 2)
            .offset(y: isOn ? 0 : 1)
    }
}

// MARK: - Choice chips

/// Two or three small capsules, one picked (dark) at a time: Every night / Weekends apart,
/// 22:48 / 10:48 PM, Real data / Demo.
struct ChoiceChips<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 5) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let picked = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.title)
                        .scaledFont(13, .heavy)
                        .lineLimit(1)
                        .foregroundStyle(picked ? Jade.onPrimary : Jade.ink2)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 30)
                        .background(Capsule().fill(picked ? Jade.primary : Jade.fill))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .fixedSize()
        .animation(.easeOut(duration: 0.15), value: selection)
        .sensoryFeedback(.selection, trigger: selection) { _, _ in FeelSettings.haptics }
    }
}

/// A small capsule button: dark (Connect) or the grey fill (a quiet choice).
struct SmallPillStyle: ButtonStyle {
    var primary = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(14, .heavy)
            .foregroundStyle(primary ? Jade.onPrimary : Jade.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 32)
            .background(Capsule().fill(primary ? Jade.primary : Jade.fill))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Pop-up cards

/// The card a small pop-up sits on: card colour, corner 22, a soft lift.
struct PopCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(6)
            .background(RoundedRectangle(cornerRadius: Metrics.tile, style: .continuous).fill(Jade.card))
            .shadow(color: Jade.popShadow, radius: 15, y: 10)
    }
}

extension View {
    func popCard() -> some View { modifier(PopCardBackground()) }

    /// Pops a card in like the food bubbles (from 0.82, a little overshoot) from the corner of its
    /// button, and fades it out.
    func popIn(from anchor: UnitPoint) -> some View {
        transition(.asymmetric(insertion: .scale(scale: 0.82, anchor: anchor).combined(with: .opacity),
                               removal: .opacity))
    }
}

/// One row in a pop-up menu: a small icon square, the name, an optional chevron.
struct PopMenuRow: View {
    let icon: String
    let title: String
    var chevron = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconSquare(systemName: icon)
                Text(title).scaledFont(16, .semibold).foregroundStyle(Jade.ink)
                Spacer(minLength: 8)
                if chevron {
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Jade.ink2)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(PopRowPress())
    }
}

/// A row darkens to the canvas under the finger.
struct PopRowPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(configuration.isPressed ? Jade.canvas : .clear))
    }
}

/// A 30 pt rounded square with an icon: the start of a menu row.
struct IconSquare: View {
    let systemName: String
    var tint: Color = Jade.ink

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Jade.fill))
            .accessibilityHidden(true)
    }
}

/// A thin line between rows, kept off the card's edges.
struct PopDivider: View {
    var body: some View {
        Rectangle().fill(Jade.fill).frame(height: 1).padding(.horizontal, 12)
    }
}

// MARK: - Sheets

/// The bottom sheets (the week card, 「手表记错了」, the time wheel): card colour, corner 28 and a
/// light handle of our own instead of the system's.
struct JadeSheet: ViewModifier {
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                Capsule()
                    .fill(Jade.ink3.opacity(0.6))
                    .frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .accessibilityHidden(true)
            }
            .presentationBackground(Jade.card)
            .presentationCornerRadius(Metrics.card)
            .presentationDragIndicator(.hidden)
    }
}

extension View {
    func jadeSheet() -> some View { modifier(JadeSheet()) }
}

// MARK: - Waiting

/// Three small dots hopping one after another (instead of the system spinner).
struct HopDots: View {
    var color: Color = Jade.onPrimary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.33 : nil)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .offset(y: reduceMotion ? 0 : -6 * hop((t - Double(index) * 0.13).truncatingRemainder(dividingBy: 1)))
                        .opacity(reduceMotion ? (0.4 + 0.6 * pulse(t, index)) : 1)
                }
            }
            .frame(height: 14)
        }
        .accessibilityLabel("Loading")
    }

    /// Up and back within the first 60% of each second, eased.
    private func hop(_ phase: Double) -> Double {
        let p = phase < 0 ? phase + 1 : phase
        guard p < 0.6 else { return 0 }
        return sin(p / 0.6 * .pi)
    }

    /// Reduce Motion: the dots only brighten in turn.
    private func pulse(_ t: Double, _ index: Int) -> Double {
        Int(t * 3) % 3 == index ? 1 : 0
    }
}
