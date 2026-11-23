// ImageLoader.swift
// Lädt PNG/JPEG/GIF (auch animiert) über ImageIO und bereitet die Bilder für
// das 160x43-Display auf. Die Idee "statisches Bild = 1 Frame, animiertes
// GIF = ein Frame pro GIF-Frame mit dessen Anzeigedauer" folgt
// jonas-werner/g13-configurator (MIT, siehe THIRD_PARTY_NOTICES.md).

#if canImport(ImageIO) && canImport(CoreGraphics)
import Foundation
import CoreGraphics
import ImageIO

/// Ein Einzelbild einer Animation mit Anzeigedauer.
public struct AnimationFrame: Equatable, Sendable {
    public var frame: LCDFrame
    /// Anzeigedauer in Sekunden (0 bei Standbildern).
    public var duration: TimeInterval

    public init(frame: LCDFrame, duration: TimeInterval) {
        self.frame = frame
        self.duration = duration
    }
}

public enum ImageLoaderError: Error, CustomStringConvertible {
    case cannotOpen(URL)
    case noFrames(URL)
    case cannotRender

    public var description: String {
        switch self {
        case .cannotOpen(let url): return String(localized: "The image could not be opened: \(url.path)")
        case .noFrames(let url): return String(localized: "The file contains no images: \(url.path)")
        case .cannotRender: return String(localized: "The image could not be converted to grayscale")
        }
    }
}

public enum ImageLoader {

    /// Lädt eine Bilddatei als Folge von Display-Frames.
    public static func load(
        _ url: URL,
        scale: ScaleMode = .fit,
        mode: MonochromeMode = .floydSteinberg,
        invert: Bool = false
    ) throws -> [AnimationFrame] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageLoaderError.cannotOpen(url)
        }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { throw ImageLoaderError.noFrames(url) }

        var frames: [AnimationFrame] = []
        for index in 0..<count {
            // ImageIO liefert bei GIFs bereits fertig zusammengesetzte Frames.
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let gray = try grayscale(from: image, scale: scale)
            let frame = LCDFrame(grayscale: gray, mode: mode, invert: invert)
            frames.append(AnimationFrame(frame: frame, duration: count > 1 ? delay(of: source, at: index) : 0))
        }
        guard !frames.isEmpty else { throw ImageLoaderError.noFrames(url) }
        return frames
    }

    /// Rendert ein CGImage auf schwarzen Hintergrund (= Pixel aus) in ein 160x43-Graustufenbild.
    public static func grayscale(from image: CGImage, scale: ScaleMode) throws -> GrayscaleImage {
        let width = LCDFrame.width
        let height = LCDFrame.height
        var pixels = [UInt8](repeating: 0, count: width * height)

        let ok: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }

            context.interpolationQuality = .high
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: targetRect(for: image, scale: scale))
            return true
        }
        guard ok else { throw ImageLoaderError.cannotRender }
        return GrayscaleImage(width: width, height: height, pixels: pixels)
    }

    static func targetRect(for image: CGImage, scale: ScaleMode) -> CGRect {
        let dw = CGFloat(LCDFrame.width), dh = CGFloat(LCDFrame.height)
        let iw = CGFloat(image.width), ih = CGFloat(image.height)
        guard iw > 0, ih > 0 else { return CGRect(x: 0, y: 0, width: dw, height: dh) }
        let factor: CGFloat
        switch scale {
        case .stretch: return CGRect(x: 0, y: 0, width: dw, height: dh)
        case .fit: factor = min(dw / iw, dh / ih)
        case .fill: factor = max(dw / iw, dh / ih)
        }
        let w = iw * factor, h = ih * factor
        return CGRect(x: (dw - w) / 2, y: (dh - h) / 2, width: w, height: h)
    }

    /// Anzeigedauer eines GIF- oder APNG-Frames, wie Browser mindestens 20 ms.
    static func delay(of source: CGImageSource, at index: Int) -> TimeInterval {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        var value: Double?
        if let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
            value = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif[kCGImagePropertyGIFDelayTime] as? Double)
        } else if let png = properties?[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
            value = (png[kCGImagePropertyAPNGUnclampedDelayTime] as? Double)
                ?? (png[kCGImagePropertyAPNGDelayTime] as? Double)
        }
        guard let seconds = value, seconds >= 0.02 else { return 0.1 }
        return seconds
    }
}
#endif
