// DisplayPlayer.swift
// Spielt Standbilder und GIF-Animationen auf dem G13-Display ab.

import Foundation
import G13Kit

@MainActor
final class DisplayPlayer {

    /// Bekommt jeden Frame, der aufs Display soll.
    var output: ((LCDFrame) -> Void)?
    /// Wie lange die Einblendung beim Profilwechsel steht.
    var bannerDuration: TimeInterval = 1.0

    private var frames: [AnimationFrame] = []
    private var index = 0
    private var timer: Timer?

    /// Zeigt `frames` (in Schleife, falls animiert), optional nach einer kurzen Einblendung.
    func play(_ frames: [AnimationFrame], banner: LCDFrame? = nil) {
        stop()
        self.frames = frames
        index = 0
        if let banner {
            output?(banner)
            schedule(after: bannerDuration)
        } else {
            showCurrent()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func showCurrent() {
        guard !frames.isEmpty else { return }
        let item = frames[index]
        output?(item.frame)
        guard frames.count > 1 else { return }
        index = (index + 1) % frames.count
        schedule(after: max(item.duration, 0.02))
    }

    private func schedule(after interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.showCurrent() }
        }
        // .common, damit Animationen auch weiterlaufen, während ein Menü offen ist.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
