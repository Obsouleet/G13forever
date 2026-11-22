import XCTest
@testable import G13Kit

final class BindingEngineTests: XCTestCase {

    private func report(_ keys: Set<G13Key> = [], x: UInt8 = 128, y: UInt8 = 128) -> G13InputReport {
        G13InputReport(joystickX: x, joystickY: y, rawKeys: keys)
    }

    private func profile(_ bindings: [G13Key: KeyAction], joystick: JoystickMode = .off) -> G13Profile {
        G13Profile(name: "Test", joystick: joystick, bindings: bindings)
    }

    func testShortcutIsHeldWhileKeyIsDown() {
        let combo = KeyCombo("cmd+c")!
        var engine = BindingEngine(profile: profile([.g1: .keys(combo)]))
        XCTAssertEqual(engine.handle(report([.g1])), [.keyDown(combo)])
        XCTAssertEqual(engine.handle(report([.g1])), [], "Gleicher Report löst nichts erneut aus")
        XCTAssertEqual(engine.handle(report()), [.keyUp(combo)])
    }

    func testTextAndProfileActionsFireOnPressOnly() {
        var engine = BindingEngine(profile: profile([.g2: .text("gg"), .m2: .profileSlot(2), .bd: .nextProfile]))
        XCTAssertEqual(engine.handle(report([.g2, .m2])), [.typeText("gg"), .switchToSlot(2)])
        XCTAssertEqual(engine.handle(report()), [])
        XCTAssertEqual(engine.handle(report([.bd])), [.nextProfile])
    }

    func testUnboundAndStatusBitsAreIgnored() {
        var engine = BindingEngine(profile: profile([:]))
        XCTAssertEqual(engine.handle(report([.g5, .lightState, .miscToggle])), [])
    }

    func testProfileSwitchWhileHoldingReleasesOldShortcut() {
        let old = KeyCombo("shift")!
        var engine = BindingEngine(profile: profile([.g1: .keys(old)]))
        XCTAssertEqual(engine.handle(report([.g1])), [.keyDown(old)])
        engine.profile = profile([.g1: .keys(KeyCombo("a")!)])
        XCTAssertEqual(engine.handle(report()), [.keyUp(old)])
    }

    func testReleaseBeforePress() {
        let a = KeyCombo("a")!, b = KeyCombo("b")!
        var engine = BindingEngine(profile: profile([.g1: .keys(a), .g2: .keys(b)]))
        _ = engine.handle(report([.g1]))
        XCTAssertEqual(engine.handle(report([.g2])), [.keyUp(a), .keyDown(b)])
    }

    func testJoystickArrows() {
        var engine = BindingEngine(profile: profile([:], joystick: .arrows))
        XCTAssertEqual(engine.handle(report(x: 140, y: 120)), [], "Innerhalb der Totzone")
        XCTAssertEqual(engine.handle(report(x: 255, y: 128)), [.keyDown(KeyCombo(key: "right"))])
        XCTAssertEqual(engine.handle(report(x: 255, y: 0)), [.keyDown(KeyCombo(key: "up"))])
        XCTAssertEqual(engine.handle(report(x: 128, y: 0)), [.keyUp(KeyCombo(key: "right"))])
        XCTAssertEqual(engine.handle(report()), [.keyUp(KeyCombo(key: "up"))])
    }

    func testJoystickWASDAndOff() {
        var engine = BindingEngine(profile: profile([:], joystick: .wasd))
        XCTAssertEqual(engine.handle(report(x: 0)), [.keyDown(KeyCombo(key: "a"))])
        engine.profile.joystick = .off
        XCTAssertEqual(engine.handle(report(x: 0)), [.keyUp(KeyCombo(key: "a"))], "Ausschalten lässt gehaltene Richtung los")
        XCTAssertEqual(engine.handle(report(y: 255)), [])
    }

    func testReleaseAll() {
        let combo = KeyCombo("cmd+v")!
        var engine = BindingEngine(profile: profile([.g3: .keys(combo)], joystick: .arrows))
        _ = engine.handle(report([.g3], x: 0))
        XCTAssertEqual(engine.releaseAll(), [.keyUp(combo), .keyUp(KeyCombo(key: "left"))])
        XCTAssertEqual(engine.releaseAll(), [])
        // Danach zählt dieselbe Taste wieder als neuer Druck.
        XCTAssertEqual(engine.handle(report([.g3])), [.keyDown(combo)])
    }
}
