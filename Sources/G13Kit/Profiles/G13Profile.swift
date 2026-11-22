// G13Profile.swift
// Profile mit Tastenbelegung, Hintergrundfarbe, Joystick-Modus und einem
// Bild oder GIF fürs Display. Gespeichert als JSON (siehe ProfileStore).

import Foundation

/// Was eine G13-Taste auslöst.
public enum KeyAction: Equatable, Hashable, Sendable {
    /// Tastenkürzel. Wird gehalten, solange die G13-Taste gedrückt ist.
    case keys(KeyCombo)
    /// Text eintippen (beim Drücken).
    case text(String)
    /// Zu Profil Nummer `slot` (ab 1) wechseln.
    case profileSlot(Int)
    case nextProfile
    case previousProfile
}

extension KeyAction: Codable {
    private enum CodingKeys: String, CodingKey { case type, shortcut, text, slot }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "keys": self = .keys(try container.decode(KeyCombo.self, forKey: .shortcut))
        case "text": self = .text(try container.decode(String.self, forKey: .text))
        case "profile": self = .profileSlot(try container.decode(Int.self, forKey: .slot))
        case "nextProfile": self = .nextProfile
        case "previousProfile": self = .previousProfile
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unbekannte Aktion: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .keys(let combo):
            try container.encode("keys", forKey: .type)
            try container.encode(combo, forKey: .shortcut)
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .profileSlot(let slot):
            try container.encode("profile", forKey: .type)
            try container.encode(slot, forKey: .slot)
        case .nextProfile:
            try container.encode("nextProfile", forKey: .type)
        case .previousProfile:
            try container.encode("previousProfile", forKey: .type)
        }
    }
}

public struct RGBColor: Codable, Equatable, Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// Was der Joystick macht.
public enum JoystickMode: String, Codable, CaseIterable, Sendable {
    case off
    /// Pfeiltasten
    case arrows
    /// W/A/S/D
    case wasd
}

/// Wie das Profilbild aufs Display kommt.
public struct DisplaySettings: Codable, Equatable, Hashable, Sendable {
    /// Dateiname im Bilder-Ordner des ProfileStore, `nil` = Profilname als Text.
    public var imageFile: String?
    public var scale: ScaleMode
    /// Floyd-Steinberg-Dithering, sonst fester Schwellwert.
    public var dither: Bool
    public var threshold: UInt8
    /// Dunkle statt helle Bildteile leuchten lassen.
    public var invert: Bool

    public init(imageFile: String? = nil, scale: ScaleMode = .fit, dither: Bool = true, threshold: UInt8 = 128, invert: Bool = false) {
        self.imageFile = imageFile
        self.scale = scale
        self.dither = dither
        self.threshold = threshold
        self.invert = invert
    }

    public var monochromeMode: MonochromeMode {
        dither ? .floydSteinberg : .threshold(threshold)
    }

    private enum CodingKeys: String, CodingKey { case imageFile, scale, dither, threshold, invert }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = DisplaySettings()
        imageFile = try c.decodeIfPresent(String.self, forKey: .imageFile)
        scale = (try? c.decodeIfPresent(ScaleMode.self, forKey: .scale)) ?? defaults.scale
        dither = try c.decodeIfPresent(Bool.self, forKey: .dither) ?? defaults.dither
        threshold = try c.decodeIfPresent(UInt8.self, forKey: .threshold) ?? defaults.threshold
        invert = try c.decodeIfPresent(Bool.self, forKey: .invert) ?? defaults.invert
    }
}

public struct G13Profile: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var backlight: RGBColor
    public var display: DisplaySettings
    public var joystick: JoystickMode
    public var bindings: [G13Key: KeyAction]

    public init(
        id: UUID = UUID(),
        name: String,
        backlight: RGBColor = RGBColor(red: 0, green: 120, blue: 255),
        display: DisplaySettings = DisplaySettings(),
        joystick: JoystickMode = .off,
        bindings: [G13Key: KeyAction] = G13Profile.defaultBindings
    ) {
        self.id = id
        self.name = name
        self.backlight = backlight
        self.display = display
        self.joystick = joystick
        self.bindings = bindings
    }

    /// M1/M2/M3 wechseln in jedem neuen Profil zu Profil 1/2/3.
    public static let defaultBindings: [G13Key: KeyAction] = [
        .m1: .profileSlot(1), .m2: .profileSlot(2), .m3: .profileSlot(3),
    ]

    /// Alle Tasten, die man belegen kann, in sinnvoller Reihenfolge.
    public static let bindableKeys: [G13Key] = [
        .g1, .g2, .g3, .g4, .g5, .g6, .g7,
        .g8, .g9, .g10, .g11, .g12, .g13, .g14,
        .g15, .g16, .g17, .g18, .g19,
        .g20, .g21, .g22,
        .left, .right, .stick,
        .bd, .l1, .l2, .l3, .l4,
        .m1, .m2, .m3, .mr,
    ]
}

extension G13Profile: Codable {
    private enum CodingKeys: String, CodingKey { case id, name, backlight, display, joystick, bindings }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Profil"
        backlight = try c.decodeIfPresent(RGBColor.self, forKey: .backlight) ?? RGBColor(red: 0, green: 120, blue: 255)
        display = try c.decodeIfPresent(DisplaySettings.self, forKey: .display) ?? DisplaySettings()
        joystick = (try? c.decodeIfPresent(JoystickMode.self, forKey: .joystick)) ?? .off
        // Unbekannte Tasten oder Aktionen werden übersprungen statt das ganze Profil zu verwerfen.
        let raw = try c.decodeIfPresent([String: LenientAction].self, forKey: .bindings) ?? [:]
        var bindings: [G13Key: KeyAction] = [:]
        for (name, entry) in raw {
            if let key = G13Key(rawValue: name), let action = entry.action { bindings[key] = action }
        }
        self.bindings = bindings
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(backlight, forKey: .backlight)
        try c.encode(display, forKey: .display)
        try c.encode(joystick, forKey: .joystick)
        var raw: [String: KeyAction] = [:]
        for (key, action) in bindings { raw[key.rawValue] = action }
        try c.encode(raw, forKey: .bindings)
    }

    private struct LenientAction: Decodable {
        let action: KeyAction?
        init(from decoder: Decoder) throws { action = try? KeyAction(from: decoder) }
    }
}
