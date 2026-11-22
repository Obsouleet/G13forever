import XCTest
@testable import G13Kit

final class KeyComboTests: XCTestCase {

    func testParsesModifiersAndKey() {
        let combo = KeyCombo("cmd+shift+4")
        XCTAssertEqual(combo?.modifiers, [.command, .shift])
        XCTAssertEqual(combo?.key, "4")
    }

    func testGermanAndSymbolAliases() {
        XCTAssertEqual(KeyCombo("Strg+Alt+Entf"), KeyCombo(key: "forwarddelete", modifiers: [.control, .option]))
        XCTAssertEqual(KeyCombo("⌘+Z"), KeyCombo(key: "z", modifiers: [.command]))
        XCTAssertEqual(KeyCombo("Leertaste")?.key, "space")
        XCTAssertEqual(KeyCombo("ESC")?.key, "escape")
    }

    func testFunctionKeysAndSingleCharacters() {
        XCTAssertEqual(KeyCombo("F5")?.key, "f5")
        XCTAssertEqual(KeyCombo("ö")?.key, "ö")
        XCTAssertEqual(KeyCombo("ctrl++"), KeyCombo(key: "+", modifiers: [.control]))
        XCTAssertEqual(KeyCombo("+")?.key, "+")
    }

    func testModifierAsKey() {
        let shift = KeyCombo("shift")
        XCTAssertEqual(shift?.key, "shift")
        XCTAssertEqual(shift?.modifiers, [])
        XCTAssertEqual(KeyCodes.modifier(forKeyName: "shift"), .shift)
    }

    func testRejectsUnknown() {
        XCTAssertNil(KeyCombo(""))
        XCTAssertNil(KeyCombo("cmd+banane"))
        XCTAssertNil(KeyCombo("hyper+a"))
        XCTAssertNil(KeyCombo("cmd+"))
    }

    func testDescriptionRoundTrip() {
        for text in ["shift+cmd+4", "ctrl+opt+forwarddelete", "f12", "space", "ctrl++", "fn+left"] {
            let combo = KeyCombo(text)
            XCTAssertNotNil(combo, text)
            XCTAssertEqual(combo?.description, text)
            XCTAssertEqual(KeyCombo(combo!.description), combo)
        }
    }

    func testDisplayString() {
        XCTAssertEqual(KeyCombo("cmd+shift+4")?.displayString, "⇧⌘4")
        XCTAssertEqual(KeyCombo("ctrl+opt+up")?.displayString, "⌃⌥↑")
        XCTAssertEqual(KeyCombo("f5")?.displayString, "F5")
    }

    func testKeyCodes() {
        XCTAssertEqual(KeyCodes.code(for: "a"), 0x00)
        XCTAssertEqual(KeyCodes.code(for: "F5"), 0x60)
        XCTAssertEqual(KeyCodes.code(for: "f20"), 0x5A)
        XCTAssertEqual(KeyCodes.code(for: "up"), 0x7E)
        XCTAssertEqual(KeyCodes.code(for: "enter"), 0x24)
        XCTAssertEqual(KeyCodes.name(for: 0x24), "return")
        XCTAssertEqual(KeyCodes.name(for: 0x35), "escape")
        XCTAssertEqual(KeyCodes.name(for: 0x60), "f5")
        // Jeder Code höchstens einmal in der Tabelle.
        XCTAssertEqual(Set(KeyCodes.byName.values).count, KeyCodes.byName.count)
    }
}
