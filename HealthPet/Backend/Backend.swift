import Foundation
import Supabase

/// Our Supabase project: auth plus the edge functions in backend/supabase/functions.
/// Configured from Info.plist (SupabaseProjectRef / SupabaseAnonKey, set in Config/Secrets.xcconfig);
/// `shared` is nil until those are filled in, and Whoop is then simply unavailable.
final class Backend: @unchecked Sendable {
    static let shared: Backend? = Backend(bundle: .main)

    let client: SupabaseClient
    private let functionsURL: URL
    private let anonKey: String

    enum BackendError: LocalizedError {
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .http(let status): "The HealthPet server answered with an error (\(status))."
            }
        }
    }

    private init?(bundle: Bundle) {
        guard let ref = bundle.object(forInfoDictionaryKey: "SupabaseProjectRef") as? String, !ref.isEmpty,
              let key = bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String, !key.isEmpty,
              let url = URL(string: "https://\(ref).supabase.co")
        else { return nil }

        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        functionsURL = url.appending(path: "functions/v1")
        anonKey = key
    }

    /// Every install gets its own anonymous account on first use, so the server can keep
    /// that person's Whoop link. Sign in with Apple can later be attached to the same account.
    func accessToken() async throws -> String {
        if let session = try? await client.auth.session {
            return session.accessToken
        }
        return try await client.auth.signInAnonymously().accessToken
    }

    /// Calls one of our edge functions as the signed-in user.
    func call(_ function: String, method: String = "GET", query: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(url: functionsURL.appending(path: function), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw BackendError.http(status) }
        return data
    }
}
