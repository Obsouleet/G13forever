// KeyCombo.swift
// Ein Tastenkürzel wie "cmd+shift+4", "f5" oder "space".

import Foundation

/// Modifier-Tasten eines Tastenkürzels.
public struct KeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = KeyModifiers(rawValue: 1 << 0)
    public static let option = KeyModifiers(rawValue: 1 << 1)
    public static let shift = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)
    public static let function = KeyModifiers(rawValue: 1 << 4)

    /// Reihenfolge wie in macOS-Menüs: ⌃⌥⇧⌘.
    public static let ordered: [(modifier: KeyModifiers, name: String, symbol: String)] = [
        (.function, "fn", "fn "),
        (.control, "ctrl", "⌃"),
        (.option, "opt", "⌥"),
        (.shift, "shift", "⇧"),
        (.command, "cmd", "⌘"),
    ]

    /// Liest einen Modifier-Namen ("cmd", "strg", "⌘", …).
    public static func parse(_ token: String) -> KeyModifiers? {
        switch token.lowercased() {
        case "cmd", "command", "⌘", "befehl": return .command
        case "shift", "⇧", "umschalt": return .shift
        case "opt", "option", "alt", "⌥", "wahl": return .option
        case "ctrl", "control", "strg", "⌃": return .control
        case "fn": return .function
        default: return nil
        }
    }
}

public struct KeyCombo: Hashable, Sendable, CustomStringConvertible {
    public var modifiers: KeyModifiers
    /// Kanonischer Tastenname aus `KeyCodes` oder ein einzelnes Zeichen.
    public var key: String

    public init(key: String, modifiers: KeyModifiers = []) {
        self.key = KeyCodes.canonicalName(key)
        self.modifiers = modifiers
    }

    /// Liest Kürzel wie "cmd+shift+4", "Strg+Alt+Entf", "F5", "space" oder "ctrl++".
    /// Liefert `nil` bei unbekannten Tasten oder Modifiern.
    public init?(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var tokens: [String]
        var keyToken: String
        if trimmed == "+" {
            tokens = []
            keyToken = "+"
        } else if trimmed.hasSuffix("++") {
            tokens = trimmed.dropLast(2).split(separator: "+", omittingEmptySubsequences: false).map(String.init)
            keyToken = "+"
        } else {
            tokens = trimmed.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
            keyToken = tokens.removeLast()
        }

        var modifiers: KeyModifiers = []
        for token in tokens {
            let token = token.trimmingCharacters(in: .whitespaces)
            guard let modifier = KeyModifiers.parse(token) else { return nil }
            modifiers.insert(modifier)
        }
        keyToken = keyToken.trimmingCharacters(in: .whitespaces)
        guard !keyToken.isEmpty, KeyCodes.isValidKeyName(keyToken) else { return nil }
        self.init(key: keyToken, modifiers: modifiers)
    }

    /// Kanonische Textform, z. B. "cmd+shift+4". Wird so auch gespeichert.
    public var description: String {
        let names = KeyModifiers.ordered.filter { modifiers.contains($0.modifier) }.map(\.name)
        return (names + [key]).joined(separator: "+")
    }

    /// Anzeige mit Symbolen, z. B. "⇧⌘4" oder "F5".
    public var displayString: String {
        let symbols = KeyModifiers.ordered.filter { modifiers.contains($0.modifier) }.map(\.symbol).joined()
        return symbols + KeyCombo.displayName(for: key)
    }

    static let displayNames: [String: String] = [
        "return": "↩", "tab": "⇥", "space": String(localized: "Space"), "delete": "⌫", "forwarddelete": "⌦",
        "escape": "esc", "left": "←", "right": "→", "up": "↑", "down": "↓",
        "home": "↖", "end": "↘", "pageup": "⇞", "pagedown": "⇟", "capslock": "⇪",
        "command": "⌘", "rightcommand": String(localized: "right ⌘"), "shift": "⇧", "rightshift": String(localized: "right ⇧"),
        "option": "⌥", "rightoption": String(localized: "right ⌥"), "control": "⌃", "rightcontrol": String(localized: "right ⌃"),
        "kpenter": "⌤",
    ]

    static func displayName(for key: String) -> String {
        if let name = displayNames[key] { return name }
        if key.count == 1 { return key.uppercased() }
        if key.hasPrefix("f"), Int(key.dropFirst()) != nil { return key.uppercased() }
        if key.hasPrefix("kp") { return String(localized: "Keypad \(String(key.dropFirst(2)))") }
        return key
    }
}

extension KeyCombo: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let combo = KeyCombo(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unbekanntes Tastenkürzel: \(string)")
        }
        self = combo
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
