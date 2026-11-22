// ProfileRenderer.swift
// Was ein Profil auf dem Display zeigt: sein Bild bzw. GIF, sonst den Namen.

#if canImport(ImageIO) && canImport(CoreGraphics)
import Foundation

public enum ProfileRenderer {

    /// Frames fürs Display. Ohne Bild (oder wenn es nicht lesbar ist) steht der Profilname da.
    public static func frames(for profile: G13Profile, store: ProfileStore) -> [AnimationFrame] {
        if let file = profile.display.imageFile,
           let frames = try? ImageLoader.load(
               store.imageURL(for: file),
               scale: profile.display.scale,
               mode: profile.display.monochromeMode,
               invert: profile.display.invert
           ), !frames.isEmpty {
            return frames
        }
        return [AnimationFrame(frame: .text(profile.name), duration: 0)]
    }

    /// Kurze Einblendung beim Profilwechsel: Name mit Rahmen.
    public static func banner(for profile: G13Profile) -> LCDFrame {
        var frame = LCDFrame.text(profile.name)
        frame.drawRect(x: 0, y: 0, width: LCDFrame.width, height: LCDFrame.height)
        return frame
    }
}
#endif
