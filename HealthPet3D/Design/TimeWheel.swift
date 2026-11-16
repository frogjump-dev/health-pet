import SwiftUI

/// The app's own time wheel (bubble-settings-v1, decided 2026-11-16): big rounded numbers, and the
/// picked row sits on a light lime capsule with a moon (a sun for waking up): colour is the legend.
/// 「手表记错了」 turns the capsule grey when the time wouldn't count. Five rows show, 44 pt each.
enum WheelMetrics {
    static let row: CGFloat = 44
    static let rows: CGFloat = 5
    static var height: CGFloat { row * rows }
}

/// One scrolling column of a wheel. It snaps to a row; the row in the middle is the choice.
struct WheelColumn<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    var width: CGFloat = 110
    /// VoiceOver: what this column picks ("Asleep by", "Hour").
    var name: String
    let label: (Value) -> String

    @State private var centred: Value?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(values, id: \.self) { value in
                    Text(label(value))
                        .font(.rounded(26, .heavy))
                        .monospacedDigit()
                        .foregroundStyle(value == (centred ?? selection) ? Jade.ink : Jade.ink3)
                        .frame(width: width, height: WheelMetrics.row)
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.easeOut(duration: 0.25)) { centred = value } }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centred, anchor: .center)
        .contentMargins(.vertical, (WheelMetrics.height - WheelMetrics.row) / 2, for: .scrollContent)
        .frame(width: width, height: WheelMetrics.height)
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3),
                                     .init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        .onAppear { centred = selection }
        .onChange(of: centred) { _, value in
            if let value, value != selection { selection = value }
        }
        .onChange(of: selection) { _, value in
            if value != centred { withAnimation(.easeOut(duration: 0.25)) { centred = value } }
        }
        .sensoryFeedback(.selection, trigger: centred) { old, _ in old != nil && FeelSettings.haptics }
        .accessibilityElement()
        .accessibilityLabel(name)
        .accessibilityValue(label(selection))
        .accessibilityAdjustableAction { direction in
            guard let index = values.firstIndex(of: selection) else { return }
            switch direction {
            case .increment: if index + 1 < values.count { selection = values[index + 1] }
            case .decrement: if index > 0 { selection = values[index - 1] }
            @unknown default: break
            }
        }
    }
}

/// The capsule behind the picked row: lime with a moon or a sun, grey when it doesn't count.
struct WheelBand: View {
    var icon: String
    var width: CGFloat = 210
    var counts = true

    var body: some View {
        Capsule()
            .fill(counts ? Jade.sleepTint : Jade.fill)
            .frame(width: width, height: WheelMetrics.row)
            .overlay(alignment: .leading) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(counts ? Jade.sleepText : Jade.ink3)
                    .padding(.leading, 14)
            }
            .animation(.easeOut(duration: 0.2), value: counts)
            .accessibilityHidden(true)
    }
}

/// A sleep target on one wheel of half-hour steps (bedtimes 20:00–02:00, wake-ups 04:00–11:00).
struct TargetWheel: View {
    let title: String
    let icon: String
    let options: [Int]
    @Binding var minutes: Int

    var body: some View {
        // a time saved before half-hour steps (or out of range) still shows
        let values = options.contains(minutes) ? options : ([minutes] + options).sorted { Self.order($0) < Self.order($1) }
        ZStack {
            WheelBand(icon: icon)
            WheelColumn(values: values, selection: $minutes, width: 170, name: title) { Format.time(minutes: $0) }
        }
        .frame(maxWidth: .infinity)
    }

    /// Evening first, then after midnight.
    private static func order(_ minutes: Int) -> Int { minutes < 12 * 60 ? minutes + 1440 : minutes }
}

/// A sleep target in a bottom sheet: its name, the wheel, Done.
struct TargetWheelSheet: View {
    let title: String
    let icon: String
    let options: [Int]
    @Binding var minutes: Int
    @Environment(\.dismiss) private var dismiss
    @State private var picked = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text(title).scaledFont(20, .heavy).foregroundStyle(Jade.ink)
            } icon: {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(Jade.sleepText)
            }
            .padding(.horizontal, 20)
            TargetWheel(title: title, icon: icon, options: options, minutes: $picked)
                .padding(.vertical, 12)
            Button("Done") {
                minutes = picked
                dismiss()
            }
            .buttonStyle(PillButtonStyle(primary: true))
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .onAppear { picked = minutes }
        .presentationDetents([.height(400)])
        .jadeSheet()
    }
}

/// Hours and minutes on two (with the 12-hour clock, three) columns under one band: when the user
/// really fell asleep. `minutes` = minutes after midnight.
struct ClockWheel: View {
    @Binding var minutes: Int
    var counts = true
    private let clock = ClockStyle.shared

    var body: some View {
        let twelve = clock.twelveHour
        ZStack {
            WheelBand(icon: "moon", width: twelve ? 270 : 210, counts: counts)
            HStack(spacing: 2) {
                if twelve {
                    WheelColumn(values: Array(1...12), selection: hour12, width: 62, name: "Hour") { "\($0)" }
                } else {
                    // evening first: it is about last night
                    WheelColumn(values: Array(18...23) + Array(0...17), selection: hour24, width: 62, name: "Hour") { String(format: "%02d", $0) }
                }
                Text(":")
                    .font(.rounded(26, .heavy))
                    .foregroundStyle(Jade.ink)
                    .frame(width: 10)
                    .accessibilityHidden(true)
                WheelColumn(values: Array(0...59), selection: minute, width: 62, name: "Minute") { String(format: "%02d", $0) }
                if twelve {
                    WheelColumn(values: ["AM", "PM"], selection: period, width: 66, name: "AM or PM") { $0 }
                }
            }
            .padding(.leading, 26)
        }
        .frame(maxWidth: .infinity)
    }

    private var hour24: Binding<Int> {
        Binding(get: { minutes / 60 }, set: { minutes = $0 * 60 + minutes % 60 })
    }

    private var minute: Binding<Int> {
        Binding(get: { minutes % 60 }, set: { minutes = (minutes / 60) * 60 + $0 })
    }

    private var hour12: Binding<Int> {
        Binding(get: { (minutes / 60) % 12 == 0 ? 12 : (minutes / 60) % 12 },
                set: { minutes = (($0 % 12) + (minutes / 60 >= 12 ? 12 : 0)) * 60 + minutes % 60 })
    }

    private var period: Binding<String> {
        Binding(get: { minutes / 60 >= 12 ? "PM" : "AM" },
                set: { minutes = ((minutes / 60) % 12 + ($0 == "PM" ? 12 : 0)) * 60 + minutes % 60 })
    }
}
