import SwiftUI

@main
struct HealthPetApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    // Opening the app is the "check on your pet" moment, so refresh every time.
                    if phase == .active { Task { await model.refresh() } }
                }
        }
    }
}

/// The pet's kitchen is the whole app; memories and settings open from its buttons.
struct RootView: View {
    var body: some View {
        HomeView()
    }
}
