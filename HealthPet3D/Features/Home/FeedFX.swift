import SwiftUI

/// The harvest after a tap on a food bubble (PRD v0.2 §4.3 / §4.4, B 轻泡, timings from the
/// 11-08 storyboard), drawn over the whole home in its own coordinates:
/// 0.2 s seven crumbs burst out of the popped bubble → from 0.36 s they are sucked into the
/// mouth one by one (0.4 s each, 0.05 s apart) → 1.06 s the last one is in (the page swallows) →
/// 1.18 s the tag pops up by the head for 1.5 s → 1.26 s a dot leaves the pet's feet and lands
/// on this week's cell (or the Memories icon) at 1.72 s.
struct Feed: Identifiable {
    let id: String
    let start: Date
    /// All in home coordinates.
    let from: CGPoint
    let mouth: CGPoint
    let feet: CGPoint
    let target: CGPoint
    let color: Color
    /// "Chili +1", "Marshmallow Lv 5"; nil for a late night or Whoop strain.
    let tag: String?
    let tagAt: CGPoint

    static let swallowAt = 1.06
    static let landsAt = 1.72
    static let endsAt = 2.7
}

enum Ease {
    static func out(_ p: Double) -> Double { 1 - pow(1 - p, 3) }
    static func easeIn(_ p: Double) -> Double { p * p * p }
    static func inOut(_ p: Double) -> Double { p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2 }
    /// Overshoots a little and settles (the engine's popIn).
    static func pop(_ u: Double, _ a: Double = 0, _ b: Double = 0.2) -> Double {
        let x = min(1, max(0, (u - a) / (b - a)))
        guard x > 0 else { return 0 }
        let c = 1.9
        return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2)
    }
    static func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
}

struct FeedLayer: View {
    let feeds: [Feed]

    private static let sizes: [Double] = [12, 10, 9, 9, 8, 7, 6]

    var body: some View {
        TimelineView(.animation(paused: feeds.isEmpty)) { timeline in
            Canvas { context, _ in
                for feed in feeds {
                    draw(feed, t: timeline.date.timeIntervalSince(feed.start), in: context)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ feed: Feed, t: Double, in context: GraphicsContext) {
        crumbs(feed, t: t, in: context)
        dot(feed, t: t, in: context)
        tag(feed, t: t, in: context)
    }

    private func circle(_ context: GraphicsContext, at p: CGPoint, size: Double, _ color: Color) {
        guard size > 0.2 else { return }
        context.fill(Path(ellipseIn: CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)), with: .color(color))
    }

    private func curve(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x, y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
    }

    /// Seven crumbs in the bubble's colour (every third one paler), bursting 27–35 pt out, then
    /// streaming into the mouth on arcs that alternate left and right.
    private func crumbs(_ feed: Feed, t: Double, in context: GraphicsContext) {
        guard t >= 0.2, t < Feed.swallowAt + 0.05 else { return }
        let n = Self.sizes.count
        for i in 0..<n {
            let angle = -Double.pi / 2 + Double(i) / Double(n) * 2 * .pi + 0.3
            let r1 = 27 + Double(i % 3) * 4
            let start = CGPoint(x: feed.from.x + cos(angle) * 13, y: feed.from.y + sin(angle) * 13)
            let burst = CGPoint(x: feed.from.x + cos(angle) * r1, y: feed.from.y + sin(angle) * r1)
            let size = Self.sizes[i]
            let leave = 0.36 + Double(i) * 0.05
            var point: CGPoint
            var diameter: Double
            if t < leave {
                let p = Ease.clamp((t - 0.2) / 0.16)
                let e = Ease.out(p)
                point = CGPoint(x: start.x + (burst.x - start.x) * e, y: start.y + (burst.y - start.y) * e)
                diameter = size * Ease.pop(p, 0, 0.8)
            } else {
                let p = Ease.clamp((t - leave) / 0.4)
                guard p < 1 else { continue }
                let e = Ease.easeIn(p) * 0.7 + p * 0.3
                let side = (i % 2 == 1 ? 1.0 : -1.0) * (24 + Double(i) * 4)
                let control = CGPoint(x: (burst.x + feed.mouth.x) / 2 + side, y: min(burst.y, feed.mouth.y) - 20)
                point = curve(burst, control, feed.mouth, e)
                diameter = size * (1 - 0.6 * e)
            }
            if i % 3 == 1 {
                circle(context, at: point, size: diameter, Jade.card)
                circle(context, at: point, size: diameter, feed.color.opacity(0.55))
            } else {
                circle(context, at: point, size: diameter, feed.color)
            }
        }
    }

    /// A dot leaves the pet's feet (not across its face) and lands on the cell it fills.
    private func dot(_ feed: Feed, t: Double, in context: GraphicsContext) {
        let begin = Feed.swallowAt + 0.2
        guard t >= begin, t < Feed.landsAt else { return }
        let p = Ease.clamp((t - begin) / 0.46)
        let e = Ease.inOut(p)
        let control = CGPoint(x: feed.feet.x + (feed.target.x - feed.feet.x) * 0.6, y: feed.feet.y - 6)
        circle(context, at: curve(feed.feet, control, feed.target, e), size: 9 * Ease.pop(p, 0, 0.25) * (1 - 0.25 * e), feed.color)
    }

    /// "Chili +1" by the pet's head: pops in, rises 8 pt, fades after 1.2 s.
    private func tag(_ feed: Feed, t: Double, in context: GraphicsContext) {
        guard let text = feed.tag else { return }
        let u = t - (Feed.swallowAt + 0.12)
        guard u >= 0, u < 1.5 else { return }
        let scale = 0.6 + 0.4 * Ease.pop(u, 0, 0.22)
        let alpha = min(1, u / 0.12) * (u > 1.2 ? 1 - (u - 1.2) / 0.3 : 1)
        let resolved = context.resolve(Text(text).font(.rounded(12, .bold)).foregroundStyle(Jade.ink))
        let size = resolved.measure(in: CGSize(width: 300, height: 40))
        let width = size.width + 30, height = 24.0
        let center = CGPoint(x: feed.tagAt.x, y: feed.tagAt.y - 8 * Ease.out(min(1, u / 0.3)))
        var layer = context
        layer.opacity = alpha
        layer.translateBy(x: center.x, y: center.y)
        layer.scaleBy(x: scale, y: scale)
        let box = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        layer.drawLayer { shadowed in
            shadowed.addFilter(.shadow(color: .black.opacity(0.08), radius: 6, y: 2))
            shadowed.fill(Path(roundedRect: box, cornerRadius: height / 2), with: .color(Jade.card))
        }
        layer.fill(Path(ellipseIn: CGRect(x: box.minX + 10, y: -3, width: 6, height: 6)), with: .color(feed.color))
        layer.draw(resolved, at: CGPoint(x: box.minX + 21 + size.width / 2, y: 0), anchor: .center)
    }
}

/// A short bump, every time `trigger` changes (a cell that just filled, the Memories icon).
struct Pulse: ViewModifier {
    let trigger: Int
    var amount: CGFloat = 1.18

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(amount, duration: 0.15)
                CubicKeyframe(1, duration: 0.15)
            }
        }
    }
}

extension View {
    func pulse(_ trigger: Int, amount: CGFloat = 1.18) -> some View {
        modifier(Pulse(trigger: trigger, amount: amount))
    }
}
