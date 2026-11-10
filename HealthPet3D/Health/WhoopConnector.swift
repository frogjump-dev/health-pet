import AuthenticationServices
import UIKit

/// Runs the Whoop OAuth flow in a system browser sheet:
/// our backend hands out the authorize URL, Whoop redirects back to the backend, and the
/// backend finally sends the browser to ovenpals://whoop/connected?status=ok|error.
final class WhoopConnector: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let callbackScheme = "ovenpals"   // must match APP_RETURN_URL in the backend

    private var session: ASWebAuthenticationSession?

    private struct ConnectResponse: Decodable {
        var url: URL
    }

    @MainActor
    func connect(backend: Backend) async throws {
        let data = try await backend.call("whoop-connect", method: "POST")
        let authorizeURL = try JSONDecoder().decode(ConnectResponse.self, from: data).url

        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authorizeURL, callbackURLScheme: Self.callbackScheme) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? WhoopError.connectFailed(nil))
                }
            }
            session.presentationContextProvider = self
            self.session = session
            session.start()
        }
        session = nil

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "status" })?.value == "ok" else {
            throw WhoopError.connectFailed(items.first(where: { $0.name == "reason" })?.value)
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
