import XCTest
@testable import PetCore

final class BondTests: XCTestCase {
    func testLevelThresholds() {
        XCTAssertEqual(Bond(points: 0).level, 1)
        XCTAssertEqual(Bond(points: 49).level, 1)
        XCTAssertEqual(Bond(points: 50).level, 2)
        XCTAssertEqual(Bond(points: 150).level, 3)
        XCTAssertEqual(Bond(points: 499).level, 4)
        XCTAssertEqual(Bond(points: 500).level, 5)
    }

    func testProgressWithinLevel() {
        let progress = Bond(points: 700).progress
        XCTAssertEqual(progress.current, 200)
        XCTAssertEqual(progress.needed, 250)
    }

    func testPointsNeverGoNegative() {
        var bond = Bond(points: -5)
        bond.add(-10)
        XCTAssertEqual(bond.points, 0)
    }
}
