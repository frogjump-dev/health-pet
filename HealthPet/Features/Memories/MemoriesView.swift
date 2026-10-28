import SwiftUI
import PetCore

/// "Shared memories" album: pages are created automatically from data events.
struct MemoriesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.memories.isEmpty {
                    ContentUnavailableView(
                        "No memories yet",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Big days you have together will show up here on their own.")
                    )
                } else {
                    List(model.memories.sorted { $0.day > $1.day }) { memory in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memory.title).font(.headline)
                            Text(memory.day, style: .date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Memories")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
