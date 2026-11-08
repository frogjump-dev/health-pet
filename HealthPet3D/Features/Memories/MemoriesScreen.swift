import SwiftUI
import PetCore

/// Memories = the achievement ledger (PRD v0.2): every 自律周 and month, every pet that joined,
/// Lv 10 / 20, 30 / 100 on-time nights, 100 workouts, the first 20k-step day and the days
/// together, newest first. On top: how many days you have been together.
struct MemoriesScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let entries = model.ledger
        PageScroll {
            PageHeader(title: "Memories", count: entries.isEmpty ? nil : "\(entries.count)")
                .padding(.bottom, 4)
            HStack(spacing: 14) {
                PetPicture(pet: model.mainPet3D, happy: true).frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.daysTogether)").font(.rounded(28, .bold)).foregroundStyle(Jade.ink).monospacedDigit()
                    Label(model.daysTogether == 1 ? "day together" : "days together", systemImage: "heart")
                        .font(.rounded(13, .semibold))
                        .foregroundStyle(Jade.ink2)
                }
                Spacer()
            }
            .card()
            .accessibilityElement(children: .combine)
            ForEach(entries) { entry in
                LedgerRow(entry: entry)
            }
        }
    }
}

/// One ledger line: a picture or an icon in the legend's colour, what happened, when.
struct LedgerRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: 14) {
            badge
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.rounded(17, .semibold))
                    .foregroundStyle(Jade.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(entry.day.formatted(.dateTime.year().month(.abbreviated).day()))
                    .font(.rounded(12, .semibold))
                    .foregroundStyle(Jade.ink3)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private var pet: Pet3D? {
        switch entry.kind {
        case .unlocked(let activity), .level(let activity, _):
            Pet3D.all.first { $0.activity == activity }
        default:
            nil
        }
    }

    private var title: String {
        switch entry.kind {
        case .disciplinedWeek(let n): "Disciplined week \(n)"
        case .monthlyAchievement(let n): "Disciplined month \(n)"
        case .unlocked: "\(pet?.name ?? "A new pet") joined"
        case .level(_, let level): "\(pet?.name ?? "A pet") Lv \(level)"
        case .onTimeNights(let n): "\(n) on-time nights"
        case .workouts(let n): "\(n) workouts"
        case .firstTwentyKSteps: "First 20k-step day"
        case .daysTogether(let n): "\(n) days together"
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let pet {
            PetPicture(pet: pet, happy: true)
        } else {
            let look = icon
            Image(systemName: look.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(look.on)
                .frame(width: 40, height: 40)
                .background(Circle().fill(look.fill))
        }
    }

    /// Colour is the legend: jade = workouts, lime = sleep, the primary for whole weeks and months.
    private var icon: (name: String, fill: Color, on: Color) {
        switch entry.kind {
        case .disciplinedWeek: ("checkmark", Jade.primary, Jade.onPrimary)
        case .monthlyAchievement: ("star.fill", Jade.primary, Jade.onPrimary)
        case .onTimeNights: ("moon.fill", Jade.sleep, Jade.onSleep)
        case .workouts, .firstTwentyKSteps: ("figure.run", Jade.accent, Jade.onAccent)
        case .daysTogether: ("heart.fill", Jade.fill, Jade.ink)
        case .unlocked, .level: ("pawprint.fill", Jade.fill, Jade.ink)
        }
    }
}
