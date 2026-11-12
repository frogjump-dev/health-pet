import Foundation

/// Where the pet's data lives (PRD v0.3 §9, decided 2026-11-10): the App Group
/// group.com.ovenpals.app, so the home screen widget that comes after TestFlight can read the same
/// data. HomeState's switches (first open done, the tour, appearance, notifications) stay in the
/// app's own defaults: the widget doesn't need them, and the screenshot script sets them at launch.
enum AppGroup {
    static let id = "group.com.ovenpals.app"

    /// The group's defaults, or the app's own when the build has no App Group (signed without the
    /// capability). Whatever the app's own defaults already hold is copied over once.
    static let defaults: UserDefaults = {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil,
              let group = UserDefaults(suiteName: id) else { return .standard }
        moveOnce(into: group)
        return group
    }()

    private static let movedKey = "3d.movedToAppGroup"

    private static func moveOnce(into group: UserDefaults) {
        guard !group.bool(forKey: movedKey) else { return }
        if let name = Bundle.main.bundleIdentifier, let own = UserDefaults.standard.persistentDomain(forName: name) {
            for (key, value) in own where group.object(forKey: key) == nil {
                group.set(value, forKey: key)
            }
        }
        group.set(true, forKey: movedKey)
    }
}
