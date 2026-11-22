// BindingEngine.swift
// Übersetzt Input-Reports der G13 anhand des aktiven Profils in Aktionen.
// Reine Logik ohne Systemzugriff, damit sie ohne Hardware testbar ist.
// Das Ausführen (Tastendrücke an macOS schicken) macht `KeyInjector`.

public enum EngineOutput: Equatable, Sendable {
    case keyDown(KeyCombo)
    case keyUp(KeyCombo)
    case typeText(String)
    case switchToSlot(Int)
    case nextProfile
    case previousProfile
}

public enum JoystickDirection: CaseIterable, Sendable {
    case up, down, left, right
}

public struct BindingEngine: Sendable {

    /// Das aktive Profil. Darf jederzeit gewechselt werden: Tasten, die gerade
    /// gehalten werden, lassen beim Loslassen trotzdem das alte Kürzel los.
    public var profile: G13Profile
    /// Ab welcher Auslenkung (0–127 von der Mitte) eine Joystick-Richtung zählt.
    public var joystickThreshold: Int

    private var previous = G13InputReport()
    private var heldKeys: [G13Key: KeyCombo] = [:]
    private var heldDirections: [JoystickDirection: KeyCombo] = [:]

    public init(profile: G13Profile, joystickThreshold: Int = 60) {
        self.profile = profile
        self.joystickThreshold = joystickThreshold
    }

    /// Verarbeitet einen neuen Report und liefert die auszuführenden Aktionen.
    public mutating func handle(_ report: G13InputReport) -> [EngineOutput] {
        var output: [EngineOutput] = []
        let (pressed, released) = report.changes(since: previous)
        previous = report

        for key in released.sorted(by: { $0.bitIndex < $1.bitIndex }) {
            if let combo = heldKeys.removeValue(forKey: key) { output.append(.keyUp(combo)) }
        }
        for key in pressed.sorted(by: { $0.bitIndex < $1.bitIndex }) {
            guard let action = profile.bindings[key] else { continue }
            switch action {
            case .keys(let combo):
                heldKeys[key] = combo
                output.append(.keyDown(combo))
            case .text(let text):
                if !text.isEmpty { output.append(.typeText(text)) }
            case .profileSlot(let slot):
                output.append(.switchToSlot(slot))
            case .nextProfile:
                output.append(.nextProfile)
            case .previousProfile:
                output.append(.previousProfile)
            }
        }

        output += updateJoystick(report)
        return output
    }

    /// Lässt alles los, was gerade gehalten wird (z. B. wenn die G13 abgezogen wird).
    public mutating func releaseAll() -> [EngineOutput] {
        let combos: [KeyCombo] = heldKeys.sorted { $0.key.bitIndex < $1.key.bitIndex }.map { $0.value }
            + JoystickDirection.allCases.compactMap { heldDirections[$0] }
        heldKeys.removeAll()
        heldDirections.removeAll()
        previous = G13InputReport()
        return combos.map { .keyUp($0) }
    }

    /// Welche Richtungen der Joystick gerade anzeigt. X: 0 = links, Y: 0 = oben.
    public func directions(of report: G13InputReport) -> Set<JoystickDirection> {
        let dx = Int(report.joystickX) - 128
        let dy = Int(report.joystickY) - 128
        var result = Set<JoystickDirection>()
        if dx <= -joystickThreshold { result.insert(.left) }
        if dx >= joystickThreshold { result.insert(.right) }
        if dy <= -joystickThreshold { result.insert(.up) }
        if dy >= joystickThreshold { result.insert(.down) }
        return result
    }

    public static func combo(for direction: JoystickDirection, mode: JoystickMode) -> KeyCombo? {
        switch (mode, direction) {
        case (.off, _): return nil
        case (.arrows, .up): return KeyCombo(key: "up")
        case (.arrows, .down): return KeyCombo(key: "down")
        case (.arrows, .left): return KeyCombo(key: "left")
        case (.arrows, .right): return KeyCombo(key: "right")
        case (.wasd, .up): return KeyCombo(key: "w")
        case (.wasd, .down): return KeyCombo(key: "s")
        case (.wasd, .left): return KeyCombo(key: "a")
        case (.wasd, .right): return KeyCombo(key: "d")
        }
    }

    private mutating func updateJoystick(_ report: G13InputReport) -> [EngineOutput] {
        let active = profile.joystick == .off ? [] : directions(of: report)
        var output: [EngineOutput] = []
        for direction in JoystickDirection.allCases {
            let held = heldDirections[direction]
            if held != nil, !active.contains(direction) {
                heldDirections[direction] = nil
                output.append(.keyUp(held!))
            } else if held == nil, active.contains(direction),
                      let combo = BindingEngine.combo(for: direction, mode: profile.joystick) {
                heldDirections[direction] = combo
                output.append(.keyDown(combo))
            }
        }
        return output
    }
}
