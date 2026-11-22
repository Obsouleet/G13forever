// KeyTest.swift
// Diagnose: `G13forever --keytest` tippt nach 3 s in die vorderste App.
// Variante n schickt die Ziffer n per Tastencode und den Buchstaben a, b, c … als Text,
// so sieht man im Zieldokument, welcher Weg ankommt. Ergebnis zusätzlich im Log
// (subsystem io.github.obsouleet.g13forever, category keys).

import AppKit
import G13Kit

@MainActor
enum KeyTest {
    static var isRequested: Bool { CommandLine.arguments.contains("--keytest") }

    static let routes: [KeyInjector.Route] = [
        .init(sourceState: .hidSystemState, tap: .cghidEventTap),
        .init(sourceState: .combinedSessionState, tap: .cghidEventTap),
        .init(sourceState: .combinedSessionState, tap: .cgSessionEventTap),
        .init(sourceState: .hidSystemState, tap: .cgSessionEventTap),
        .init(sourceState: .privateState, tap: .cgSessionEventTap),
    ]

    static func run() {
        KeyInjector.logPermissions("Keytest")
        let injector = KeyInjector()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
            KeyInjector.log.notice("Keytest: Ziel \(front, privacy: .public)")
            for (index, route) in routes.enumerated() {
                injector.route = route
                let digit = String(index + 1)
                let letter = String(UnicodeScalar(UInt8(ascii: "a") + UInt8(index)))
                KeyInjector.log.notice("Keytest \(digit, privacy: .public): \(route.description, privacy: .public)")
                injector.keyDown(KeyCombo(key: digit))
                usleep(30_000)
                injector.keyUp(KeyCombo(key: digit))
                usleep(30_000)
                injector.type(letter)
                usleep(100_000)
            }
            KeyInjector.log.notice("Keytest fertig")
        }
    }
}
