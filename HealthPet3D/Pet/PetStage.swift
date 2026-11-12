import SwiftUI
import UIKit
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
    /// The slow condition of the last 7 days (PRD v0.2 §5.5): "lively" | "normal" | "low".
    /// Only the idle behaviour and the floor's tint change.
    var energy = "normal"
    /// Reduce Motion is on (PRD v0.3 §8.2): the pet keeps its blinks and its faces, nothing moves.
    /// Filled in by `PetStage` from the system setting each time the config is sent.
    var calm = false
    var interactive = true
    /// The pet's 100 × 100 box inside the web view: x and size as fractions of the width, y of the height.
    var box = Box(x: 0.19, y: 0.245, size: 0.62)

    struct Box: Equatable, Encodable {
        var x: Double
        var y: Double
        var size: Double
    }
}

/// The app's one living pet (decided 2026-11-08, PRD §9 D1): a single web view, started as the
/// app launches (warm-up) and handed between the screens that show a live pet (home, a pet's
/// page). Only the screen that holds it last (`claim`) drives it; the others wait.
/// Calls made before the page is ready wait and are sent once it is.
@MainActor
@Observable
final class PetStage {
    static let shared = PetStage()

    /// The page has the pet mounted and takes calls.
    private(set) var isReady = false
    /// The page has put the current pet on screen; until then the still picture stands in for it.
    private(set) var hasDrawn = false
    /// Bumped on every tap on the pet (the home shows a short line then).
    private(set) var tapCount = 0
    private(set) var lastTapMode = "awake"
    /// The screen that holds the pet now.
    private(set) var owner: UUID?
    /// Each pet's standing box, as the page measured it.
    private(set) var anchorsByPet: [String: PetAnchors] = [:]

    @ObservationIgnored private var webView: WKWebView?
    @ObservationIgnored private var pending: [String] = []
    @ObservationIgnored private var config: PetStageConfig?
    @ObservationIgnored private var hosts: [UUID: WeakHost] = [:]
    @ObservationIgnored private var appActive = true
    @ObservationIgnored private var handler: PetPageHandler?
    /// When the page started loading, for the debug log.
    @ObservationIgnored private var loadStarted = ContinuousClock.now

    private init() {}

    func anchors(for pet: String) -> PetAnchors? { anchorsByPet[pet] }

    // MARK: - Screens

    /// Starts the page in the background, so the pet is there the moment a screen asks for it.
    func warmUp(_ config: PetStageConfig) {
        guard webView == nil else { return }
        self.config = config
        let handler = PetPageHandler(stage: self)
        self.handler = handler
        let content = WKUserContentController()
        content.add(handler, name: "pet")
        content.addUserScript(Self.initScript(config))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = content
        configuration.suppressesIncrementalRendering = true

        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 400, height: 600), configuration: configuration)
        web.navigationDelegate = handler
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsLinkPreview = false
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        #if DEBUG
        web.isInspectable = true
        #endif
        webView = web
        loadStarted = .now
        log("warm-up \(config.pet)")
        Self.load(web)
    }

    /// A screen came on: it gets the pet, showing `config`.
    func claim(_ owner: UUID, config: PetStageConfig) {
        self.owner = owner
        if webView == nil { warmUp(config) }
        attachToOwner()
        apply(config)
        updatePause()
    }

    /// A screen went away: the pet pauses unless another screen already took it.
    func release(_ owner: UUID) {
        guard self.owner == owner else { return }
        self.owner = nil
        updatePause()
    }

    /// The holding screen changed what it shows (theme, mood, box…). Other screens are ignored.
    func update(_ owner: UUID, config: PetStageConfig) {
        guard self.owner == owner else { return }
        apply(config)
    }

    /// The place on screen where `owner` shows the pet.
    fileprivate func register(_ owner: UUID, host: PetHostView) {
        hosts = hosts.filter { $0.value.view != nil }
        hosts[owner] = WeakHost(view: host)
        if self.owner == owner { attachToOwner() }
    }

    func setAppActive(_ active: Bool) {
        appActive = active
        updatePause()
    }

    private func attachToOwner() {
        guard let owner, let host = hosts[owner]?.view, let webView, webView.superview !== host else { return }
        webView.removeFromSuperview()
        webView.frame = host.bounds
        host.addSubview(webView)
    }

    private func apply(_ given: PetStageConfig) {
        var new = given
        new.calm = UIAccessibility.isReduceMotionEnabled
        guard new != config else { return }
        // the page mounts the pet again for a different pet or floor: the still stands in meanwhile
        if config.map({ $0.pet != new.pet || $0.rug != new.rug }) ?? true { hasDrawn = false }
        config = new
        run("Pet.configure(\(Self.json(new)))")
    }

    private func updatePause() {
        run("Pet.pause(\(owner == nil || !appActive))")
    }

    // MARK: - The pet

    /// 醒来: only for the first open of the day.
    func morning() { run("Pet.morning()") }
    /// cheer, starry, proud, hop, love, cheerup, confused: plays to the end.
    func celebrate(_ id: String) { run("Pet.celebrate('\(id)')") }
    func play(_ id: String) { run("Pet.play('\(id)')") }
    /// A food bubble reached the pet's mouth.
    func eat() { run("Pet.eat()") }
    /// A food bubble at `point` (fractions of the pet's page) was tapped: the pet watches its
    /// crumbs come, chews, and swallows at 1.06 s, then plays `then` (giggle, proud, cheer).
    func feed(at point: CGPoint, then expression: String) {
        let x = String(format: "%.4f", point.x), y = String(format: "%.4f", point.y)
        run("Pet.feed({x: \(x), y: \(y), then: '\(expression)'})")
    }
    func activity() { run("Pet.activity()") }

    private func run(_ js: String) {
        guard isReady, let webView else {
            pending.append(js)
            return
        }
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Page events

    fileprivate func receive(_ body: Any) {
        guard let message = body as? [String: Any], let type = message["type"] as? String else { return }
        let pet = message["pet"] as? String
        switch type {
        case "ready":
            if let pet, let raw = message["anchors"], let data = try? JSONSerialization.data(withJSONObject: raw),
               let anchors = try? JSONDecoder().decode(PetAnchors.self, from: data) {
                anchorsByPet[pet] = anchors
            }
            log("ready \(pet ?? "?")")
            guard !isReady else { return }
            isReady = true
            let queued = pending
            pending = []
            queued.forEach(run)
        case "drawn":
            log("drawn \(pet ?? "?")")
            // a drawing of the pet shown before the latest change doesn't count
            if pet == nil || pet == config?.pet { hasDrawn = true }
        case "tap":
            lastTapMode = message["mode"] as? String ?? "awake"
            tapCount += 1
        case "error":
            log("page error: \(message["message"] as? String ?? "?")")
        default:
            break
        }
    }

    /// The web content process went away (iOS reclaims it in the background): load the page
    /// again showing what the app shows now; calls wait until it is ready.
    fileprivate func pageLost() {
        guard let webView else { return }
        log("web content process ended, reloading")
        isReady = false
        hasDrawn = false
        pending = []
        loadStarted = .now
        if let config {
            let content = webView.configuration.userContentController
            content.removeAllUserScripts()
            content.addUserScript(Self.initScript(config))
        }
        Self.load(webView)
        updatePause()
    }

    /// Debug builds print how long the page takes (`[pet] ready toast +640ms`) to the console.
    fileprivate func log(_ text: String) {
        #if DEBUG
        let ms = Int((ContinuousClock.now - loadStarted) / .milliseconds(1))
        // stderr is unbuffered, so the line is there even if the app is ended right after
        FileHandle.standardError.write(Data("[pet] \(text) +\(ms)ms\n".utf8))
        #endif
    }

    private static func initScript(_ given: PetStageConfig) -> WKUserScript {
        var config = given
        config.calm = UIAccessibility.isReduceMotionEnabled
        return WKUserScript(source: "window.PET_INIT = \(json(config));", injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    private static func load(_ web: WKWebView) {
        guard let url = Bundle.main.url(forResource: "pet", withExtension: "html") else { return }
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    static func json<T: Encodable>(_ value: T) -> String {
        (try? String(data: JSONEncoder().encode(value), encoding: .utf8)) ?? "{}"
    }
}

private struct WeakHost {
    weak var view: PetHostView?
}

/// Hears the page (ready / drawn / tap / hold / error) and its navigation; kept apart from the
/// stage because WebKit retains its message handlers.
private final class PetPageHandler: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    weak var stage: PetStage?

    init(stage: PetStage) {
        self.stage = stage
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body
        MainActor.assumeIsolated { stage?.receive(body) }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        MainActor.assumeIsolated { stage?.pageLost() }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated { stage?.log("page loaded") }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let text = error.localizedDescription
        MainActor.assumeIsolated { stage?.log("page failed: \(text)") }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let text = error.localizedDescription
        MainActor.assumeIsolated { stage?.log("page failed to start: \(text)") }
    }
}

/// The spot a screen keeps for the pet; the shared web view is moved in while that screen holds it.
final class PetHostView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.forEach { $0.frame = bounds }
    }
}

/// Puts the shared living pet into a screen. Only the pet's own box takes touches:
/// tap, several taps, press and hold.
struct PetStageView: UIViewRepresentable {
    let owner: UUID
    let config: PetStageConfig

    func makeUIView(context: Context) -> PetHostView {
        let host = PetHostView()
        host.backgroundColor = .clear
        return host
    }

    func updateUIView(_ host: PetHostView, context: Context) {
        PetStage.shared.register(owner, host: host)
        PetStage.shared.update(owner, config: config)
    }
}

/// The living pet for one screen, with its still picture standing in at the same place until the
/// page has drawn it. The screen holds the pet while it is on screen.
struct LivePet: View {
    let config: PetStageConfig
    @State private var owner = UUID()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let stage = PetStage.shared
        GeometryReader { geo in
            let side = CGFloat(config.box.size) * geo.size.width
            ZStack(alignment: .topLeading) {
                PetStageView(owner: owner, config: config)
                if !(stage.hasDrawn && stage.owner == owner), let pet = Pet3D.with(id: config.pet) {
                    PetPicture(pet: pet)
                        .frame(width: side, height: side)
                        .offset(x: CGFloat(config.box.x) * geo.size.width, y: CGFloat(config.box.y) * geo.size.height)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: stage.hasDrawn)
        }
        .onAppear { stage.claim(owner, config: config) }
        .onDisappear { stage.release(owner) }
        .onChange(of: scenePhase) { _, phase in
            stage.setAppActive(phase == .active)
            if phase == .active, stage.owner == nil { stage.claim(owner, config: config) }
        }
    }
}
