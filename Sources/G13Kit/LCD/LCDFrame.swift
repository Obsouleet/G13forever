// LCDFrame.swift
// Framebuffer für das monochrome 160x43-LCD der Logitech G13.
//
// Speicherlayout (übereinstimmend dokumentiert von golgote/G13 und
// jonas-werner/g13-configurator, beide MIT, siehe THIRD_PARTY_NOTICES.md):
//   Der Controller adressiert 6 horizontale "Pages" zu je 8 Zeilen
//   (48 Zeilen, sichtbar sind nur die oberen 43). Jedes Byte ist eine
//   Spalte innerhalb einer Page, Bit N = Zeile N innerhalb der Page.
//   Pixel (x, y): Index = (y / 8) * 160 + x, Bit = y % 8.
//
// Ein Frame geht als Output-Report 0x03 an das Gerät: 32 Byte Header
// (nur Byte 0 = 0x03 gesetzt), danach die 960 Byte Pixeldaten, zusammen
// 992 Byte.

/// Ein Bild für das G13-Display. `true` heißt: Pixel ist "an" und leuchtet hell.
public struct LCDFrame: Equatable, Sendable {

    public static let width = 160
    public static let height = 43
    public static let pages = 6
    public static let bufferSize = width * pages          // 960
    public static let headerSize = 32
    public static let reportSize = headerSize + bufferSize // 992
    public static let reportID: UInt8 = 0x03

    /// Page-adressierte Rohdaten, 960 Byte.
    public private(set) var buffer: [UInt8]

    public init() {
        buffer = [UInt8](repeating: 0, count: LCDFrame.bufferSize)
    }

    /// Erzeugt einen Frame aus 960 Byte Rohdaten (z. B. aus einer Datei).
    public init?(buffer: [UInt8]) {
        guard buffer.count == LCDFrame.bufferSize else { return nil }
        self.buffer = buffer
    }

    public static func isInside(x: Int, y: Int) -> Bool {
        x >= 0 && x < width && y >= 0 && y < height
    }

    /// Liest oder setzt ein Pixel. Koordinaten außerhalb werden ignoriert
    /// (Lesen liefert dort `false`).
    public subscript(x: Int, y: Int) -> Bool {
        get {
            guard LCDFrame.isInside(x: x, y: y) else { return false }
            return buffer[(y / 8) * LCDFrame.width + x] & (1 << UInt8(y % 8)) != 0
        }
        set {
            guard LCDFrame.isInside(x: x, y: y) else { return }
            let index = (y / 8) * LCDFrame.width + x
            let mask = UInt8(1 << (y % 8))
            if newValue { buffer[index] |= mask } else { buffer[index] &= ~mask }
        }
    }

    public mutating func clear() {
        for i in buffer.indices { buffer[i] = 0 }
    }

    /// Schaltet alle sichtbaren Pixel an (die unsichtbaren Zeilen 43–47 bleiben aus).
    public mutating func fill() {
        for y in 0..<LCDFrame.height {
            for x in 0..<LCDFrame.width { self[x, y] = true }
        }
    }

    /// Kehrt alle sichtbaren Pixel um.
    public mutating func invert() {
        for y in 0..<LCDFrame.height {
            for x in 0..<LCDFrame.width { self[x, y].toggle() }
        }
    }

    /// Anzahl gesetzter Pixel (praktisch für Tests und Diagnose).
    public var litPixelCount: Int {
        var count = 0
        for y in 0..<LCDFrame.height {
            for x in 0..<LCDFrame.width where self[x, y] { count += 1 }
        }
        return count
    }

    /// Die 992 Byte, die als HID-Output-Report 0x03 ans Gerät gehen.
    public func reportBytes() -> [UInt8] {
        var report = [UInt8](repeating: 0, count: LCDFrame.reportSize)
        report[0] = LCDFrame.reportID
        report.replaceSubrange(LCDFrame.headerSize..<LCDFrame.reportSize, with: buffer)
        return report
    }

    /// Textvorschau fürs Terminal: zwei Pixelzeilen pro Textzeile.
    public func asciiPreview() -> String {
        var lines: [String] = []
        let border = "+" + String(repeating: "-", count: LCDFrame.width) + "+"
        lines.append(border)
        var y = 0
        while y < LCDFrame.height {
            var line = "|"
            for x in 0..<LCDFrame.width {
                let top = self[x, y]
                let bottom = y + 1 < LCDFrame.height ? self[x, y + 1] : false
                switch (top, bottom) {
                case (true, true): line += "█"
                case (true, false): line += "▀"
                case (false, true): line += "▄"
                case (false, false): line += " "
                }
            }
            lines.append(line + "|")
            y += 2
        }
        lines.append(border)
        return lines.joined(separator: "\n")
    }
}

// MARK: - Zeichnen

extension LCDFrame {

    public mutating func drawHLine(x: Int = 0, y: Int, length: Int = LCDFrame.width) {
        guard length > 0 else { return }
        for px in x..<(x + length) { self[px, y] = true }
    }

    public mutating func drawVLine(x: Int, y: Int = 0, length: Int = LCDFrame.height) {
        guard length > 0 else { return }
        for py in y..<(y + length) { self[x, py] = true }
    }

    public mutating func drawRect(x: Int, y: Int, width: Int, height: Int) {
        guard width > 0, height > 0 else { return }
        drawHLine(x: x, y: y, length: width)
        drawHLine(x: x, y: y + height - 1, length: width)
        drawVLine(x: x, y: y, length: height)
        drawVLine(x: x + width - 1, y: y, length: height)
    }

    public mutating func fillRect(x: Int, y: Int, width: Int, height: Int) {
        guard width > 0, height > 0 else { return }
        for py in y..<(y + height) {
            for px in x..<(x + width) { self[px, py] = true }
        }
    }

    /// Testbild: Rahmen, Ecken-Markierungen, Schachbrett und Beschriftung.
    /// Damit lässt sich auf echter Hardware prüfen, ob Orientierung,
    /// Ränder und Bitreihenfolge stimmen.
    public static func testPattern() -> LCDFrame {
        var frame = LCDFrame()
        frame.drawRect(x: 0, y: 0, width: width, height: height)
        // Gefüllte Ecke oben links, damit oben/unten eindeutig ist.
        frame.fillRect(x: 2, y: 2, width: 6, height: 6)
        // Schachbrett rechts (4x4-Felder).
        for cy in 0..<8 {
            for cx in 0..<8 where (cx + cy) % 2 == 0 {
                frame.fillRect(x: 122 + cx * 4, y: 4 + cy * 4, width: 4, height: 4)
            }
        }
        frame.drawText("G13forever", x: 12, y: 3)
        frame.drawText("160x43 Test", x: 12, y: 14)
        frame.drawText("oben links", x: 12, y: 25)
        // Diagonale über die untere Kante als Linearitätstest.
        for i in 0..<110 { frame[6 + i, 41 - (i / 12)] = true }
        return frame
    }
}
