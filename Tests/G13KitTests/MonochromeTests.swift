import XCTest
@testable import G13Kit

final class MonochromeTests: XCTestCase {

    func testWhiteImageLightsEverything() {
        let frame = LCDFrame(grayscale: GrayscaleImage(fill: 255), mode: .threshold(128))
        XCTAssertEqual(frame.litPixelCount, 160 * 43)
    }

    func testBlackImageLightsNothing() {
        let frame = LCDFrame(grayscale: GrayscaleImage(fill: 0), mode: .floydSteinberg)
        XCTAssertEqual(frame.litPixelCount, 0)
    }

    func testInvertSwapsMeaning() {
        let frame = LCDFrame(grayscale: GrayscaleImage(fill: 0), mode: .threshold(128), invert: true)
        XCTAssertEqual(frame.litPixelCount, 160 * 43)
    }

    func testFloydSteinbergHalftoneIsAboutHalf() {
        let frame = LCDFrame(grayscale: GrayscaleImage(fill: 128), mode: .floydSteinberg)
        let ratio = Double(frame.litPixelCount) / Double(160 * 43)
        XCTAssertEqual(ratio, 0.5, accuracy: 0.05)
    }

    func testThresholdKeepsPosition() {
        var image = GrayscaleImage(fill: 0)
        image[3, 40] = 255
        let frame = LCDFrame(grayscale: image, mode: .threshold(128))
        XCTAssertEqual(frame.litPixelCount, 1)
        XCTAssertTrue(frame[3, 40])
    }
}
