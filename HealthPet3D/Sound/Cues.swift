import Foundation

/// One sound of the design with its haptics (PRD v0.3 §8.4; files, tiers and tap times from
/// 3D方案/sfx-v1/spec.json). Tap times count from the start of the file.
struct Cue {
    let file: String
    let tier: Sounds.Tier
    var taps: [Haptics.Tap] = []
    /// A rhythm in Resources/Haptics instead of `taps`.
    var pattern: String? = nil

    /// The sound and its taps, `after` seconds from now; `gain` 0.5 = 6 dB lower; `haptics`
    /// false = the sound alone (another tap is already there).
    @MainActor
    func play(after delay: Double = 0, gain: Float = 1, haptics: Bool = true) {
        guard delay > 0 else { return start(gain: gain, haptics: haptics) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            start(gain: gain, haptics: haptics)
        }
    }

    @MainActor
    fileprivate func start(gain: Float, haptics: Bool = true) {
        Sounds.shared.play(file, tier: tier, gain: gain)
        guard haptics else { return }
        if let pattern { Haptics.shared.pattern(pattern) } else { Haptics.shared.play(taps) }
    }
}

/// The sounds of 「玩具厨房」 (sfx-v1, 2026-11-13). Only actions and what they earn make a sound:
/// tapping a bubble, dressing up, a draw, a picture, a celebration. Touching the pet only has
/// haptics for now (the user paused its voices on 2026-11-13); idle moves, automatic bookings
/// and navigation are silent. There is no failure sound.
@MainActor
enum Cues {
    // MARK: Feeding (HomeScreen.harvest: 0 s pop, 0.76 s crumbs in, 1.72 s the dot lands)

    static let pop = Cue(file: "harvest_pop", tier: .booking, taps: [.init(0.18, .soft, 0.6)])
    /// Its tap is home's swallow at 1.06 s (the bites feedback that was there already).
    static let nibble = Cue(file: "harvest_nibble", tier: .booking)
    /// This week's workout cells 1–3: C6 D6 E6 on the toy xylophone.
    static func workoutCell(_ number: Int) -> Cue {
        Cue(file: "cell_workout_\(min(max(number, 1), 3))", tier: .booking, taps: [.init(0, .rigid, 0.4)])
    }
    /// The night cells 1–5 (on time or the leave night): G6 A6 C7 D7 E7 on the music box.
    static func nightCell(_ number: Int) -> Cue {
        Cue(file: "cell_night_\(min(max(number, 1), 5))", tier: .booking, taps: [.init(0, .rigid, 0.4)])
    }
    /// A late night or Whoop strain into Memories: neutral, not a failure.
    static let toMemories = Cue(file: "to_memories", tier: .booking, taps: [.init(0.06, .selection, 0.3)])

    // MARK: The pet's moments, by expression (seconds after it starts, from the 对齐 column)

    static let hello = Cue(file: "hello", tier: .light)
    static let please = Cue(file: "please", tier: .light)
    static let nod = Cue(file: "nod", tier: .light, taps: [.init(0, .light, 0.4), .init(0.35, .light, 0.5)])
    static let cheerUp = Cue(file: "cheer_up", tier: .booking, taps: [.init(0, .selection, 0.3), .init(0.58, .soft, 0.7)])
    static let wakeUp = Cue(file: "wake_up", tier: .booking)
    static let proud = Cue(file: "proud", tier: .booking, taps: [.init(0.09, .soft, 0.5)])
    static let hop = Cue(file: "hop", tier: .booking, taps: [.init(0, .light, 0.5)])
    static let levelUp = Cue(file: "levelup", tier: .celebration, pattern: "levelup")
    static let newPet = Cue(file: "new_pet", tier: .celebration, taps: [.init(0.42, .success, 0.8)])
    static let weekDone = Cue(file: "week_done", tier: .celebration, pattern: "week_done")
    static let bigCheer = Cue(file: "big_cheer", tier: .celebration, pattern: "big_cheer")
    static let love = Cue(file: "love", tier: .celebration, pattern: "love")
    static let missYou = Cue(file: "miss_you", tier: .celebration, taps: [.init(0, .light, 0.4), .init(0.87, .soft, 0.6)])
    static let mirror = Cue(file: "mirror", tier: .light)
    static let photo = Cue(file: "photo", tier: .booking, taps: [.init(0, .rigid, 0.6)])

    /// What an expression the app asked for plays, and when: 醒来 says hello again when it
    /// recognises you (3.05 s), 照一照 turns twice. 好吃, 等一下, 拆礼物 and the idle ones are silent.
    static let byExpression: [String: [(at: Double, cue: Cue)]] = [
        "hello": [(0.1, hello)],
        "please": [(0.2, please)],
        "nod": [(0.22, nod)],
        "cheerup": [(1.2, cheerUp)],
        "wakeup": [(0, wakeUp), (3.05, hello)],
        "proud": [(1.11, proud)],
        "hop": [(0.23, hop)],
        "levelup": [(0.4, levelUp)],
        "starry": [(0.28, newPet)],
        "cheer": [(0.4, weekDone)],
        "bigcheer": [(0.98, bigCheer)],
        "love": [(0, love)],
        "missyou": [(0.75, missYou)],
        "mirror": [(0.2, mirror), (1.75, mirror)],
        "photo": [(0.95, photo)],
        // not an expression: the moment 等一下 finds the first open's 30 days and nods
        "found": [(0, nod)],
    ]

    private static var expressionRun = 0

    /// The pet's page started an expression. Any newer expression cuts the sounds of the one
    /// before; only moments the app asked for make a sound.
    static func expressionStarted(_ id: String, asked: Bool) {
        expressionRun += 1
        guard asked, let cues = byExpression[id] else { return }
        let run = expressionRun
        for (at, cue) in cues {
            Task { @MainActor in
                if at > 0 { try? await Task.sleep(for: .seconds(at)) }
                guard run == expressionRun else { return }
                cue.start(gain: 1)
            }
        }
    }

    // MARK: Dress up and the gift

    /// Put on: one music-box note per slot, lower from head to back (C7 A6 G6 E6 C6). The
    /// selection tap is the wardrobe's own (DressUpScreen).
    static func wearOn(_ slot: String) -> Cue { Cue(file: "wear_on_\(slot)", tier: .light) }
    static let wearOff = Cue(file: "wear_off", tier: .light)
    /// A tap on Draw without enough points: a soft rubbery "pf", never an error.
    static let softNo = Cue(file: "soft_no", tier: .light, taps: [.init(0, .soft, 0.3)])
    static let giftDrop = Cue(file: "gift_drop", tier: .booking, taps: [.init(0, .soft, 0.7), .init(0.15, .soft, 0.3)])
    /// The beads in the box, once per wobble of the gift card's box.
    static let giftShake = Cue(file: "gift_shake_loop", tier: .light,
                               taps: [0.05, 0.27, 0.49, 0.95, 1.17].map { Haptics.Tap($0, .light, 0.3) })
    /// Its success tap is the gift card's own (GiftSheet).
    static let giftOpen = Cue(file: "gift_open", tier: .celebration)

    // MARK: Touching the pet: haptics only for now

    /// What the page says a touch was: a tap (戳一戳), a tickle (the third tap in a row), dizzy
    /// (the sixth: no tap, it doesn't invite more), a yawn (woken from sleep: none either).
    static func touched(_ kind: String) {
        switch kind {
        case "tap": Haptics.shared.tap(.soft, 0.5)
        case "tickle": Haptics.shared.pattern("giggle")
        default: break
        }
    }
}
