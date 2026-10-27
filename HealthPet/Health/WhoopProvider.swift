import Foundation
import PetCore

/// Whoop data comes through our backend, not straight from the phone:
/// the OAuth client secret must stay on the server, and Whoop pushes updates via webhooks.
///
/// Backend contract (to be built):
///   GET  {base}/whoop/connect           -> 302 to Whoop OAuth, returns to healthpet://whoop/callback
///   GET  {base}/whoop/daily?from=&to=   -> [HealthSnapshot] as JSON (ISO 8601 dates)
struct WhoopProvider: HealthDataProvider {
    enum WhoopError: LocalizedError {
        case backendNotConfigured

        var errorDescription: String? {
            "Whoop needs the HealthPet backend, which isn't set up yet."
        }
    }

    let source: DataSource = .whoop
    /// nil until the backend exists.
    var backendBaseURL: URL?
    var session: URLSession = .shared

    var connectURL: URL? { backendBaseURL?.appending(path: "whoop/connect") }

    func requestAuthorization() async throws {
        // The OAuth web flow is started from the UI (ASWebAuthenticationSession with `connectURL`).
        guard backendBaseURL != nil else { throw WhoopError.backendNotConfigured }
    }

    func snapshots(from start: Date, to end: Date) async throws -> [HealthSnapshot] {
        guard let base = backendBaseURL else { throw WhoopError.backendNotConfigured }

        let formatter = ISO8601DateFormatter()
        var components = URLComponents(url: base.appending(path: "whoop/daily"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "from", value: formatter.string(from: start)),
            URLQueryItem(name: "to", value: formatter.string(from: end))
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([HealthSnapshot].self, from: data)
    }
}
