import SwiftUI

// Drawn pieces for the home screen's kitchen. Everything is vector so it can be swapped
// for final illustrations later without touching the layout.

extension Color {
    static let toastInk = Color(red: 0.29, green: 0.20, blue: 0.13)
    static let crust = Color(red: 0.80, green: 0.47, blue: 0.20)
    static let crustLight = Color(red: 0.96, green: 0.70, blue: 0.38)
    static let butter = Color(red: 1.00, green: 0.86, blue: 0.40)
    static let butterLight = Color(red: 1.00, green: 0.96, blue: 0.75)
}

/// Warm cream room with soft morning light from a window.
struct KitchenBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.91, blue: 0.83),
                    Color(red: 0.98, green: 0.94, blue: 0.87),
                    Color(red: 0.89, green: 0.80, blue: 0.68),
                ],
                startPoint: .top, endPoint: .bottom
            )
            // Light beams.
            GeometryReader { proxy in
                let w = proxy.size.width
                ForEach(0..<2) { i in
                    Rectangle()
                        .fill(.white.opacity(0.35))
                        .frame(width: w * (i == 0 ? 0.28 : 0.16), height: proxy.size.height * 0.9)
                        .rotationEffect(.degrees(-18))
                        .offset(x: w * (i == 0 ? 0.08 : 0.42), y: -proxy.size.height * 0.1)
                        .blur(radius: 28)
                }
            }
            // Table edge where the plate sits.
            VStack {
                Spacer()
                Ellipse()
                    .fill(.white.opacity(0.25))
                    .frame(height: 260)
                    .scaleEffect(x: 1.6)
                    .offset(y: 60)
                    .blur(radius: 20)
            }
        }
        .ignoresSafeArea()
    }
}

struct CircleIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.toastInk.opacity(0.8))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }
}

/// The once-a-day "pat on the head" bubble that floats beside the pet.
struct PatBubble: View {
    let action: () -> Void
    @State private var floating = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.55))
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
                        .frame(width: 70, height: 70)
                    VStack(spacing: 0) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(LinearGradient(colors: [.crustLight, .crust], startPoint: .top, endPoint: .bottom))
                            .rotationEffect(.degrees(-20))
                        Text("+10")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.crust)
                    }
                }
                Text("Pat Toast")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.toastInk.opacity(0.7))
            }
            .offset(y: floating ? -5 : 5)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: floating)
        }
        .buttonStyle(.plain)
        .onAppear { floating = true }
        .accessibilityLabel("Pat Toast, plus 10 warmth")
    }
}

/// A plain white breakfast plate seen from the side.
struct Plate: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.10))
                .offset(y: 6)
                .blur(radius: 6)
            Ellipse()
                .fill(LinearGradient(colors: [.white, Color(white: 0.90)], startPoint: .top, endPoint: .bottom))
            Ellipse()
                .stroke(Color(white: 0.86), lineWidth: 2)
                .padding(10)
            Ellipse()
                .fill(Color(white: 0.97))
                .padding(14)
        }
    }
}

struct LevelBar: View {
    let level: Int
    let current: Int
    let needed: Int

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.5))
                .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
            GeometryReader { proxy in
                Capsule()
                    .fill(LinearGradient(colors: [.crustLight, .crust], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(proxy.size.height, proxy.size.width * CGFloat(current) / CGFloat(needed)))
            }
            Text("\(current) / \(needed)")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.toastInk)
                .frame(maxWidth: .infinity)
            Text("Lv \(level)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(Capsule().fill(Color.crust))
                .overlay(Capsule().stroke(.white, lineWidth: 2))
                .offset(x: -12)
        }
        .frame(height: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level), \(current) of \(needed) warmth")
    }
}

/// A frosted card whose illustration pops out over its top edge.
struct ActionCard<Icon: View>: View {
    let title: String
    let subtitle: String?
    let height: CGFloat
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Spacer(minLength: 0)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.toastInk.opacity(0.85))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.toastInk.opacity(0.6))
                }
            }
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.7), lineWidth: 1))
            .overlay(alignment: .top) {
                icon().offset(y: -26)
            }
        }
        .buttonStyle(.plain)
    }
}

/// A glowing pat of butter: the "Today" button's illustration.
struct ButterPat: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.butter.opacity(0.45))
                .blur(radius: 16)
                .scaleEffect(1.4)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [.butterLight, .butter], startPoint: .top, endPoint: .bottom))
                .frame(height: 40)
                .offset(y: 8)
                .shadow(color: .crust.opacity(0.35), radius: 6, y: 4)
            // Top face.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.butterLight)
                .frame(height: 18)
                .offset(y: -10)
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 22, y: -14)
        }
    }
}

/// A little toaster with two slices peeking out: the "Memories" button's illustration.
struct Toaster: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 8) {
                ForEach(0..<2) { _ in
                    UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8)
                        .fill(LinearGradient(colors: [.crustLight, .crust], startPoint: .top, endPoint: .bottom))
                        .frame(width: 18, height: 30)
                }
            }
            .padding(.bottom, 22)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.62, green: 0.84, blue: 0.86), Color(red: 0.40, green: 0.68, blue: 0.72)], startPoint: .top, endPoint: .bottom))
                .frame(height: 34)
                .overlay(alignment: .trailing) {
                    Circle().fill(.white.opacity(0.8)).frame(width: 7, height: 7).padding(.trailing, 8)
                }
                .shadow(color: .black.opacity(0.15), radius: 4, y: 3)
        }
    }
}

/// The frosted strip at the bottom that opens "more" (settings for now).
struct MoreDrawerHandle: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up.circle.fill")
                Text("More")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.toastInk.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32)
                    .fill(.white.opacity(0.3))
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Placeholder until outfits exist.
struct WardrobeView: View {
    var body: some View {
        ContentUnavailableView(
            "Wardrobe coming soon",
            systemImage: "tshirt",
            description: Text("Hats, scarves and jam stains for Toast are on the way.")
        )
    }
}
