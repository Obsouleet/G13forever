// G13InputReport.swift
// Auswertung der 8-Byte-Input-Reports der G13.
//
// Byte 0 = Report-ID, Byte 1/2 = Joystick X/Y (0–255, Mitte ~127),
// Byte 3–7 = 40 Tasten-Bits. Die Reihenfolge der Tasten-Bits stammt aus
// golgote/G13 (G13Device.swift, MIT, siehe THIRD_PARTY_NOTICES.md).

/// Alle Tasten-Bits der G13 in Report-Reihenfolge (Bit 0 von Byte 3 zuerst).
public enum G13Key: String, CaseIterable, Sendable {
    case g1 = "G1", g2 = "G2", g3 = "G3", g4 = "G4", g5 = "G5", g6 = "G6", g7 = "G7", g8 = "G8"
    case g9 = "G9", g10 = "G10", g11 = "G11", g12 = "G12", g13 = "G13", g14 = "G14", g15 = "G15", g16 = "G16"
    case g17 = "G17", g18 = "G18", g19 = "G19", g20 = "G20", g21 = "G21", g22 = "G22", undefined1 = "UNDEF1", lightState = "LIGHT_STATE"
    case bd = "BD", l1 = "L1", l2 = "L2", l3 = "L3", l4 = "L4", m1 = "M1", m2 = "M2", m3 = "M3"
    case mr = "MR", left = "LEFT", right = "RIGHT", stick = "STICK", undefined2 = "UNDEF2", light = "LIGHT", light2 = "LIGHT2", miscToggle = "MISC_TOGGLE"

    /// Bits, die keine echten Tasten sind bzw. Statusbits, die man meist ignoriert.
    public static let statusBits: Set<G13Key> = [.undefined1, .lightState, .undefined2, .light, .light2, .miscToggle]

    /// Bit-Position 0–39 in Byte 3–7.
    public var bitIndex: Int { G13Key.allCases.firstIndex(of: self)! }
}

public struct G13InputReport: Equatable, Sendable {
    public static let length = 8

    public var joystickX: UInt8
    public var joystickY: UInt8
    /// Alle gesetzten Bits, einschließlich Statusbits.
    public var rawKeys: Set<G13Key>

    /// Gedrückte echte Tasten (ohne Statusbits).
    public var pressedKeys: Set<G13Key> { rawKeys.subtracting(G13Key.statusBits) }

    public init(joystickX: UInt8 = 127, joystickY: UInt8 = 127, rawKeys: Set<G13Key> = []) {
        self.joystickX = joystickX
        self.joystickY = joystickY
        self.rawKeys = rawKeys
    }

    /// Liest einen Report. Liefert `nil`, wenn er zu kurz ist.
    public init?(bytes: [UInt8]) {
        guard bytes.count >= G13InputReport.length else { return nil }
        joystickX = bytes[1]
        joystickY = bytes[2]
        var keys = Set<G13Key>()
        for key in G13Key.allCases {
            let byte = bytes[3 + key.bitIndex / 8]
            if byte & (1 << UInt8(key.bitIndex % 8)) != 0 { keys.insert(key) }
        }
        rawKeys = keys
    }

    /// Welche echten Tasten sich gegenüber dem vorigen Report geändert haben.
    public func changes(since previous: G13InputReport) -> (pressed: Set<G13Key>, released: Set<G13Key>) {
        (pressedKeys.subtracting(previous.pressedKeys), previous.pressedKeys.subtracting(pressedKeys))
    }
}

/// Die LEDs über M1, M2, M3 und MR.
public struct G13ModeLEDs: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let m1 = G13ModeLEDs(rawValue: 0x01)
    public static let m2 = G13ModeLEDs(rawValue: 0x02)
    public static let m3 = G13ModeLEDs(rawValue: 0x04)
    public static let mr = G13ModeLEDs(rawValue: 0x08)
}
