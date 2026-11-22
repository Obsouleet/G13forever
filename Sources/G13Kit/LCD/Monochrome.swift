// Monochrome.swift
// Wandelt ein Graustufenbild (160x43, 0 = schwarz, 255 = weiß) in einen
// 1-Bit-LCDFrame um. Plattformunabhängig, damit es ohne Hardware testbar ist.

/// Wie Graustufen auf 1 Bit reduziert werden.
public enum MonochromeMode: Equatable, Sendable {
    /// Fester Schwellwert: Helligkeit < threshold wird zu "an".
    case threshold(UInt8)
    /// Floyd-Steinberg-Fehlerdiffusion, gut für Fotos und Verläufe.
    case floydSteinberg
}

/// Ein Graustufenbild genau in Displaygröße.
public struct GrayscaleImage: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// Zeilenweise, oben links beginnend. 0 = schwarz, 255 = weiß.
    public var pixels: [UInt8]

    public init(width: Int = LCDFrame.width, height: Int = LCDFrame.height, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "pixels muss width * height Werte haben")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public init(width: Int = LCDFrame.width, height: Int = LCDFrame.height, fill value: UInt8) {
        self.init(width: width, height: height, pixels: [UInt8](repeating: value, count: width * height))
    }

    public subscript(x: Int, y: Int) -> UInt8 {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }
}

extension LCDFrame {

    /// Erzeugt einen Frame aus einem Graustufenbild.
    ///
    /// Standard: dunkle Bildpunkte werden zu gesetzten LCD-Pixeln, das Bild
    /// erscheint also wie gedruckt. Mit `invert: true` gilt das Umgekehrte
    /// (helle Punkte = gesetzt), passend für Grafiken, die wie die Beispiele
    /// aus jonas-werner/g13-configurator "weiß auf schwarz" gestaltet sind.
    public init(grayscale image: GrayscaleImage, mode: MonochromeMode = .floydSteinberg, invert: Bool = false) {
        self.init()
        let w = min(image.width, LCDFrame.width)
        let h = min(image.height, LCDFrame.height)

        switch mode {
        case .threshold(let limit):
            for y in 0..<h {
                for x in 0..<w {
                    let dark = image[x, y] < limit
                    self[x, y] = dark != invert
                }
            }

        case .floydSteinberg:
            var values = image.pixels.map { Float($0) }
            func add(_ x: Int, _ y: Int, _ amount: Float) {
                guard x >= 0, x < image.width, y >= 0, y < image.height else { return }
                values[y * image.width + x] += amount
            }
            for y in 0..<image.height {
                for x in 0..<image.width {
                    let old = values[y * image.width + x]
                    let new: Float = old < 128 ? 0 : 255
                    let error = old - new
                    add(x + 1, y, error * 7 / 16)
                    add(x - 1, y + 1, error * 3 / 16)
                    add(x, y + 1, error * 5 / 16)
                    add(x + 1, y + 1, error * 1 / 16)
                    if x < w, y < h {
                        self[x, y] = (new == 0) != invert
                    }
                }
            }
        }
    }
}
