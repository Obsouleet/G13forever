import XCTest
@testable import G13Kit

final class InputReportTests: XCTestCase {

    func testTooShortReportIsRejected() {
        XCTAssertNil(G13InputReport(bytes: [1, 2, 3]))
    }

    func testJoystickAndG1() {
        let report = G13InputReport(bytes: [0x01, 10, 200, 0x01, 0, 0, 0, 0])
        XCTAssertEqual(report?.joystickX, 10)
        XCTAssertEqual(report?.joystickY, 200)
        XCTAssertEqual(report?.pressedKeys, [.g1])
    }

    func testKeyBitPositions() {
        XCTAssertEqual(G13Key.allCases.count, 40)
        XCTAssertEqual(G13Key.g9.bitIndex, 8)
        XCTAssertEqual(G13Key.m1.bitIndex, 29)
        // M1 = Byte 3 + 3, Bit 5
        let report = G13InputReport(bytes: [0x01, 127, 127, 0, 0, 0, 0x20, 0])
        XCTAssertEqual(report?.pressedKeys, [.m1])
    }

    func testStatusBitsAreFiltered() {
        // LIGHT_STATE (Bit 23) und MISC_TOGGLE (Bit 39)
        let report = G13InputReport(bytes: [0x01, 127, 127, 0, 0, 0x80, 0, 0x80])
        XCTAssertEqual(report?.rawKeys, [.lightState, .miscToggle])
        XCTAssertEqual(report?.pressedKeys, [])
    }

    func testChanges() {
        let before = G13InputReport(rawKeys: [.g1, .g2])
        let after = G13InputReport(rawKeys: [.g2, .g3])
        let changes = after.changes(since: before)
        XCTAssertEqual(changes.pressed, [.g3])
        XCTAssertEqual(changes.released, [.g1])
    }
}
