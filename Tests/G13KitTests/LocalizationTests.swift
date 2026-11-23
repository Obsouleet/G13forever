#if canImport(Darwin)
import XCTest

final class LocalizationTests: XCTestCase {

    /// Andere Platzhalter in der Übersetzung wären falsche Anzeigen oder Abstürze.
    func testTranslationsKeepPlaceholders() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources")
        let languages = try FileManager.default.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "lproj" && $0.lastPathComponent != "en.lproj" }
        XCTAssertFalse(languages.isEmpty)

        for language in languages {
            let data = try Data(contentsOf: language.appendingPathComponent("Localizable.strings"))
            let table = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
            XCTAssertFalse(table.isEmpty)
            for (english, translation) in table {
                XCTAssertFalse(translation.isEmpty, english)
                XCTAssertEqual(placeholders(english), placeholders(translation), english)
            }
        }
    }

    private func placeholders(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(lld|@)")
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { (text as NSString).substring(with: $0.range) }
    }
}
#endif
