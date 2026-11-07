import SwiftUI
import PetCore

/// Memories: the moments the pet remembers (first 20k-step day, 30/100/365 days together), newest first.
struct MemoriesScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let memories = model.memories.sorted { $0.day > $1.day }
        PageScroll {
            PageHeader(title: "Memories", count: memories.isEmpty ? nil : "\(memories.count)")
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
            ForEach(memories) { memory in
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.day.formatted(.dateTime.year().month(.abbreviated).day()))
                        .font(.rounded(12, .semibold))
                        .foregroundStyle(Jade.ink3)
                    Text(memory.title)
                        .font(.rounded(17, .semibold))
                        .foregroundStyle(Jade.ink)
                }
                .card()
                .accessibilityElement(children: .combine)
            }
        }
    }
}
