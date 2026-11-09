import SwiftUI

/// The tap-to-explain card (PRD v0.2 §6, v3.4 layer ②): 250 pt wide, a 15 pt title and 13 pt
/// text, a tail pointing at what was tapped, gone with a tap anywhere else. It says what the thing
/// is and how much there is now; never a button or a link (all the numbers are in Today).
struct InfoNote<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.rounded(15, .bold))
                .foregroundStyle(Jade.ink)
            content()
                .font(.rounded(13, .medium))
                .foregroundStyle(Jade.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 250, alignment: .leading)
    }
}

extension InfoNote where Content == Text {
    init(_ title: String, _ text: String) {
        self.init(title: title) { Text(text) }
    }
}

extension View {
    /// Shows `note` as a small popover with a tail (never a sheet, even on a phone).
    func infoNote<Note: View>(isPresented: Binding<Bool>, @ViewBuilder note: @escaping () -> Note) -> some View {
        popover(isPresented: isPresented) {
            note()
                .presentationCompactAdaptation(.popover)
                .presentationBackground(Jade.card)
        }
    }

    /// The row a note is about gets a faint rounded backing while the note is open.
    func noteHighlight(_ on: Bool, radius: CGFloat = 14, inset: CGFloat = 8) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Jade.ink.opacity(on ? 0.07 : 0))
                .padding(-inset)
        )
        .animation(.easeOut(duration: 0.15), value: on)
    }
}

/// The note on this week's row (home and Today): one line per kind of cell, each led by a cell of
/// its own colour, so the colours need no words; the 自律周 rule is only explained here.
struct WeekNote: View {
    let cells: WeekCells
    let bedtime: String

    var body: some View {
        InfoNote(title: "This week") {
            VStack(alignment: .leading, spacing: 8) {
                line(CellRow.Cell.filled, Jade.accent,
                     Text("Workouts ") + Text("\(min(cells.workoutCount, 3)) of 3").bold().foregroundStyle(Jade.ink)
                     + Text(" · a run, a swim, or a 10k-step day"))
                line(.filled, Jade.sleep,
                     Text("Early nights ") + Text("\(min(cells.nightCount, 5)) of 5").bold().foregroundStyle(Jade.ink)
                     + Text(" · asleep by \(bedtime)"))
                line(.leave, Jade.sleep, Text("Leave night · one a week, still counts"))
                Rectangle().fill(Jade.fill).frame(height: 1).padding(.vertical, 2)
                Text("3 + 5 = a disciplined week, Monday to Sunday.")
                    .font(.rounded(13, .bold))
                    .foregroundStyle(Jade.ink)
            }
        }
    }

    private func line(_ cell: CellRow.Cell, _ color: Color, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            CellRow(cells: [cell], color: color, size: CGSize(width: 16, height: 6))
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            text
        }
    }
}
