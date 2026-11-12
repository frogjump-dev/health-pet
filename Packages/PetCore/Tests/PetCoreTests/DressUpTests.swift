import XCTest
@testable import PetCore

/// The wardrobe's rules (PRD v0.3 §5.4, Dress up design v1 of 2026-11-12).
final class DressUpTests: XCTestCase {
    func testCatalogueMatchesTheDecorations() {
        XCTAssertEqual(Decor.all.count, 51)
        XCTAssertEqual(Set(Decor.all.map(\.id)).count, 51)
        XCTAssertEqual(Decor.of(.head).count, 11)
        for slot in [DecorSlot.eyes, .mouth, .neck, .back] { XCTAssertEqual(Decor.of(slot).count, 10) }
        XCTAssertEqual(Decor.with(id: "party")?.slot, .head)
        XCTAssertEqual(Decor.with(id: "bandana")?.name, "Bandana")
        XCTAssertEqual(DecorSlot.mouth.title, "Mouth")
    }

    func testOnePointADayAndFiveADraw() {
        var d = DressUp()
        XCTAssertTrue(d.collectPoint(day: "2026-11-12"))
        XCTAssertFalse(d.collectPoint(day: "2026-11-12"))
        XCTAssertEqual(d.points, 1)
        XCTAssertFalse(d.canDraw)
        XCTAssertNil(d.draw())
        for day in 13...16 { d.collectPoint(day: "2026-11-\(day)") }
        XCTAssertEqual(d.points, 5)
        XCTAssertEqual(d.pointsShort, 0)
        let id = d.draw()
        XCTAssertNotNil(id)
        XCTAssertEqual(d.points, 0)
        XCTAssertEqual(d.pointsShort, 5)
        XCTAssertTrue(d.fresh.contains(id!))
    }

    func testDrawsNeverRepeatAndPointsStopWhenAllCollected() {
        var d = DressUp()
        _ = d.giveWelcome()
        var generator = SeededGenerator(seed: 7)
        var day = 0
        while !d.allCollected {
            for _ in 0..<5 { day += 1; d.collectPoint(day: "day-\(day)") }
            XCTAssertNotNil(d.draw(using: &generator))
        }
        XCTAssertEqual(Set(d.owned).count, 51)
        XCTAssertEqual(d.owned.count, 51)
        XCTAssertEqual(d.draws, 50)
        XCTAssertFalse(d.collectPoint(day: "later"))
        XCTAssertFalse(d.canDraw)
    }

    func testWelcomeGiftIsTheFreePartyHatOnce() {
        var d = DressUp()
        d.collectPoint(day: "2026-11-12")
        XCTAssertFalse(d.drawPool.contains("party"))
        XCTAssertEqual(d.giveWelcome(), "party")
        XCTAssertNil(d.giveWelcome())
        XCTAssertEqual(d.owned, ["party"])
        XCTAssertEqual(d.points, 1)
        XCTAssertEqual(d.collected, 1)
        XCTAssertTrue(d.fresh.contains("party"))
    }

    func testOneItemPerSlotEachPetItsOwn() {
        var d = DressUp()
        d.owned = ["cowboy", "party", "bandana", "sunglasses"]
        d.fresh = ["party"]
        d.wear("bandana", on: "toast")
        d.wear("cowboy", on: "toast")
        XCTAssertEqual(d.outfit(for: "toast"), ["cowboy", "bandana"])
        d.wear("party", on: "toast")
        XCTAssertEqual(d.outfit(for: "toast"), ["party", "bandana"])
        XCTAssertFalse(d.fresh.contains("party"))
        d.wear("party", on: "chili")
        XCTAssertEqual(d.outfit(for: "chili"), ["party"])
        d.wear("crown", on: "chili")   // not owned
        XCTAssertEqual(d.outfit(for: "chili"), ["party"])
        d.takeOff(.head, from: "toast")
        XCTAssertEqual(d.outfit(for: "toast"), ["bandana"])
        XCTAssertEqual(d.worn(.neck, on: "toast"), "bandana")
        XCTAssertNil(d.worn(.head, on: "toast"))
    }

    func testTwoPhonesOnTheSameDayCountOnce() {
        var a = DressUp(), b = DressUp()
        a.collectPoint(day: "2026-11-12")
        b.collectPoint(day: "2026-11-12")
        b.collectPoint(day: "2026-11-11")
        a.merge(b)
        XCTAssertEqual(a.points, 2)
    }

    func testReinstallKeepsEverythingFromICloud() {
        var cloud = DressUp()
        _ = cloud.giveWelcome(at: Date(timeIntervalSince1970: 10))
        for day in 1...12 { cloud.collectPoint(day: "d\(day)") }
        _ = cloud.draw(at: Date(timeIntervalSince1970: 20))
        cloud.wear("party", on: "toast", at: Date(timeIntervalSince1970: 30))
        var fresh = DressUp()
        fresh.collectPoint(day: "today")
        fresh.merge(cloud)
        XCTAssertEqual(fresh.points, 13 - 5)
        XCTAssertEqual(fresh.owned, cloud.owned)
        XCTAssertTrue(fresh.welcomeGiven)
        XCTAssertEqual(fresh.outfit(for: "toast"), ["party"])
    }

    func testNewerLookWinsAndNewDotsStay() {
        var a = DressUp(), b = DressUp()
        a.owned = ["cowboy"]; b.owned = ["cowboy"]
        a.wear("cowboy", on: "toast", at: Date(timeIntervalSince1970: 100))
        b.owned.append("crown"); b.fresh.insert("crown"); b.lookChangedAt = Date(timeIntervalSince1970: 50)
        a.merge(b)
        XCTAssertEqual(a.outfit(for: "toast"), ["cowboy"])
        XCTAssertTrue(a.fresh.contains("crown"))
        XCTAssertEqual(a.owned, ["cowboy", "crown"])

        var c = DressUp()
        c.owned = ["cowboy"]
        c.takeOff(.head, from: "toast", at: Date(timeIntervalSince1970: 200))
        c.lookChangedAt = Date(timeIntervalSince1970: 200)
        a.merge(c)
        XCTAssertEqual(a.outfit(for: "toast"), [])
        XCTAssertTrue(a.fresh.contains("crown"))
    }

    func testOldDataAndUnknownFieldsStillRead() throws {
        let json = #"{"owned":["party","rocket"],"pointDays":["2026-11-12"],"somethingNew":1}"#
        let d = try JSONDecoder().decode(DressUp.self, from: Data(json.utf8))
        XCTAssertEqual(d.owned, ["party", "rocket"])
        XCTAssertEqual(d.collected, 1)
        XCTAssertFalse(d.welcomeGiven)
        let round = try JSONDecoder().decode(DressUp.self, from: JSONEncoder().encode(d))
        XCTAssertEqual(round, d)
    }

    func testDayKeyIsTheLocalDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let date = Date(timeIntervalSince1970: 1_794_441_600)   // 2026-11-12 00:00 UTC
        XCTAssertEqual(DressUp.dayKey(date, calendar: calendar), "2026-11-12")
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(DressUp.dayKey(date, calendar: calendar), "2026-11-11")
    }
}

/// A small fixed generator, so a test run always draws the same way.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
