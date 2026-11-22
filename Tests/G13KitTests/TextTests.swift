import XCTest
@testable import G13Kit

final class TextTests: XCTestCase {

    func testAllGlyphsHaveFiveColumnsAndSevenRows() {
        for (character, glyph) in BitmapFont.glyphs {
            XCTAssertEqual(glyph.count, 5, "Glyphe \(character)")
            XCTAssertTrue(glyph.allSatisfy { $0 < 0x80 }, "Glyphe \(character) ist höher als 7 Pixel")
        }
    }

    func testTextWidth() {
        XCTAssertEqual(BitmapFont.width(of: ""), 0)
        XCTAssertEqual(BitmapFont.width(of: "A"), 5)
        XCTAssertEqual(BitmapFont.width(of: "AB"), 11)
    }

    func testDrawLetterI() {
        var frame = LCDFrame()
        frame.drawText("I", x: 0, y: 0)
        // "I" hat in Spalte 2 einen durchgehenden Strich (0x7F).
        for row in 0..<7 { XCTAssertTrue(frame[2, row]) }
        XCTAssertFalse(frame[2, 7])
    }

    func testUnknownCharacterUsesFallback() {
        XCTAssertEqual(BitmapFont.glyph(for: "€"), BitmapFont.fallback)
    }

    func testWrapRespectsWidth() {
        let lines = LCDFrame.wrap("Das ist ein ziemlich langer Satz, der umbrochen werden muss")
        XCTAssertGreaterThan(lines.count, 1)
        XCTAssertTrue(lines.allSatisfy { BitmapFont.width(of: $0) <= LCDFrame.width })
    }

    func testWrapSplitsOverlongWord() {
        let lines = LCDFrame.wrap(String(repeating: "x", count: 30))
        XCTAssertEqual(lines.map(\.count), [26, 4])
    }

    func testCenteredTextIsCentered() {
        let frame = LCDFrame.text("I")
        // "I" ist 5 px breit → x = 77; Strich in Spalte 79, vertikal zentriert ab y = 18.
        XCTAssertTrue(frame[79, 18])
        XCTAssertTrue(frame[79, 24])
        XCTAssertFalse(frame[79, 17])
    }
}
