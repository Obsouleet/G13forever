// KeyInjector.swift
// Schickt Tastendrücke und Text über CGEvent an macOS.
//
// Braucht die Freigabe unter Systemeinstellungen > Datenschutz & Sicherheit >
// Bedienungshilfen. Ohne sie verwirft macOS die Events stillschweigend.

#if canImport(Carbon) && canImport(ApplicationServices)
import Foundation
import Carbon
import ApplicationServices

public final class KeyInjector {

    private let source = CGEventSource(stateID: .hidSystemState)
    /// Wie oft jeder Modifier gerade gehalten wird (mehrere G-Tasten können denselben halten).
    private var modifierCounts: [UInt8: Int] = [:]
    /// Zeichen → (Tastencode, braucht Shift) im aktuellen Tastaturlayout.
    private var layoutMap: [Character: (code: UInt16, shift: Bool)] = [:]
    private var layoutObserver: NSObjectProtocol?

    public init() {
        reloadKeyboardLayout()
        layoutObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in self?.reloadKeyboardLayout() }
    }

    deinit {
        if let layoutObserver { DistributedNotificationCenter.default().removeObserver(layoutObserver) }
    }

    // MARK: Berechtigung

    /// Darf die App Tastendrücke senden (Bedienungshilfen)?
    public static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Fragt nach der Freigabe; macOS zeigt dann einen Dialog mit Link zu den Einstellungen.
    @discardableResult
    public static func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    // MARK: Ausführen

    public func keyDown(_ combo: KeyCombo) {
        for (modifier, _, _) in KeyModifiers.ordered where combo.modifiers.contains(modifier) {
            pressModifier(modifier)
        }
        if let modifier = KeyCodes.modifier(forKeyName: combo.key) {
            pressModifier(modifier, keyCode: KeyCodes.code(for: combo.key))
            return
        }
        guard let (code, shift) = resolve(combo.key) else {
            // Zeichen, das es im Layout nicht direkt gibt (z. B. "€"): als Text tippen.
            type(combo.key)
            return
        }
        post(code: code, down: true, extraFlags: shift ? .maskShift : [])
    }

    public func keyUp(_ combo: KeyCombo) {
        if let modifier = KeyCodes.modifier(forKeyName: combo.key) {
            releaseModifier(modifier, keyCode: KeyCodes.code(for: combo.key))
        } else if let (code, shift) = resolve(combo.key) {
            post(code: code, down: false, extraFlags: shift ? .maskShift : [])
        }
        for (modifier, _, _) in KeyModifiers.ordered.reversed() where combo.modifiers.contains(modifier) {
            releaseModifier(modifier)
        }
    }

    /// Tippt Text als Unicode, unabhängig vom Tastaturlayout.
    public func type(_ text: String) {
        let units = Array(text.utf16)
        var start = 0
        // CGEvent nimmt höchstens 20 UTF-16-Einheiten pro Event.
        while start < units.count {
            let end = min(start + 20, units.count)
            var chunk = Array(units[start..<end])
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
                event.flags = []
                event.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
                event.post(tap: .cghidEventTap)
            }
            start = end
        }
    }

    /// Lässt alle Modifier los, die noch gehalten werden.
    public func releaseAllModifiers() {
        for (modifier, _, _) in KeyModifiers.ordered where (modifierCounts[modifier.rawValue] ?? 0) > 0 {
            modifierCounts[modifier.rawValue] = 1
            releaseModifier(modifier)
        }
    }

    // MARK: Intern

    private var currentFlags: CGEventFlags {
        var flags: CGEventFlags = []
        for (modifier, _, _) in KeyModifiers.ordered where (modifierCounts[modifier.rawValue] ?? 0) > 0 {
            flags.insert(KeyInjector.flag(for: modifier))
        }
        return flags
    }

    private static func flag(for modifier: KeyModifiers) -> CGEventFlags {
        switch modifier {
        case .command: return .maskCommand
        case .shift: return .maskShift
        case .option: return .maskAlternate
        case .control: return .maskControl
        default: return .maskSecondaryFn
        }
    }

    private static func defaultKeyCode(for modifier: KeyModifiers) -> UInt16 {
        switch modifier {
        case .command: return 0x37
        case .shift: return 0x38
        case .option: return 0x3A
        case .control: return 0x3B
        default: return 0x3F
        }
    }

    private func pressModifier(_ modifier: KeyModifiers, keyCode: UInt16? = nil) {
        let count = modifierCounts[modifier.rawValue] ?? 0
        modifierCounts[modifier.rawValue] = count + 1
        if count == 0 {
            post(code: keyCode ?? KeyInjector.defaultKeyCode(for: modifier), down: true, flagsChanged: true)
        }
    }

    private func releaseModifier(_ modifier: KeyModifiers, keyCode: UInt16? = nil) {
        let count = modifierCounts[modifier.rawValue] ?? 0
        guard count > 0 else { return }
        modifierCounts[modifier.rawValue] = count - 1
        if count == 1 {
            post(code: keyCode ?? KeyInjector.defaultKeyCode(for: modifier), down: false, flagsChanged: true)
        }
    }

    private func post(code: UInt16, down: Bool, extraFlags: CGEventFlags = [], flagsChanged: Bool = false) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return }
        if flagsChanged { event.type = .flagsChanged }
        event.flags = currentFlags.union(extraFlags)
        event.post(tap: .cghidEventTap)
    }

    /// Tastencode für einen Tastennamen. Einzelne Zeichen zuerst über das aktuelle Layout.
    private func resolve(_ key: String) -> (UInt16, Bool)? {
        if key.count == 1, let character = key.first, let entry = layoutMap[character] {
            return (entry.code, entry.shift)
        }
        if let code = KeyCodes.code(for: key) { return (code, false) }
        return nil
    }

    /// Baut die Zuordnung Zeichen → Taste für das aktuelle Tastaturlayout.
    public func reloadKeyboardLayout() {
        var map: [Character: (code: UInt16, shift: Bool)] = [:]
        defer { layoutMap = map }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        let keyboardType = UInt32(LMGetKbdType())
        data.withUnsafeBytes { raw in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return }
            for shift in [false, true] {
                // Modifier-Zustand für UCKeyTranslate: (shiftKey >> 8) & 0xFF = 2
                let modifierState: UInt32 = shift ? 2 : 0
                for code in UInt16(0)..<UInt16(128) {
                    // Ziffernblock (0x41–0x5C) nicht für Zeichen verwenden, die Haupttastatur hat Vorrang.
                    if (0x41...0x5C).contains(code), KeyCodes.name(for: code)?.hasPrefix("kp") == true { continue }
                    var deadKeyState: UInt32 = 0
                    var length = 0
                    var chars = [UniChar](repeating: 0, count: 4)
                    let status = UCKeyTranslate(
                        layout, code, UInt16(kUCKeyActionDisplay), modifierState, keyboardType,
                        OptionBits(1 << kUCKeyTranslateNoDeadKeysBit), &deadKeyState, 4, &length, &chars
                    )
                    guard status == 0, length == 1 else { continue }
                    let string = String(utf16CodeUnits: chars, count: length)
                    guard let character = string.first, let scalar = string.unicodeScalars.first,
                          scalar.value >= 0x20, scalar.value != 0x7F else { continue }
                    let key = Character(String(character).lowercased())
                    if map[key] == nil { map[key] = (code, shift && String(character).lowercased() == String(character)) }
                }
            }
        }
    }
}
#endif
