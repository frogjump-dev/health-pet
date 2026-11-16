import SwiftUI
import PetCore

/// What a line is about, as a small icon before it (colour is the legend, like the food bubbles:
/// only the icon is coloured): a moon in lime, a workout or a 10k day in jade.
enum BubbleIcon: Equatable {
    case moon, workout, steps, week

    var symbol: String {
        switch self {
        case .moon: "moon.fill"
        case .workout: "figure.run"
        case .steps: "shoeprints.fill"
        case .week: "checkmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .moon: Jade.sleepText
        case .workout, .steps, .week: Jade.accent
        }
    }

    /// The pet's lines are a fixed set of English sentences; the ones about data get their icon.
    static func guess(_ line: String) -> BubbleIcon? {
        let text = line.lowercased()
        if text.contains("on time") { return .moon }
        if text.contains("10k") { return .steps }
        if text.contains("logged") { return .workout }
        if text.contains("disciplined") { return .week }
        return nil
    }

    /// A booking's tag (Reduce Motion says it): the kind of what was eaten.
    static func of(_ kind: CreditKind) -> BubbleIcon? {
        switch kind {
        case .night: .moon
        case .workout: .workout
        case .steps: .steps
        case .load: nil
        }
    }
}

/// B 轻泡串 (decided 2026-11-16): what the pet says. A card-coloured capsule (corner 22 when it
/// takes two lines) and two small round beads, 10 and 6 pt, leading to the pet, as if it blew the
/// bubble. The beads pop first, then the bubble (the food bubble's jelly), then the words one by
/// one, like talking; a question's two buttons come after the words. Asleep: the beads are two
/// small z's and the words grey. No sound of its own (pet sounds are paused, PRD v0.3 §8.4).
/// Reduce Motion: it only fades in, all words at once.
struct PetBubble: View {
    /// Where the pet is, seen from the bubble: under it (home), above it, or to its left.
    enum Toward { case down, up, leading }

    struct Question {
        var no: String
        var yes: String
        var onNo: () -> Void
        var onYes: () -> Void
    }

    let text: String
    var icon: BubbleIcon? = nil
    var asleep = false
    var toward: Toward = .down
    var question: Question? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0
    @State private var sx: CGFloat = 0.3
    @State private var sy: CGFloat = 0.3
    @State private var shown = 0.0
    @State private var nearBead: CGFloat = 0
    @State private var farBead: CGFloat = 0
    @State private var buttons = false

    private var wordList: [String] { text.split(separator: " ").map(String.init) }

    var body: some View {
        Group {
            switch toward {
            case .down: VStack(spacing: 0) { bubble; trail }
            case .up: VStack(spacing: 0) { trail; bubble }
            case .leading: HStack(spacing: 0) { trail; bubble }
            }
        }
        .onAppear(perform: play)
        .accessibilityElement(children: question == nil ? .ignore : .contain)
        .accessibilityLabel(question == nil ? text : "")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: The bubble

    private var bubble: some View {
        Group {
            if let question {
                VStack(spacing: 10) {
                    spoken(Jade.ink)
                    HStack(spacing: 8) {
                        Button(question.no, action: question.onNo).buttonStyle(QuestionButton(primary: false))
                        Button(question.yes, action: question.onYes).buttonStyle(QuestionButton(primary: true))
                    }
                    .opacity(buttons ? 1 : 0)
                    .offset(y: buttons ? 0 : 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                HStack(spacing: 7) {
                    if asleep {
                        Image(systemName: "moon.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(Jade.ink3)
                    } else if let icon {
                        Image(systemName: icon.symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(icon.color)
                    }
                    spoken(asleep ? Jade.ink2 : Jade.ink)
                }
                .padding(.horizontal, 17)
                .padding(.top, 10)
                .padding(.bottom, 11)
            }
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Jade.card))
        .softShadow(1)
        .scaleEffect(x: sx, y: sy, anchor: anchor)
        .opacity(shown)
    }

    /// The words that are out so far; the rest already take their place, invisible, so the
    /// bubble keeps its size while it talks.
    private func spoken(_ ink: Color) -> some View {
        let all = wordList
        let line = all.indices.reduce(Text("")) { text, index in
            text + Text(all[index] + (index < all.count - 1 ? " " : ""))
                .foregroundStyle(index < revealed ? ink : Color.clear)
        }
        return line
            .scaledFont(15, .semibold)
            .multilineTextAlignment(.center)
            .lineSpacing(1)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var anchor: UnitPoint {
        switch toward {
        case .down: .bottom
        case .up: .top
        case .leading: .leading
        }
    }

    // MARK: The beads (or the z's)

    @ViewBuilder
    private var trail: some View {
        switch toward {
        case .down:
            ZStack(alignment: .top) {
                bead(10, near: true).offset(x: 7, y: 4)
                bead(6, near: false).offset(x: 1, y: 17)
            }
            .frame(width: 30, height: 30, alignment: .top)
        case .up:
            ZStack(alignment: .top) {
                bead(6, near: false).offset(x: 1, y: 4)
                bead(10, near: true).offset(x: 7, y: 14)
            }
            .frame(width: 30, height: 28, alignment: .top)
        case .leading:
            HStack(spacing: 3) {
                bead(6, near: false)
                bead(10, near: true)
            }
            .padding(.trailing, 4)
        }
    }

    @ViewBuilder
    private func bead(_ size: CGFloat, near: Bool) -> some View {
        Group {
            if asleep {
                Text("z")
                    .font(.rounded(near ? 12 : 9, .black))
                    .foregroundStyle(Jade.ink3)
                    .frame(width: 12, height: 12)
            } else {
                Circle().fill(Jade.card).frame(width: size, height: size).softShadow(0.8)
            }
        }
        .scaleEffect(near ? nearBead : farBead)
        .accessibilityHidden(true)
    }

    // MARK: Pop

    private func play() {
        let count = max(1, wordList.count)
        if reduceMotion {
            (sx, sy, nearBead, farBead, revealed, buttons) = (1, 1, 1, 1, count, true)
            withAnimation(.easeOut(duration: 0.2)) { shown = 1 }
            return
        }
        // the far bead, the near one, then the bubble (with the pet above, the bubble comes first)
        let beadsFirst = toward != .up
        let beadDelay = beadsFirst ? 0.0 : 0.2
        let bodyDelay = beadsFirst ? 0.12 : 0.0
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5).delay(beadDelay)) { farBead = 1 }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5).delay(beadDelay + 0.06)) { nearBead = 1 }
        withAnimation(.easeOut(duration: 0.12).delay(bodyDelay)) { shown = 1 }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.5).delay(bodyDelay)) { sx = 1 }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62).delay(bodyDelay)) { sy = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int((bodyDelay + 0.11) * 1000)))
            for index in 1...count {
                withAnimation(.easeOut(duration: 0.14)) { revealed = index }
                try? await Task.sleep(for: .milliseconds(55))
            }
            if question != nil {
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(.easeOut(duration: 0.22)) { buttons = true }
            }
        }
    }
}

/// Not now (the grey fill) and Sure (dark), 34 pt.
private struct QuestionButton: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(14, .heavy)
            .foregroundStyle(primary ? Jade.onPrimary : Jade.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 34)
            .background(Capsule().fill(primary ? Jade.primary : Jade.fill))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
