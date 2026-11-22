import XCTest
@testable import G13Kit

final class LCDFrameTests: XCTestCase {

    func testEmptyReportHasHeaderAndSize() {
        let report = LCDFrame().reportBytes()
        XCTAssertEqual(report.count, 992)
        XCTAssertEqual(report[0], 0x03)
        XCTAssertTrue(report[1...].allSatisfy { $0 == 0 })
    }

    func testTopLeftPixelIsBit0OfFirstDataByte() {
        var frame = LCDFrame()
        frame[0, 0] = true
        let report = frame.reportBytes()
        XCTAssertEqual(report[32], 0x01)
        XCTAssertEqual(frame.litPixelCount, 1)
    }

    func testPageAddressing() {
        var frame = LCDFrame()
        frame[5, 9] = true          // Page 1, Bit 1
        frame[159, 42] = true       // Page 5, Bit 2, letzte Spalte
        XCTAssertEqual(frame.buffer[160 + 5], 0x02)
        XCTAssertEqual(frame.buffer[5 * 160 + 159], 0x04)
        XCTAssertEqual(frame.reportBytes()[991], 0x04)
    }

    func testSetAndClearPixel() {
        var frame = LCDFrame()
        frame[10, 20] = true
        XCTAssertTrue(frame[10, 20])
        frame[10, 20] = false
        XCTAssertFalse(frame[10, 20])
        XCTAssertEqual(frame, LCDFrame())
    }

    func testOutOfBoundsIsIgnored() {
        var frame = LCDFrame()
        frame[-1, 0] = true
        frame[160, 0] = true
        frame[0, 43] = true          // unsichtbare Zeile
        XCTAssertEqual(frame, LCDFrame())
        XCTAssertFalse(frame[200, 200])
    }

    func testFillLightsOnlyVisibleRows() {
        var frame = LCDFrame()
        frame.fill()
        XCTAssertEqual(frame.litPixelCount, 160 * 43)
        // Page 5 enthält Zeilen 40–47, nur 40–42 sind sichtbar → Bits 0–2.
        XCTAssertEqual(frame.buffer[5 * 160], 0x07)
        frame.invert()
        XCTAssertEqual(frame, LCDFrame())
    }

    func testInitFromBufferChecksSize() {
        XCTAssertNil(LCDFrame(buffer: [0, 1, 2]))
        XCTAssertNotNil(LCDFrame(buffer: [UInt8](repeating: 0xFF, count: 960)))
    }

    func testTestPatternHasBorderAndMarker() {
        let frame = LCDFrame.testPattern()
        XCTAssertTrue(frame[0, 0])
        XCTAssertTrue(frame[159, 42])
        XCTAssertTrue(frame[4, 4])      // gefüllte Ecke oben links
        XCTAssertFalse(frame[155, 38])  // unten rechts innen frei
    }

    func testAsciiPreviewDimensions() {
        let lines = LCDFrame.testPattern().asciiPreview().split(separator: "\n")
        XCTAssertEqual(lines.count, 22 + 2)  // 43 Zeilen → 22 Textzeilen + Rahmen
        XCTAssertTrue(lines.allSatisfy { $0.count == 162 })
    }
}
