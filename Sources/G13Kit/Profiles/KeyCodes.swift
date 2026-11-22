// KeyCodes.swift
// Virtuelle macOS-Tastencodes (kVK_* aus Carbon/HIToolbox/Events.h) unter
// lesbaren Namen. Die Codes sind Positionen auf einer US-Tastatur (ANSI).
// Für Zeichen-Tasten (Buchstaben, Ziffern, Satzzeichen) schlägt
// `KeyInjector` zur Laufzeit im aktuellen Tastaturlayout nach, damit z. B.
// "z" auf einer deutschen Tastatur auch ein Z ergibt. Die Tabelle hier ist
// dann nur der Rückfall.

public enum KeyCodes {

    /// Name → virtueller Tastencode.
    public static let byName: [String: UInt16] = {
        var table: [String: UInt16] = [
            // Zeichen-Tasten (ANSI-Position)
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
            "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
            "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18,
            "9": 0x19, "7": 0x1A, "-": 0x1B, "8": 0x1C, "0": 0x1D, "]": 0x1E, "o": 0x1F, "u": 0x20,
            "[": 0x21, "i": 0x22, "p": 0x23, "l": 0x25, "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29,
            "\\": 0x2A, ",": 0x2B, "/": 0x2C, "n": 0x2D, "m": 0x2E, ".": 0x2F, "`": 0x32,

            // Sondertasten
            "return": 0x24, "tab": 0x30, "space": 0x31, "delete": 0x33, "escape": 0x35,
            "forwarddelete": 0x75, "home": 0x73, "end": 0x77, "pageup": 0x74, "pagedown": 0x79,
            "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E, "help": 0x72,
            "capslock": 0x39,

            // Modifier als eigenständige Tasten (z. B. Shift für Spiele)
            "command": 0x37, "rightcommand": 0x36, "shift": 0x38, "rightshift": 0x3C,
            "option": 0x3A, "rightoption": 0x3D, "control": 0x3B, "rightcontrol": 0x3E, "fn": 0x3F,

            // Ziffernblock
            "kp0": 0x52, "kp1": 0x53, "kp2": 0x54, "kp3": 0x55, "kp4": 0x56, "kp5": 0x57,
            "kp6": 0x58, "kp7": 0x59, "kp8": 0x5B, "kp9": 0x5C, "kpdecimal": 0x41,
            "kpmultiply": 0x43, "kpplus": 0x45, "kpclear": 0x47, "kpdivide": 0x4B,
            "kpenter": 0x4C, "kpminus": 0x4E, "kpequals": 0x51,

            // Lautstärke
            "volumeup": 0x48, "volumedown": 0x49, "mute": 0x4A,
        ]
        let functionKeys: [UInt16] = [
            0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, // F1–F10
            0x67, 0x6F, 0x69, 0x6B, 0x71, 0x6A, 0x40, 0x4F, 0x50, 0x5A, // F11–F20
        ]
        for (index, code) in functionKeys.enumerated() { table["f\(index + 1)"] = code }
        return table
    }()

    /// Andere Schreibweisen, die beim Einlesen akzeptiert werden.
    public static let aliases: [String: String] = [
        "enter": "return", "eingabe": "return", "esc": "escape", "backspace": "delete",
        "rücktaste": "delete", "entf": "forwarddelete", "del": "forwarddelete",
        "leertaste": "space", "leer": "space", "pos1": "home", "ende": "end",
        "pgup": "pageup", "pgdown": "pagedown", "pgdn": "pagedown",
        "links": "left", "rechts": "right", "hoch": "up", "runter": "down",
        "cmd": "command", "ctrl": "control", "strg": "control", "alt": "option", "opt": "option",
        "lshift": "shift", "rshift": "rightshift",
    ]

    /// Code → Name (bei mehreren Namen der kürzeste, z. B. 0x24 → "return").
    public static let byCode: [UInt16: String] = {
        var result: [UInt16: String] = [:]
        for (name, code) in byName {
            if let existing = result[code], existing.count <= name.count { continue }
            result[code] = name
        }
        return result
    }()

    public static func code(for name: String) -> UInt16? {
        byName[canonicalName(name)]
    }

    public static func name(for code: UInt16) -> String? {
        byCode[code]
    }

    /// Kleinschreibung und Aliase aufgelöst. Unbekannte Namen bleiben (kleingeschrieben) erhalten.
    public static func canonicalName(_ name: String) -> String {
        let lower = name.lowercased()
        return aliases[lower] ?? lower
    }

    /// Ein Name ist gültig, wenn er in der Tabelle steht oder genau ein Zeichen ist
    /// (das wird dann über das Tastaturlayout aufgelöst, z. B. "ö" oder "#").
    public static func isValidKeyName(_ name: String) -> Bool {
        let canonical = canonicalName(name)
        return byName[canonical] != nil || canonical.count == 1
    }

    /// Tasten, die selbst Modifier sind, und welcher Modifier dazugehört.
    public static func modifier(forKeyName name: String) -> KeyModifiers? {
        switch canonicalName(name) {
        case "command", "rightcommand": return .command
        case "shift", "rightshift": return .shift
        case "option", "rightoption": return .option
        case "control", "rightcontrol": return .control
        case "fn": return .function
        default: return nil
        }
    }
}
