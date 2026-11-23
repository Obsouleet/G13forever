// G13PictureView.swift
// Die G13 als Bild. Jede Taste lässt sich anklicken, belegte Tasten sind grün gekennzeichnet.

import AppKit
import SwiftUI
import G13Kit

struct G13PictureView: View {
    let profile: G13Profile
    let frames: [AnimationFrame]
    @Binding var selection: G13Key

    private let art = G13Artwork.standard

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / art.viewBox.width, geometry.size.height / art.viewBox.height)
            let size = CGSize(width: art.viewBox.width * scale, height: art.viewBox.height * scale)
            let transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: -art.viewBox.minX, y: -art.viewBox.minY)

            ZStack(alignment: .topLeading) {
                Image(nsImage: Self.picture)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size.width, height: size.height)
                    .accessibilityHidden(true)
                // Etwas größer, damit vom gezeichneten Display kein Rand durchscheint.
                if let lcd = art.lcd?.insetBy(dx: -1, dy: -1).applying(transform) {
                    LCDAnimationView(frames: frames)
                        .colorMultiply(profile.backlight.color)
                        .frame(width: lcd.width, height: lcd.height)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                        .offset(x: lcd.minX, y: lcd.minY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                ForEach(G13Profile.bindableKeys, id: \.self) { key in
                    if let path = art.zones[key] {
                        KeyZone(
                            key: key,
                            action: profile.bindings[key],
                            path: Path(path).applying(transform),
                            dot: art.dots[key]?.applying(transform),
                            scale: scale,
                            isSelected: selection == key
                        ) { selection = key }
                    }
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Das SVG einmalig als Bitmap, zugeschnitten auf den sichtbaren Bereich.
    /// Mit seinen vielen Verläufen wäre es zu langsam, um es ständig neu zu zeichnen.
    private static let picture: NSImage = {
        let box = G13Artwork.standard.viewBox
        let zoom: CGFloat = 4
        guard
            let svg = NSImage(data: G13Artwork.imageData),
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(box.width * zoom), pixelsHigh: Int(box.height * zoom),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return NSImage() }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        // AppKit zählt y von unten.
        svg.draw(in: CGRect(
            x: -box.minX * zoom, y: -(svg.size.height - box.maxY) * zoom,
            width: svg.size.width * zoom, height: svg.size.height * zoom))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: box.size)
        image.addRepresentation(bitmap)
        return image
    }()
}

/// Eine anklickbare Taste im Bild.
private struct KeyZone: View {
    let key: G13Key
    let action: KeyAction?
    let path: Path
    /// Wo der Punkt sitzt, bei Tasten ohne Namen.
    let dot: CGPoint?
    let scale: CGFloat
    let isSelected: Bool
    let select: () -> Void

    @State private var isHovered = false

    var body: some View {
        // Nur so groß wie die Taste, damit Tooltip und Hover nicht das ganze Bild abdecken.
        let box = path.boundingRect
        let shape = path.offsetBy(dx: -box.minX, dy: -box.minY)
        Button(action: select) {
            shape
                .fill(fill)
                .overlay { shape.stroke(isSelected ? Color.accentColor : .clear, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round)) }
                .overlay { caption }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .frame(width: box.width, height: box.height)
        .onHover { isHovered = $0 }
        .help("\(key.label): \(action?.summary ?? "nicht belegt")")
        .accessibilityLabel(key.label)
        .accessibilityValue(action?.summary ?? "nicht belegt")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .offset(x: box.minX, y: box.minY)
    }

    private var fill: Color {
        if isSelected { return Color.accentColor.opacity(0.55) }
        if isHovered { return Color.white.opacity(0.22) }
        return Color.white.opacity(0.001)
    }

    /// Der Tastenname, grün wenn belegt. Tasten ohne Namen zeigen dann einen grünen Punkt.
    @ViewBuilder private var caption: some View {
        if let dot {
            if action != nil {
                let box = path.boundingRect
                Circle()
                    .fill(Self.assignedColor)
                    .overlay { Circle().stroke(.black.opacity(0.6), lineWidth: 0.5 * scale) }
                    .frame(width: 7 * scale, height: 7 * scale)
                    .position(x: dot.x - box.minX, y: dot.y - box.minY)
            }
        } else {
            Text(key.rawValue)
                .font(.system(size: 7 * scale, weight: .semibold))
                .foregroundStyle(action == nil ? .white.opacity(0.75) : Self.assignedColor)
        }
    }

    private static let assignedColor = Color(red: 0.3, green: 0.9, blue: 0.4)
}

extension KeyAction {
    /// Ausgeschrieben für Tooltip und Bedienungshilfen.
    var summary: String {
        switch self {
        case .keys(let combo): return combo.displayString
        case .text(let text): return "Text „\(text)“"
        case .profileSlot(let slot): return "Profil \(slot)"
        case .nextProfile: return "Nächstes Profil"
        case .previousProfile: return "Vorheriges Profil"
        }
    }
}
