// LCDView.swift
// Zeigt einen LCDFrame bzw. eine Animation so, wie sie auf der G13 aussieht.

import SwiftUI
import G13Kit

struct LCDView: View {
    let frame: LCDFrame

    var body: some View {
        Image(decorative: LCDView.render(frame), scale: 1)
            .resizable()
            .interpolation(.none)
            .aspectRatio(CGFloat(LCDFrame.width) / CGFloat(LCDFrame.height), contentMode: .fit)
            .padding(6)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    /// Leuchtende Pixel hell, aus = dunkel, wie auf dem echten Display.
    static func render(_ frame: LCDFrame) -> CGImage {
        let width = LCDFrame.width, height = LCDFrame.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                pixels[y * width + x] = frame[x, y] ? 235 : 30
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }
}

/// Spielt animierte Frames in der Vorschau ab.
struct LCDAnimationView: View {
    let frames: [AnimationFrame]
    @State private var index = 0

    var body: some View {
        LCDView(frame: frames.isEmpty ? LCDFrame() : frames[min(index, frames.count - 1)].frame)
            .task(id: frames) {
                index = 0
                guard frames.count > 1 else { return }
                while !Task.isCancelled {
                    let seconds = max(frames[index].duration, 0.02)
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    if Task.isCancelled { break }
                    index = (index + 1) % frames.count
                }
            }
    }
}
