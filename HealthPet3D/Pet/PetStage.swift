import SwiftUI
import WebKit

/// Where the pet stands, in its own 100 × 100 box (the same units as pet.html).
struct PetAnchors: Equatable, Decodable {
    var cx: Double
    var top: Double
    var bottom: Double
    /// Height of the eyes.
    var ey: Double
    var w: Double
    var h: Double

    /// Where food goes in, as a fraction of the box: a little under the eyes, never below the feet.
    var mouth: CGPoint {
        CGPoint(x: cx / 100, y: min(bottom - 0.1 * h, ey + 0.12 * h) / 100)
    }

    static let standard = PetAnchors(cx: 50, top: 13.75, bottom: 87, ey: 50, w: 78.7, h: 73.25)
}

/// What the page shows; any change is sent to the live pet (a different pet or floor re-mounts it).
struct PetStageConfig: Equatable, Encodable {
    var pet: String
    /// The flat pale-sage oval under the pet: home only.
    var rug = false
    var shadow = true
    var dark = false
    /// Background the pet stands on, so its shadow is tinted for it (nil = the page canvas).
    var canvas: String? = nil
    /// At bedtime the pet nods off within seconds instead of minutes.
    var bedtime = false
    /// "normal" | "tired" | "sad"
    var mood = "normal"
    var interactive = true
    /// The pet's 100 × 100 box inside the web view: x and size as fractions of the width, y of the height.
    var box = Box(x: 0.19, y: 0.245, size: 0.62)

    struct Box: Equatable, Encodable {
        var x: Double
        var y: Double
        var size: Double
    }
}

/// Talks to one living pet. Calls made before the page is ready wait and are sent once it is.
@MainActor
@Observable
final class PetStageController {
    private(set) var anchors: PetAnchors?
    private(set) var isReady = false
    /// Bumped on every tap on the pet (the home shows a short line then).
    private(set) var tapCount = 0
    private(set) var lastTapMode = "awake"

    @ObservationIgnored fileprivate weak var webView: WKWebView?
    @ObservationIgnored private var pending: [String] = []

    func configure(_ config: PetStageConfig) { run("Pet.configure(\(Self.json(config)))") }
    /// 醒来: only for the first open of the day.
    func morning() { run("Pet.morning()") }
    /// cheer, starry, proud, hop, love: plays to the end.
    func celebrate(_ id: String) { run("Pet.celebrate('\(id)')") }
    func play(_ id: String) { run("Pet.play('\(id)')") }
    /// A food bubble reached the pet's mouth.
    func eat() { run("Pet.eat()") }
    func activity() { run("Pet.activity()") }
    func pause(_ paused: Bool) { run("Pet.pause(\(paused))") }

    private func run(_ js: String) {
        guard isReady, let webView else {
            pending.append(js)
            return
        }
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    fileprivate func attach(_ webView: WKWebView) {
        self.webView = webView
        isReady = false
    }

    fileprivate func receive(_ body: Any) {
        guard let message = body as? [String: Any], let type = message["type"] as? String else { return }
        switch type {
        case "ready":
            if let raw = message["anchors"], let data = try? JSONSerialization.data(withJSONObject: raw) {
                anchors = try? JSONDecoder().decode(PetAnchors.self, from: data)
            }
            isReady = true
            let queued = pending
            pending = []
            queued.forEach(run)
        case "tap":
            lastTapMode = message["mode"] as? String ?? "awake"
            tapCount += 1
        default:
            break
        }
    }

    static func json<T: Encodable>(_ value: T) -> String {
        (try? String(data: JSONEncoder().encode(value), encoding: .utf8)) ?? "{}"
    }
}

/// The living 3D pet (pet.html in a transparent web view). Only the pet's own box takes touches:
/// tap, several taps, press and hold.
struct PetStageView: UIViewRepresentable {
    let controller: PetStageController
    let config: PetStageConfig

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> WKWebView {
        let content = WKUserContentController()
        content.add(context.coordinator, name: "pet")
        content.addUserScript(WKUserScript(source: "window.PET_INIT = \(PetStageController.json(config));",
                                           injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = content
        configuration.suppressesIncrementalRendering = true

        let web = WKWebView(frame: .zero, configuration: configuration)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsLinkPreview = false
        #if DEBUG
        web.isInspectable = true
        #endif
        controller.attach(web)
        context.coordinator.lastConfig = config
        if let url = Bundle.main.url(forResource: "pet", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard context.coordinator.lastConfig != config else { return }
        context.coordinator.lastConfig = config
        controller.configure(config)
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "pet")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var controller: PetStageController?
        var lastConfig: PetStageConfig?

        init(controller: PetStageController) {
            self.controller = controller
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let body = message.body
            MainActor.assumeIsolated { controller?.receive(body) }
        }
    }
}
