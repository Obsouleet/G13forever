import CoreGraphics
import XCTest
@testable import G13Kit

final class ArtworkTests: XCTestCase {
    func testEveryBindableKeyHasAZone() {
        XCTAssertEqual(Set(G13Artwork.standard.zones.keys), Set(G13Profile.bindableKeys))
    }

    func testZonesLieInsideAndDoNotOverlap() {
        let art = G13Artwork.standard
        let zones = art.zones.map { ($0.key, $0.value) }
        for (index, (key, path)) in zones.enumerated() {
            XCTAssertTrue(art.viewBox.contains(path.boundingBox), "\(key) liegt außerhalb")
            for (other, otherPath) in zones[(index + 1)...] {
                XCTAssertTrue(path.intersection(otherPath).isEmpty, "\(key) überlappt \(other)")
            }
        }
    }

    func testImageAndLCDArePresent() throws {
        XCTAssertFalse(G13Artwork.imageData.isEmpty)
        let lcd = try XCTUnwrap(G13Artwork.standard.lcd)
        XCTAssertTrue(G13Artwork.standard.viewBox.contains(lcd))
    }

    func testReadsShapesAndIgnoresUnknownIDs() throws {
        let svg = #"<svg viewBox="1 2 10 20"><polygon id="G1" points="1,2 4,2 4,6 1,6"/><circle id="STICK" cx="5" cy="5" r="2"/><rect id="LCD" x="1" y="1" width="4" height="1"/><rect id="deko" width="1" height="1"/></svg>"#
        let art = try XCTUnwrap(G13Artwork(svg: Data(svg.utf8)))
        XCTAssertEqual(art.viewBox, CGRect(x: 1, y: 2, width: 10, height: 20))
        XCTAssertEqual(Set(art.zones.keys), [.g1, .stick])
        XCTAssertEqual(art.zones[.g1]?.boundingBox, CGRect(x: 1, y: 2, width: 3, height: 4))
        XCTAssertEqual(art.zones[.stick]?.boundingBox, CGRect(x: 3, y: 3, width: 4, height: 4))
        XCTAssertEqual(art.lcd, CGRect(x: 1, y: 1, width: 4, height: 1))
    }

    func testRoundedPolygonCutsCornersButKeepsEdges() {
        let square = [CGPoint(x: 0, y: 0), CGPoint(x: 20, y: 0), CGPoint(x: 20, y: 20), CGPoint(x: 0, y: 20)]
        let path = G13Artwork.roundedPolygon(square, radius: 5)
        XCTAssertFalse(path.contains(CGPoint(x: 0.5, y: 0.5)))
        XCTAssertTrue(path.contains(CGPoint(x: 10, y: 0.5)))
        XCTAssertEqual(path.boundingBoxOfPath, CGRect(x: 0, y: 0, width: 20, height: 20))
        // Zu großer Radius wird auf die halbe Kante begrenzt, es bleibt ein Kreis.
        let circle = G13Artwork.roundedPolygon(square, radius: 100)
        XCTAssertEqual(circle.boundingBoxOfPath.width, 20, accuracy: 0.01)
    }

    func testRejectsBrokenSVG() {
        XCTAssertNil(G13Artwork(svg: Data("kaputt".utf8)))
        XCTAssertNil(G13Artwork(svg: Data("<svg></svg>".utf8)))
    }
}
