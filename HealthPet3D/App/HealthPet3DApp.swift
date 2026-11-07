import SwiftUI

/// HealthPet 3D: the test build of the 3D方案 (slice pets, v3 「干净版」 UI, Mountain Jade).
/// It installs next to the 2D HealthPet app and shares its health data layer (AppModel,
/// HealthKit / Whoop / demo providers, PetCore); everything on screen lives in HealthPet3D/.
@main
struct HealthPet3DApp: App {
    @State private var model = AppModel()
    @State private var home = HomeState()
    @State private var router = Router()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(home)
                .environment(router)
                .preferredColorScheme(home.appearance.colorScheme)
                .tint(Jade.accent)
                .task { await model.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    // Opening the app is the "check on your pet" moment, so refresh every time.
                    if phase == .active { Task { await model.refresh() } }
                }
        }
    }
}

enum Route: Hashable {
    case today, pets, pet(String), share, memories, settings
}

@MainActor
@Observable
final class Router {
    var path: [Route] = []
}

struct RootView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeScreen()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .today: TodayScreen()
                    case .pets: PetsScreen()
                    case .pet(let id): PetDetailScreen(petID: id)
                    case .share: ShareScreen()
                    case .memories: MemoriesScreen()
                    case .settings: SettingsScreen()
                    }
                }
        }
        #if DEBUG
        .onAppear { router.path = Self.launchRoute() }
        #endif
    }

    #if DEBUG
    /// For screenshots on the simulator: `-hp3dRoute today|pets|pet:chili|share|memories|settings`.
    private static func launchRoute() -> [Route] {
        guard let raw = UserDefaults.standard.string(forKey: "hp3dRoute") else { return [] }
        switch raw {
        case "today": return [.today]
        case "pets": return [.pets]
        case "share": return [.today, .share]
        case "memories": return [.memories]
        case "settings": return [.settings]
        default:
            if raw.hasPrefix("pet:") { return [.pets, .pet(String(raw.dropFirst(4)))] }
            return []
        }
    }
    #endif
}
