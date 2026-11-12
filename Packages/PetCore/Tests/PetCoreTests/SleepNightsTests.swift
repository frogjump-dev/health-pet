import XCTest
@testable import PetCore

/// Sleep stretches sorted into nights with the 18:00 cut (PRD v0.3 §7.2, review 11-10 二 · 1).
final class SleepNightsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Monday 2026-10-26, 00:00 UTC.
    private let monday = Date(timeIntervalSince1970: 1_792_972_800)

    private func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: monday)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func stretch(_ from: Date, _ to: Date) -> DateInterval { DateInterval(start: from, end: to) }

    func testStretchesBeforeMidnightBelongToTheNextMorning() {
        // Asleep 22:48 Monday; the watch writes short stretches, the first ones end before midnight.
        let stretches = [
            stretch(at(0, 22, 48), at(0, 23, 10)),
            stretch(at(0, 23, 10), at(0, 23, 45)),
            stretch(at(0, 23, 45), at(1, 3, 0)),
            stretch(at(1, 3, 20), at(1, 6, 50))
        ]
        let nights = SleepNights.nights(stretches, calendar: calendar)
        XCTAssertEqual(Array(nights.keys), [at(1, 0)], "one night, counted on Tuesday morning")
        let night = nights[at(1, 0)]!
        XCTAssertEqual(night.onset, at(0, 22, 48), "not 23:45, the first stretch that ends after midnight")
        XCTAssertEqual(night.wake, at(1, 6, 50))
        XCTAssertEqual(night.hours, 7.7, accuracy: 0.001, "22:48–03:00 plus 03:20–06:50")
    }

    func testOverlappingSourcesAreCountedOnce() {
        // Watch and phone both recorded the same night.
        let stretches = [
            stretch(at(0, 23, 0), at(1, 7, 0)),
            stretch(at(0, 23, 30), at(1, 6, 0)),
            stretch(at(1, 6, 30), at(1, 7, 30))
        ]
        let night = SleepNights.nights(stretches, calendar: calendar)[at(1, 0)]!
        XCTAssertEqual(night.hours, 8.5, accuracy: 0.001)
        XCTAssertEqual(night.onset, at(0, 23, 0))
        XCTAssertEqual(night.wake, at(1, 7, 30))
    }

    func testEighteenHundredIsTheCut() {
        let stretches = [
            stretch(at(0, 17, 30), at(0, 17, 50)), // a nap: still Monday's night
            stretch(at(0, 18, 0), at(0, 18, 20))   // an early evening doze: Tuesday's night
        ]
        let nights = SleepNights.nights(stretches, calendar: calendar)
        XCTAssertEqual(nights[at(0, 0)]?.onset, at(0, 17, 30))
        XCTAssertEqual(nights[at(1, 0)]?.onset, at(0, 18, 0))
    }

    func testAnAfternoonNapAddsHoursButKeepsTheWakeTime() {
        let stretches = [
            stretch(at(0, 23, 0), at(1, 6, 30)),
            stretch(at(1, 14, 0), at(1, 14, 30))
        ]
        let night = SleepNights.nights(stretches, calendar: calendar)[at(1, 0)]!
        XCTAssertEqual(night.onset, at(0, 23, 0))
        XCTAssertEqual(night.wake, at(1, 6, 30))
        XCTAssertEqual(night.hours, 8, accuracy: 0.001)
    }

    func testAsleepAfterMidnightStaysOnThatMorning() {
        let night = SleepNights.nights([stretch(at(1, 1, 15), at(1, 8, 0))], calendar: calendar)[at(1, 0)]!
        XCTAssertEqual(night.onset, at(1, 1, 15))
    }

    func testNoStretchesNoNights() {
        XCTAssertTrue(SleepNights.nights([], calendar: calendar).isEmpty)
    }
}
