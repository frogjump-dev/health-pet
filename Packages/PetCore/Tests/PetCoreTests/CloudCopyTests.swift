import XCTest
@testable import PetCore

/// iCloud keeps the app's own check-in records but no health values (PRD v0.3 §10.3 #19).
final class CloudCopyTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_731_456_000)

    private func line(_ key: String, _ kind: CreditKind, _ detail: String) -> CreditRecord {
        CreditRecord(id: "1731456000/\(key)", day: day, kind: kind, detail: detail, activity: .running,
                     bookedAt: day, auto: true, levelFrom: 3, levelTo: 4)
    }

    func testTheBareCopyCarriesNoValues() {
        let full = [line("workout:Run:32", .workout, "Run 32 min"), line("steps", .steps, "10,240 steps"),
                    line("night", .night, "Asleep 22:48"), line("load", .load, "Strain 11.4"),
                    line("workout:Table tennis:45", .workout, "Table tennis 45 min")]
        let bare = CreditRecord.bare(full)
        XCTAssertEqual(bare.map(\.detail), ["Run", "10k-step day", "Night's sleep", "Whoop strain", "Table tennis"])
        XCTAssertEqual(bare.map(\.id), ["1731456000/workout:Run#1", "1731456000/steps", "1731456000/night",
                                        "1731456000/load", "1731456000/workout:Table tennis#1"])
        // no digits left in what a line says, and no minutes in an id
        XCTAssertFalse(bare.contains { $0.detail.contains(where: \.isNumber) })
        XCTAssertFalse(bare.contains { $0.id.range(of: #":\d+"#, options: .regularExpression) != nil })
        // the app's own record stays: the pet, the levels, when and how it was booked
        XCTAssertEqual(bare[0].activity, .running)
        XCTAssertEqual(bare[0].levelFrom, 3)
        XCTAssertEqual(bare[0].levelTo, 4)
        XCTAssertEqual(bare[0].bookedAt, day)
        XCTAssertTrue(bare[0].auto)
        XCTAssertTrue(bare.allSatisfy(\.isBare))
        XCTAssertFalse(full.contains(where: \.isBare))
    }

    func testTwoRunsOnADayStayApart() {
        let ids = CreditRecord.bareIDs(["1/workout:Run:32", "1/workout:Run:45", "1/workout:Run:32#2",
                                        "2/workout:Run:32", "1/steps", "1/workout:Run#1"])
        XCTAssertEqual(ids, ["1/workout:Run#1", "1/workout:Run#2", "1/workout:Run#3",
                             "2/workout:Run#1", "1/steps", "1/workout:Run#1"])
    }

    func testABareLineStaysAsItIs() {
        let bare = CreditRecord.bare([line("workout:Run:32", .workout, "Run 32 min"), line("night", .night, "Asleep 22:48")])
        XCTAssertEqual(CreditRecord.bare(bare), bare)
    }
}
