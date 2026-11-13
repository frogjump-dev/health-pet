import AVFoundation
import CoreHaptics
import UIKit

/// Settings → Sounds & Haptics (PRD v0.3 §8.4): two switches, both on at first, each on its own,
/// kept on this phone like the appearance. They only cover the app's own sounds and taps.
enum FeelSettings {
    static let soundKey = "3d.soundEffects"
    static let hapticsKey = "3d.haptics"
    static var sound: Bool { UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true }
    static var haptics: Bool { UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true }
}

/// The app's sounds (sfx-v1 「玩具厨房」, decided 2026-11-13): 36 short files in
/// Resources/Sounds, read once at launch and played from Swift, not from the pet's page.
/// - The session is `.ambient`: the ring/silent switch mutes it, and it mixes with whatever music
///   or podcast is playing without stopping or ducking it.
/// - At most two at a time: a third one drops the lightest (the newer one wins a tie); the same
///   sound doesn't start twice within 0.12 s; nothing plays unless the app is in the foreground.
@MainActor
final class Sounds {
    static let shared = Sounds()

    /// The three loudness tiers of the design (L1 a light tap, L2 a booking, L3 a celebration);
    /// the files are already levelled, so this only decides which sound gives way.
    enum Tier: Int {
        case light = 1, booking, celebration
    }

    private final class Voice {
        let node = AVAudioPlayerNode()
        var tier = Tier.light
        var endsAt: TimeInterval = 0
    }

    private final class Loaded: @unchecked Sendable {
        var buffers: [String: AVAudioPCMBuffer] = [:]
    }

    private let engine: AVAudioEngine
    private var voices: [Voice] = []
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var lastStart: [String: TimeInterval] = [:]
    private var started = false
    private var foreground = true

    private init() {
        engine = AVAudioEngine()
    }

    /// At launch: the session, the files (read off the main thread) and the two voices.
    func prepare() {
        guard !started else { return }
        started = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Sounds.shared.foreground = true }
        }
        center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Sounds.shared.goQuiet() }
        }
        Task.detached(priority: .utility) {
            let loaded = Sounds.load()
            await MainActor.run { Sounds.shared.setUp(loaded.buffers) }
        }
    }

    private nonisolated static func load() -> Loaded {
        let loaded = Loaded()
        for url in Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? [] {
            guard let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil else { continue }
            loaded.buffers[url.deletingPathExtension().lastPathComponent] = buffer
        }
        return loaded
    }

    private func setUp(_ loaded: [String: AVAudioPCMBuffer]) {
        // the voices are wired for the files' format (all 44.1 kHz mono); a file in another one is left out
        guard let format = loaded["harvest_pop"]?.format ?? loaded.values.first?.format else { return }
        buffers = loaded.filter { $0.value.format == format }
        for _ in 0..<2 {
            let voice = Voice()
            engine.attach(voice.node)
            engine.connect(voice.node, to: engine.mainMixerNode, format: format)
            voices.append(voice)
        }
        engine.prepare()
        log("\(buffers.count) files")
    }

    /// Plays `name` (a file in Resources/Sounds, without .wav) now; `gain` 0.5 = 6 dB lower.
    func play(_ name: String, tier: Tier, gain: Float = 1) {
        guard FeelSettings.sound, foreground, let buffer = buffers[name], !voices.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastStart[name], now - last < 0.12 { return }
        let voice: Voice
        if let free = voices.first(where: { $0.endsAt <= now }) {
            voice = free
        } else {
            // both voices busy: the lightest gives way (the older of two equals), unless this one is lighter still
            guard let lightest = voices.min(by: { ($0.tier.rawValue, $0.endsAt) < ($1.tier.rawValue, $1.endsAt) }),
                  tier.rawValue >= lightest.tier.rawValue else { return }
            voice = lightest
        }
        if !engine.isRunning {
            // first sound, or the engine stopped (a call, a new route, a configuration change)
            try? AVAudioSession.sharedInstance().setActive(true)
            guard (try? engine.start()) != nil else { return }
        }
        voice.node.stop()
        voice.node.volume = gain
        voice.node.scheduleBuffer(buffer, at: nil, options: [])
        voice.node.play()
        voice.tier = tier
        voice.endsAt = now + Double(buffer.frameLength) / buffer.format.sampleRate
        lastStart[name] = now
        log(gain < 1 ? "\(name) \(gain)" : name)
    }

    /// Debug builds print each sound (`[sound] harvest_pop`), so a simulator run can show what played.
    private func log(_ text: String) {
        #if DEBUG
        FileHandle.standardError.write(Data("[sound] \(text)\n".utf8))
        #endif
    }

    /// The app leaves the foreground: whatever is playing stops, and the engine rests.
    private func goQuiet() {
        foreground = false
        for voice in voices {
            voice.node.stop()
            voice.endsAt = 0
        }
        if engine.isRunning { engine.pause() }
    }
}

/// The app's taps (PRD v0.3 §8.4): a single tap through UIKit's feedback generators, a rhythm
/// (升级, 自律周, 大庆祝, 喜欢你, 挠痒, 摸摸) from an AHAP file in Resources/Haptics through Core Haptics.
/// Never .error / .warning. The system's own haptics switch still has the last word.
@MainActor
final class Haptics {
    static let shared = Haptics()

    enum Kind {
        case soft, light, rigid, selection, success
    }

    /// One tap of a sound's haptics, `at` seconds into the sound.
    struct Tap {
        let at: Double
        let kind: Kind
        let intensity: Double

        init(_ at: Double, _ kind: Kind, _ intensity: Double) {
            self.at = at
            self.kind = kind
            self.intensity = intensity
        }
    }

    private let soft: UIImpactFeedbackGenerator
    private let light: UIImpactFeedbackGenerator
    private let rigid: UIImpactFeedbackGenerator
    private let selection: UISelectionFeedbackGenerator
    private let notification: UINotificationFeedbackGenerator
    private let supported: Bool
    private var engine: CHHapticEngine?
    private var patterns: [String: CHHapticPattern] = [:]
    private var purr: CHHapticAdvancedPatternPlayer?

    private init() {
        soft = UIImpactFeedbackGenerator(style: .soft)
        light = UIImpactFeedbackGenerator(style: .light)
        rigid = UIImpactFeedbackGenerator(style: .rigid)
        selection = UISelectionFeedbackGenerator()
        notification = UINotificationFeedbackGenerator()
        supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private var allowed: Bool { FeelSettings.haptics && UIApplication.shared.applicationState == .active }

    func tap(_ kind: Kind, _ intensity: Double) {
        guard allowed else { return }
        let i = CGFloat(intensity)
        switch kind {
        case .soft: soft.impactOccurred(intensity: i)
        case .light: light.impactOccurred(intensity: i)
        case .rigid: rigid.impactOccurred(intensity: i)
        case .selection: selection.selectionChanged()
        case .success: notification.notificationOccurred(.success)
        }
    }

    /// A sound's taps, timed from now.
    func play(_ taps: [Tap]) {
        for tap in taps {
            if tap.at <= 0 {
                self.tap(tap.kind, tap.intensity)
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(tap.at))
                    self.tap(tap.kind, tap.intensity)
                }
            }
        }
    }

    /// A rhythm from Resources/Haptics/`name`.ahap, from now.
    func pattern(_ name: String) {
        guard allowed, let engine = runningEngine(), let pattern = load(name) else { return }
        try? engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
    }

    /// 摸摸: a soft purr while the finger stays on the pet (pat.ahap, one stroke on a loop).
    func startPurr() {
        guard purr == nil, allowed, let engine = runningEngine(), let pattern = load("pat"),
              let player = try? engine.makeAdvancedPlayer(with: pattern) else { return }
        player.loopEnabled = true
        player.loopEnd = pattern.duration
        guard (try? player.start(atTime: CHHapticTimeImmediate)) != nil else { return }
        purr = player
        // never longer than a long stroke, in case the page doesn't hear the finger lift
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(20))
            if purr === player { stopPurr() }
        }
    }

    func stopPurr() {
        try? purr?.stop(atTime: CHHapticTimeImmediate)
        purr = nil
    }

    private func load(_ name: String) -> CHHapticPattern? {
        if let pattern = patterns[name] { return pattern }
        guard let url = Bundle.main.url(forResource: name, withExtension: "ahap"),
              let pattern = try? CHHapticPattern(contentsOf: url) else { return nil }
        patterns[name] = pattern
        return pattern
    }

    private func runningEngine() -> CHHapticEngine? {
        guard supported else { return nil }
        if engine == nil {
            guard let made = try? CHHapticEngine() else { return nil }
            made.playsHapticsOnly = true
            made.isAutoShutdownEnabled = true
            // after a reset (the haptic server restarted) the old players are gone
            made.resetHandler = {
                Task { @MainActor in
                    Haptics.shared.purr = nil
                    try? Haptics.shared.engine?.start()
                }
            }
            made.stoppedHandler = { _ in
                Task { @MainActor in Haptics.shared.purr = nil }
            }
            engine = made
        }
        try? engine?.start()
        return engine
    }
}
