import SwiftUI
import PetCore

/// The wardrobe's own colours (Dress up design v1, 2026-11-12).
enum Wardrobe {
    /// The round backing under an item's picture: light at night too, so dark hats and beards
    /// stay readable.
    static let well = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xE6E2D8) : UIColor(hex: 0xECE9E2) })
    /// Items not drawn yet: their silhouette.
    static let silhouette = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x39423A) : UIColor(hex: 0xD6D2C8) })
    /// The gift box's ribbon, and the new-item dot.
    static let lime = Color(UIColor(hex: 0xD9D387))
}

/// What the gift card shows: a draw, or the welcome gift after the tour.
struct GiftReveal: Identifiable, Equatable {
    let item: String
    /// The free party hat after the tour: "A welcome gift", then "Put it on 〈pet〉".
    var welcome = false
    /// Who the button puts it on.
    let petName: String
    var id: String { item }
}

/// The gift card (D06, D07, D11, D12): a box that wobbles every 2.2 s until it is tapped open;
/// the lid flies off (0.45 s), the item pops out (0.55 s) with 14 confetti dots (0.8 s); then its
/// name, its slot and how many are collected, and Wear on 〈pet〉 / Later. Reduce Motion: no
/// wobble or confetti, the item simply fades in. A success tap when it opens.
struct GiftSheet: View {
    let gift: GiftReveal
    /// After this gift.
    let collected: Int
    let pointsLeft: Int
    let wear: () -> Void
    let later: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened = false
    @State private var revealed = false
    @State private var popped = false
    @State private var wobble = 0
    @State private var opens = 0

    private var decor: Decor? { Decor.with(id: gift.item) }
    private var last: Bool { !gift.welcome && collected >= Decor.all.count }

    var body: some View {
        ZStack {
            Jade.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}   // the card waits for the gift to be opened
                .accessibilityHidden(true)
            card
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .sensoryFeedback(.success, trigger: opens)
        #if DEBUG
        // simulator screenshots: -hp3dGiftOpen YES opens the box by itself
        .task {
            guard UserDefaults.standard.bool(forKey: "hp3dGiftOpen") else { return }
            try? await Task.sleep(for: .seconds(0.9))
            open()
        }
        #endif
    }

    private var card: some View {
        Group {
            if revealed { reveal.transition(.opacity) } else { box.transition(.opacity) }
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(width: 338)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Jade.card))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Step 1: the box

    private var box: some View {
        VStack(spacing: 6) {
            Text(gift.welcome ? "A welcome gift" : "Your draw is ready")
                .scaledFont(22, .bold)
                .foregroundStyle(Jade.ink)
            Text(gift.welcome
                 ? "For \(gift.petName), for joining in. Every day you open Ovenpals adds a point toward the next one."
                 : "\(DressUp.drawCost) pts used · \(pointsLeft) left")
                .scaledFont(14, .medium)
                .foregroundStyle(Jade.ink2)
            Button(action: open) {
                GiftBox(lidOff: opened)
                    .frame(width: 168, height: 168)
                    .keyframeAnimator(initialValue: 0.0, trigger: wobble) { view, angle in
                        view.rotationEffect(.degrees(angle), anchor: .bottom)
                    } keyframes: { _ in
                        KeyframeTrack {
                            CubicKeyframe(-5, duration: 0.12)
                            CubicKeyframe(5, duration: 0.16)
                            CubicKeyframe(-3, duration: 0.14)
                            CubicKeyframe(0, duration: 0.16)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(opened)
            .accessibilityLabel("Open gift")
            .padding(.top, 14)
            Text("Tap the gift to open")
                .scaledFont(14, .medium)
                .foregroundStyle(Jade.ink2)
                .accessibilityHidden(true)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))
                if opened { return }
                wobble += 1
            }
        }
    }

    private func open() {
        guard !opened else { return }
        opens += 1
        if reduceMotion {
            opened = true
            withAnimation(.easeOut(duration: 0.3)) { revealed = true }
            popped = true
        } else {
            withAnimation(.easeIn(duration: 0.45)) { opened = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.43))
                withAnimation(.easeOut(duration: 0.2)) { revealed = true }
                withAnimation(.spring(duration: 0.55, bounce: 0.45)) { popped = true }
            }
        }
        if let decor {
            AccessibilityNotification.Announcement("New: \(decor.name), \(decor.slot.title)").post()
        }
    }

    // MARK: - Step 2: what it was

    private var reveal: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Wardrobe.well).frame(width: 168, height: 168)
                if let decor {
                    Image(decor.icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 132, height: 132)
                        .scaleEffect(popped ? 1 : 0.35)
                        .opacity(popped ? 1 : 0)
                }
                if !reduceMotion { ConfettiBurst() }
            }
            .frame(width: 168, height: 168)
            .accessibilityHidden(true)
            Text(last ? "All \(Decor.all.count)!" : "New")
                .scaledFont(12, .bold)
                .foregroundStyle(Jade.onSleep)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Capsule().fill(Wardrobe.lime))
                .padding(.top, 16)
            Text(decor?.name ?? "")
                .scaledFont(26, .bold)
                .foregroundStyle(Jade.ink)
                .padding(.top, 6)
            Text(subtitle)
                .scaledFont(14, .medium)
                .foregroundStyle(Jade.ink2)
                .padding(.top, 4)
            VStack(spacing: 10) {
                Button(gift.welcome ? "Put it on \(gift.petName)" : "Wear on \(gift.petName)", action: wear)
                    .buttonStyle(PillButtonStyle(primary: true))
                Button("Later", action: later)
                    .buttonStyle(PillButtonStyle(primary: false))
            }
            .padding(.top, 20)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(decor.map { "New: \($0.name), \($0.slot.title)" } ?? "")
    }

    private var subtitle: String {
        guard let decor else { return "" }
        let total = Decor.all.count
        return last
            ? "That’s the whole wardrobe. \(decor.slot.title) · \(total) of \(total)"
            : "\(decor.slot.title) · \(collected) of \(total) collected"
    }
}

/// The gift box of the design (proto.js GIFT_SVG, a 200 × 200 drawing): the box in the accent
/// colour, a lime ribbon and bow. The lid flies off when it is opened.
struct GiftBox: View {
    var lidOff = false

    var body: some View {
        ZStack {
            Canvas { context, size in
                context.scaleBy(x: size.width / 200, y: size.height / 200)
                context.fill(Path(ellipseIn: CGRect(x: 38, y: 172, width: 124, height: 16)), with: .color(Jade.ink.opacity(0.08)))
                context.fill(Path(roundedRect: CGRect(x: 44, y: 92, width: 112, height: 86), cornerRadius: 16), with: .color(Jade.accent))
                context.fill(Path(CGRect(x: 90, y: 92, width: 20, height: 86)), with: .color(Wardrobe.lime))
            }
            Canvas { context, size in
                context.scaleBy(x: size.width / 200, y: size.height / 200)
                context.fill(Self.bow, with: .color(Wardrobe.lime))
                context.fill(Path(roundedRect: CGRect(x: 36, y: 72, width: 128, height: 30), cornerRadius: 12), with: .color(Jade.accent))
                context.fill(Path(roundedRect: CGRect(x: 36, y: 88, width: 128, height: 14), cornerRadius: 6), with: .color(.black.opacity(0.08)))
                context.fill(Path(CGRect(x: 88, y: 72, width: 24, height: 30)), with: .color(Wardrobe.lime))
            }
            .rotationEffect(.degrees(lidOff ? -16 : 0), anchor: UnitPoint(x: 0.5, y: 0.45))
            .offset(y: lidOff ? -70 : 0)
            .opacity(lidOff ? 0 : 1)
        }
    }

    /// The two loops of the bow, meeting at (100, 76).
    private static let bow: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 100, y: 76))
        p.addCurve(to: CGPoint(x: 56, y: 64), control1: CGPoint(x: 88, y: 50), control2: CGPoint(x: 56, y: 46))
        p.addCurve(to: CGPoint(x: 100, y: 76), control1: CGPoint(x: 56, y: 76), control2: CGPoint(x: 78, y: 76))
        p.closeSubpath()
        p.move(to: CGPoint(x: 100, y: 76))
        p.addCurve(to: CGPoint(x: 144, y: 64), control1: CGPoint(x: 112, y: 50), control2: CGPoint(x: 144, y: 46))
        p.addCurve(to: CGPoint(x: 100, y: 76), control1: CGPoint(x: 144, y: 76), control2: CGPoint(x: 122, y: 76))
        p.closeSubpath()
        return p
    }()
}

/// 14 dots flying out of the new item (0.8 s), in the app's colours.
private struct ConfettiBurst: View {
    @State private var go = false
    private static let colors: [Color] = [Jade.accent, Wardrobe.lime, Color(UIColor(hex: 0xF08A72)), Color(UIColor(hex: 0x8CB8D9)),
                                          Color(UIColor(hex: 0xE2B443)), Color(UIColor(hex: 0xF27A8C))]

    var body: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { i in
                // fixed spread, a little uneven, so every burst looks the same
                let angle = Double(i) / 14 * 2 * .pi + Double((i * 37) % 10) * 0.03
                let reach = 92 + Double((i * 53) % 40)
                let size = CGFloat(7 + (i % 3) * 3)
                Circle()
                    .fill(Self.colors[i % Self.colors.count])
                    .frame(width: size, height: size)
                    .offset(x: go ? cos(angle) * reach : 0, y: go ? sin(angle) * reach : 0)
                    .animation(.easeOut(duration: 0.8).delay(0.05 + Double(i % 4) * 0.03), value: go)
                    .opacity(go ? 0 : 1)
                    .animation(.easeIn(duration: 0.8).delay(0.05 + Double(i % 4) * 0.03), value: go)
            }
        }
        .allowsHitTesting(false)
        .onAppear { go = true }
    }
}
