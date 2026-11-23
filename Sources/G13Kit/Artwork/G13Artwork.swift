// G13Artwork.swift
// Das Bild der G13 (g13.svg) und die Klickflächen der Tasten (g13-keys.svg).

import CoreGraphics
import Foundation

/// Klickflächen der G13-Tasten, gelesen aus einer SVG: Elemente, deren id einem G13Key entspricht.
public struct G13Artwork {
    /// Sichtbarer Ausschnitt in SVG-Koordinaten (Ursprung oben links). Auch die Flächen liegen darin.
    public let viewBox: CGRect
    public let zones: [G13Key: CGPath]
    /// Wo das Display sitzt (Element mit id "LCD").
    public let lcd: CGRect?

    public static let standard = G13Artwork(svg: resource("g13-keys.svg"))!
    /// Das Bild selbst, gezeichnet in denselben Koordinaten.
    public static var imageData: Data { resource("g13.svg") }

    /// In der gebündelten App liegen die Dateien in Contents/Resources, sonst im SwiftPM-Bundle.
    private static func resource(_ name: String) -> Data {
        let url = Bundle.main.url(forResource: name, withExtension: nil)
            ?? Bundle.module.url(forResource: name, withExtension: nil)
        guard let url, let data = try? Data(contentsOf: url) else { fatalError("\(name) fehlt") }
        return data
    }

    /// Liefert `nil`, wenn die SVG nicht lesbar ist oder keine viewBox hat.
    public init?(svg: Data) {
        let reader = Reader()
        let parser = XMLParser(data: svg)
        parser.delegate = reader
        guard parser.parse(), let viewBox = reader.viewBox else { return nil }
        self.viewBox = viewBox
        zones = reader.zones
        lcd = reader.lcd
    }

    private final class Reader: NSObject, XMLParserDelegate {
        var viewBox: CGRect?
        var zones: [G13Key: CGPath] = [:]
        var lcd: CGRect?

        func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            func numbers(_ name: String) -> [CGFloat] {
                (attributes[name] ?? "").split(whereSeparator: { " ,\n\t".contains($0) })
                    .compactMap { Double($0) }.map { CGFloat($0) }
            }
            func number(_ name: String) -> CGFloat { numbers(name).first ?? 0 }

            if element == "svg" {
                let box = numbers("viewBox")
                if box.count == 4 { viewBox = CGRect(x: box[0], y: box[1], width: box[2], height: box[3]) }
                return
            }
            guard let id = attributes["id"] else { return }
            let path: CGPath
            switch element {
            case "rect":
                let rect = CGRect(x: number("x"), y: number("y"), width: number("width"), height: number("height"))
                if id == "LCD" { lcd = rect }
                path = CGPath(rect: rect, transform: nil)
            case "circle":
                let r = number("r")
                path = CGPath(ellipseIn: CGRect(x: number("cx") - r, y: number("cy") - r, width: 2 * r, height: 2 * r), transform: nil)
            case "polygon":
                let values = numbers("points")
                guard values.count >= 6, values.count.isMultiple(of: 2) else { return }
                let polygon = CGMutablePath()
                polygon.addLines(between: stride(from: 0, to: values.count, by: 2).map { CGPoint(x: values[$0], y: values[$0 + 1]) })
                polygon.closeSubpath()
                path = polygon
            default:
                return
            }
            if let key = G13Key(rawValue: id) { zones[key] = path }
        }
    }
}
