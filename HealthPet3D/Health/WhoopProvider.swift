import Foundation
import PetCore

enum WhoopError: LocalizedError {
    case backendNotConfigured
    case notConnected
    case connectFailed(String?)

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured: "Whoop needs the HealthPet server, which isn't set up in this build."
        case .notConnected: "Whoop isn't connected."
        case .connectFailed: "Couldn't connect Whoop. Please try again."
        }
    }
}

/// Whoop data comes through our backend, never straight from the phone: the OAuth client
/// secret stays on the server, and Whoop pushes updates there via webhooks.
/// Connecting is done by `WhoopConnector`; this type only reads.
struct WhoopProvider: HealthDataProvider {
    let source: DataSource = .whoop
    var backend: Backend?

    func requestAuthorization() async throws {
        guard backend != nil else { throw WhoopError.backendNotConfigured }
    }

    /// Throws `WhoopError.notConnected` when this account has no Whoop link.
    func snapshots(from start: Date, to end: Date) async throws -> [HealthSnapshot] {
        guard let backend else { throw WhoopError.backendNotConfigured }

        let data = try await backend.call("snapshots", query: [
            URLQueryItem(name: "from", value: Self.dayFormatter.string(from: start)),
            URLQueryItem(name: "to", value: Self.dayFormatter.string(from: end))
        ])
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.connected else { throw WhoopError.notConnected }
        return response.snapshots.compactMap(\.snapshot)
    }

    func disconnect() async throws {
        guard let backend else { throw WhoopError.backendNotConfigured }
        _ = try await backend.call("whoop-disconnect", method: "POST")
    }

    /// "YYYY-MM-DD" in the phone's time zone, matching the server's local-day keys.
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Wire format (backend/supabase/functions/_shared/whoop.ts SnapshotDTO)

    private struct Response: Decodable {
        var connected: Bool
        var snapshots: [DTO]
    }

    private struct DTO: Decodable {
        var day: String
        var sleepHours: Double?
        var hrvMs: Double?
        var hrvMethod: HRVMethod?
        var restingHeartRate: Double?
        var vendorRecovery: Double?
        var strain: Double?
        var sleepPerformance: Double?

        var snapshot: HealthSnapshot? {
            guard let date = WhoopProvider.dayFormatter.date(from: day) else { return nil }
            return HealthSnapshot(
                day: Calendar.current.startOfDay(for: date),
                source: .whoop,
                sleepHours: sleepHours,
                hrvMs: hrvMs,
                hrvMethod: hrvMethod,
                restingHeartRate: restingHeartRate,
                vendorRecovery: vendorRecovery,
                strain: strain,
                sleepPerformance: sleepPerformance
            )
        }
    }
}
