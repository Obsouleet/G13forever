import XCTest
@testable import G13Kit

final class ProfileTests: XCTestCase {

    func testActionJSONFormat() throws {
        let data = try JSONEncoder().encode(KeyAction.keys(KeyCombo("cmd+c")!))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: String]
        XCTAssertEqual(object, ["type": "keys", "shortcut": "cmd+c"])
    }

    func testActionRoundTrip() throws {
        let actions: [KeyAction] = [
            .keys(KeyCombo("ctrl+opt+f5")!), .text("Hallo Welt"), .profileSlot(2), .nextProfile, .previousProfile,
        ]
        for action in actions {
            let data = try JSONEncoder().encode(action)
            XCTAssertEqual(try JSONDecoder().decode(KeyAction.self, from: data), action)
        }
    }

    func testProfileRoundTrip() throws {
        var profile = G13Profile(name: "Spiel", backlight: RGBColor(red: 255, green: 0, blue: 10))
        profile.joystick = .wasd
        profile.display = DisplaySettings(imageFile: "x.gif", scale: .fill, dither: false, threshold: 90, invert: true)
        profile.bindings[.g1] = .keys(KeyCombo("space")!)
        profile.bindings[.g22] = .text("gg")
        let data = try JSONEncoder().encode(profile)
        XCTAssertEqual(try JSONDecoder().decode(G13Profile.self, from: data), profile)
    }

    func testProfileDecodingIsLenient() throws {
        let json = """
        {"name": "Alt", "bindings": {
            "G1": {"type": "keys", "shortcut": "f1"},
            "G99": {"type": "keys", "shortcut": "f2"},
            "G2": {"type": "zaubern"},
            "G3": {"type": "keys", "shortcut": "cmd+banane"}
        }}
        """
        let profile = try JSONDecoder().decode(G13Profile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.name, "Alt")
        XCTAssertEqual(profile.bindings, [.g1: .keys(KeyCombo("f1")!)])
        XCTAssertEqual(profile.joystick, .off)
        XCTAssertEqual(profile.display, DisplaySettings())
    }

    func testDefaultLibraryAndSwitching() {
        var library = ProfileLibrary.makeDefault()
        XCTAssertEqual(library.profiles.count, 3)
        XCTAssertEqual(library.activeIndex, 0)
        XCTAssertEqual(library.profiles[0].bindings[.m2], .profileSlot(2))

        XCTAssertTrue(library.activate(slot: 3))
        XCTAssertEqual(library.activeIndex, 2)
        XCTAssertFalse(library.activate(slot: 4))
        XCTAssertEqual(library.activeIndex, 2)

        library.activateNext()
        XCTAssertEqual(library.activeIndex, 0)
        library.activatePrevious()
        XCTAssertEqual(library.activeIndex, 2)

        library.activeProfileID = UUID()
        XCTAssertEqual(library.activeIndex, 0, "Unbekannte ID fällt aufs erste Profil zurück")
    }

    func testStoreSaveLoadAndImages() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfileStore(directory: directory)

        XCTAssertEqual(try store.load().profiles.count, 3, "Ohne Datei gibt es die Standardprofile")

        let source = directory.appendingPathComponent("quelle.PNG")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: source)
        let imported = try store.importImage(from: source)
        XCTAssertTrue(imported.hasSuffix(".png"))
        let unused = try store.importImage(from: source)

        var library = ProfileLibrary.makeDefault()
        library.profiles[1].display.imageFile = imported
        library.activate(slot: 2)
        try store.save(library)
        XCTAssertEqual(try store.load(), library)

        store.removeUnusedImages(keeping: library)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.imageURL(for: imported).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.imageURL(for: unused).path))
    }
}
