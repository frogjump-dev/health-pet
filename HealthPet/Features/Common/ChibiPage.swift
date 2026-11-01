import SwiftUI

/// A full page opened from the home dock: warm wood background, round back button,
/// big title. Matches the inner-pages v1 mockups (Today, Pets, Share).
struct ChibiPage<Trailing: View, Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                        .chibiPanel(Circle(), shadow: 3)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Back")

                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(ChibiFont.title(30)).foregroundStyle(Palette.ink)
                    Text(subtitle).font(ChibiFont.body(12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                }
                Spacer(minLength: 0)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            content
        }
        .background(PageBackground().ignoresSafeArea())
    }
}

extension ChibiPage where Trailing == EmptyView {
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, trailing: { EmptyView() }, content: content)
    }
}

/// Warm floorboards, the same wood as the home kitchen floor.
struct PageBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.97, green: 0.90, blue: 0.78),
                                    Color(red: 0.95, green: 0.85, blue: 0.68),
                                    Color(red: 0.94, green: 0.81, blue: 0.61)],
                           startPoint: .top, endPoint: .bottom)
            GeometryReader { geo in
                Path { p in
                    var x: CGFloat = 66
                    while x < geo.size.width {
                        p.addRect(CGRect(x: x, y: 0, width: 2, height: geo.size.height))
                        x += 68
                    }
                }
                .fill(Color(red: 0.63, green: 0.39, blue: 0.16).opacity(0.08))
            }
        }
    }
}

/// Small rounded label with an ink outline.
struct ChibiChip: View {
    let text: String
    var fill: Color = Palette.cream

    var body: some View {
        Text(text)
            .font(ChibiFont.bold(11))
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.top, 3)
            .padding(.bottom, 2)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
    }
}

/// Big game button: yellow with outlined white text, or cream with ink text.
struct ChibiButton: View {
    let title: String
    var detail: String?
    var primary = true
    var height: CGFloat = 54
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if primary {
                    OutlinedText(text: title, font: ChibiFont.title(19), tracking: 1)
                    if let detail { OutlinedText(text: detail, font: ChibiFont.title(15), tracking: 0.8) }
                } else {
                    Text(title).font(ChibiFont.title(height < 50 ? 15 : 19)).foregroundStyle(Palette.ink)
                    if let detail { Text(detail).font(ChibiFont.title(15)).foregroundStyle(Palette.inkSoft) }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .chibiPanel(RoundedRectangle(cornerRadius: height < 50 ? 14 : 18, style: .continuous),
                        fill: primary ? Palette.butter : Palette.cream, shadow: height < 50 ? 3 : 4)
        }
        .buttonStyle(PressableStyle())
    }
}

/// The 出炉券 (bake ticket) drawn as a little yellow stub.
struct TicketGlyph: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Palette.butter)
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
            .overlay(alignment: .leading) {
                Rectangle()
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                    .frame(width: 0.1)
                    .padding(.leading, 6)
            }
            .frame(width: 20, height: 13)
    }
}
