import SwiftUI
import UIKit
import WebKit

/// Pictures of dressed pets for the Pets tiles and share cards (PRD v0.3 §5.4, decided
/// 2026-11-12). The bundled stills can't show decorations and there are far too many outfits to
/// draw ahead, so a pet that wears something is photographed from its own pet.html in a second,
/// hidden web view (never the living pet's). Undressed pets keep the bundled stills.
///
/// Each picture is taken twice, on black and on white, and the two are turned into one picture
/// with a transparent background, so it can stand on any card and overlap its neighbours.
/// Pictures are cached in Caches/PetStills by pet, outfit and pose; one is taken at a time.
/// A web view that is not on screen may not draw: this one sits in the key window, almost fully
/// transparent. If a picture can't be taken, the bundled still stays (check on a real device).
@MainActor
@Observable
final class PetSnapper {
    static let shared = PetSnapper()

    /// The pose of a still: as it stands, ^^ eyes, or 骄傲挺胸.
    enum Pose: String {
        case neutral, happy, proud
    }

    struct Key: Hashable {
        let pet: String
        let decor: [String]
        let pose: Pose

        init(pet: String, decor: [String], pose: Pose) {
            self.pet = pet
            self.decor = decor.sorted()
            self.pose = pose
        }

        /// "toast-bandana+cowboy-proud"
        var file: String { "\(pet)-\(decor.joined(separator: "+"))-\(pose.rawValue)" }
    }

    /// Where the pet's 100 × 100 box sits in the picture (fractions of its side): room above for
    /// hats, at the sides for wings, below for capes.
    static let box = (x: 0.2, y: 0.25, size: 0.6)
    /// The web view's side, in points.
    private static let side: CGFloat = 360

    /// Bumped whenever a picture is ready, so pictures on screen look again.
    private(set) var version = 0

    @ObservationIgnored private var memory: [Key: UIImage] = [:]
    @ObservationIgnored private var queue: [Key] = []
    @ObservationIgnored private var waiting: [Key: [CheckedContinuation<UIImage?, Never>]] = [:]
    @ObservationIgnored private var busy = false
    @ObservationIgnored private var webView: WKWebView?
    @ObservationIgnored private var handler: SnapHandler?
    @ObservationIgnored private var ready = false
    /// Counts page loads, so a load's time-out never answers a later one.
    @ObservationIgnored private var loads = 0
    @ObservationIgnored private var readyWaiters: [CheckedContinuation<Bool, Never>] = []
    @ObservationIgnored private var shotWaiters: [String: CheckedContinuation<Bool, Never>] = [:]
    @ObservationIgnored private var shotCount = 0
    @ObservationIgnored private var idleTask: Task<Void, Never>?
    /// After a picture could not be taken, the bundled stills stay for this launch.
    @ObservationIgnored private var failed = false

    private init() {}

    // MARK: - Asking for pictures

    /// The picture if it was already taken (in memory or on disk); nil = use the bundled still.
    func image(for key: Key) -> UIImage? {
        _ = version
        if let image = memory[key] { return image }
        guard let image = UIImage(contentsOfFile: Self.url(for: key).path) else { return nil }
        memory[key] = image
        return image
    }

    /// The picture, taken now if there isn't one yet (nil when it can't be taken).
    @discardableResult
    func picture(for key: Key) async -> UIImage? {
        if let image = image(for: key) { return image }
        guard !failed, !key.decor.isEmpty else { return nil }
        return await withCheckedContinuation { continuation in
            waiting[key, default: []].append(continuation)
            if !queue.contains(key) { queue.append(key) }
            if !busy { Task { await run() } }
        }
    }

    /// Takes every picture `keys` needs (dressed pets only) and returns once they are there.
    func prepare(_ keys: [Key]) async {
        for key in keys where !key.decor.isEmpty {
            await picture(for: key)
        }
    }

    // MARK: - Taking them

    private func run() async {
        guard !busy else { return }
        busy = true
        idleTask?.cancel()
        while !queue.isEmpty {
            let key = queue.removeFirst()
            let image = failed ? nil : await shoot(key)
            if let image {
                memory[key] = image
                version += 1
            }
            for continuation in waiting.removeValue(forKey: key) ?? [] { continuation.resume(returning: image) }
        }
        busy = false
        // the hidden page goes away a while after the last picture
        idleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, !busy else { return }
            tearDown()
        }
    }

    private func shoot(_ key: Key) async -> UIImage? {
        guard await loadPage(for: key), let webView else { return nil }
        let config = PetShot(pet: key.pet, decor: key.decor, still: key.pose.rawValue)
        guard await draw(config, background: "#000"), let black = await snapshot(webView),
              await draw(config, background: "#FFF"), let white = await snapshot(webView) else {
            failed = true
            PetStage.shared.log("snapper: no picture of \(key.file); the bundled still stays")
            return nil
        }
        guard let matte = await Task.detached(priority: .utility, operation: { Self.matte(black: black, white: white) }).value else {
            failed = true
            PetStage.shared.log("snapper: the picture of \(key.file) came out empty; the bundled still stays")
            return nil
        }
        let image = UIImage(cgImage: matte)
        save(image, for: key)
        PetStage.shared.log("snapper: took \(key.file)")
        return image
    }

    /// Draws the still on `background` and waits until the page says it is on screen.
    private func draw(_ config: PetShot, background: String) async -> Bool {
        guard let webView else { return false }
        shotCount += 1
        let token = "s\(shotCount)"
        let js = "Pet.shoot(\(PetStage.json(config)), '\(token)', '\(background)')"
        return await withCheckedContinuation { continuation in
            shotWaiters[token] = continuation
            webView.evaluateJavaScript(js) { [weak self] _, error in
                guard error != nil else { return }
                MainActor.assumeIsolated { self?.finishShot(token, ok: false) }
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(6))
                self?.finishShot(token, ok: false)
            }
        }
    }

    private func finishShot(_ token: String, ok: Bool) {
        shotWaiters.removeValue(forKey: token)?.resume(returning: ok)
    }

    private func snapshot(_ webView: WKWebView) async -> CGImage? {
        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds
        config.snapshotWidth = NSNumber(value: Double(Self.side))
        config.afterScreenUpdates = true
        return await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: config) { image, _ in
                continuation.resume(returning: image?.cgImage)
            }
        }
    }

    // MARK: - The hidden page

    private func loadPage(for key: Key) async -> Bool {
        if webView == nil {
            guard let window = Self.keyWindow else { return false }
            let handler = SnapHandler(snapper: self)
            self.handler = handler
            let content = WKUserContentController()
            content.add(handler, name: "pet")
            let initial = PetShot(pet: key.pet, decor: key.decor, still: key.pose.rawValue)
            content.addUserScript(WKUserScript(source: "window.PET_INIT = \(PetStage.json(initial));",
                                               injectionTime: .atDocumentStart, forMainFrameOnly: true))
            let configuration = WKWebViewConfiguration()
            configuration.userContentController = content
            let web = WKWebView(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side), configuration: configuration)
            web.navigationDelegate = handler
            web.isOpaque = false
            web.backgroundColor = .clear
            web.scrollView.isScrollEnabled = false
            web.scrollView.contentInsetAdjustmentBehavior = .never
            web.isUserInteractionEnabled = false
            web.alpha = 0.01
            web.accessibilityElementsHidden = true
            window.addSubview(web)
            webView = web
            ready = false
            loads += 1
            if let url = Bundle.main.url(forResource: "pet", withExtension: "html") {
                web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            }
        }
        if ready { return true }
        let load = loads
        return await withCheckedContinuation { continuation in
            readyWaiters.append(continuation)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard let self, self.loads == load, !self.ready else { return }
                self.pageReady(false)
            }
        }
    }

    fileprivate func pageReady(_ ok: Bool) {
        if ok { ready = true }
        let waiters = readyWaiters
        readyWaiters = []
        waiters.forEach { $0.resume(returning: ok) }
    }

    fileprivate func receive(_ body: Any) {
        guard let message = body as? [String: Any], let type = message["type"] as? String else { return }
        switch type {
        case "ready": pageReady(true)
        case "shot": if let token = message["token"] as? String { finishShot(token, ok: true) }
        case "error": PetStage.shared.log("snapper page error: \(message["message"] as? String ?? "?")")
        default: break
        }
    }

    fileprivate func pageLost() {
        tearDown()
    }

    private func tearDown() {
        webView?.removeFromSuperview()
        webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        webView = nil
        handler = nil
        ready = false
        pageReady(false)
        for token in Array(shotWaiters.keys) { finishShot(token, ok: false) }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { $0.isKeyWindow }
    }

    // MARK: - The cache on disk

    private static let folder: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = caches.appendingPathComponent("PetStills", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static func url(for key: Key) -> URL {
        folder.appendingPathComponent(key.file + ".png")
    }

    /// Keeps the new picture and drops this pet's older ones in the same pose (an older outfit).
    private func save(_ image: UIImage, for key: Key) {
        let prefix = key.pet + "-", suffix = "-" + key.pose.rawValue + ".png", keep = key.file + ".png"
        if let names = try? FileManager.default.contentsOfDirectory(atPath: Self.folder.path) {
            for name in names where name.hasPrefix(prefix) && name.hasSuffix(suffix) && name != keep {
                try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(name))
            }
        }
        memory = memory.filter { $0.key.pet != key.pet || $0.key.pose != key.pose || $0.key == key }
        try? image.pngData()?.write(to: Self.url(for: key), options: .atomic)
    }

    // MARK: - Black + white → transparent

    /// One picture of the same frame on black and on white gives each pixel's coverage
    /// (white − black = how much background shows through) and its colour (the black one is
    /// already the colour times its coverage).
    nonisolated static func matte(black: CGImage, white: CGImage) -> CGImage? {
        let w = black.width, h = black.height
        guard w > 0, h > 0, white.width == w, white.height == h,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        func pixels(_ image: CGImage) -> [UInt8]? {
            var data = [UInt8](repeating: 0, count: w * h * 4)
            let drawn = data.withUnsafeMutableBytes { raw -> Bool in
                guard let context = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                              bytesPerRow: w * 4, space: space, bitmapInfo: info) else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
                return true
            }
            return drawn ? data : nil
        }
        guard let b = pixels(black), let wh = pixels(white) else { return nil }
        var out = [UInt8](repeating: 0, count: w * h * 4)
        var solid = 0
        var i = 0
        while i < out.count {
            let r = Int(b[i]), g = Int(b[i + 1]), bl = Int(b[i + 2])
            let through = (Int(wh[i]) - r + Int(wh[i + 1]) - g + Int(wh[i + 2]) - bl) / 3
            let alpha = min(255, max(255 - through, r, g, bl))
            out[i] = UInt8(r)
            out[i + 1] = UInt8(g)
            out[i + 2] = UInt8(bl)
            out[i + 3] = UInt8(alpha)
            if alpha >= 200 { solid += 1 }
            i += 4
        }
        // The pet fills a good part of the frame. Next to nothing means the page wasn't drawn; all of
        // it means the background never changed between the two pictures. Neither is a picture.
        let share = Double(solid) / Double(w * h)
        guard share > 0.03, share < 0.9 else { return nil }
        guard let provider = CGDataProvider(data: Data(out) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: info), provider: provider, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent)
    }
}

/// What the hidden page draws: one still, no shadow, the pet's box with room around it.
private struct PetShot: Encodable {
    let pet: String
    let decor: [String]
    let still: String
    var interactive = false
    var shadow = false
    var rug = false
    var dark = false
    var box = PetStageConfig.Box(x: PetSnapper.box.x, y: PetSnapper.box.y, size: PetSnapper.box.size)
}

/// Hears the hidden page; kept apart because WebKit retains its message handlers.
private final class SnapHandler: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    weak var snapper: PetSnapper?

    init(snapper: PetSnapper) {
        self.snapper = snapper
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body
        MainActor.assumeIsolated { snapper?.receive(body) }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        MainActor.assumeIsolated { snapper?.pageLost() }
    }
}

/// A dressed pet's picture laid over the place its bundled still takes (same box, so a dressed
/// and an undressed pet stand the same size); hats and wings reach past it.
struct DressedPicture: View {
    let image: UIImage

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let side = s / PetSnapper.box.size
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: side, height: side)
                .position(x: geo.size.width / 2 + (0.5 - (PetSnapper.box.x + PetSnapper.box.size / 2)) * side,
                          y: geo.size.height / 2 + (0.5 - (PetSnapper.box.y + PetSnapper.box.size / 2)) * side)
        }
        .allowsHitTesting(false)
    }
}
