// BindingEditor.swift
// Die Belegung einer Taste und das Eingabefeld für Tastenkürzel.

import AppKit
import SwiftUI
import G13Kit

enum ActionKind: String, CaseIterable, Identifiable {
    case none, keys, text, profile, next, previous
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return String(localized: "Nothing")
        case .keys: return String(localized: "Keyboard shortcut")
        case .text: return String(localized: "Type text")
        case .profile: return String(localized: "Switch profile")
        case .next: return String(localized: "Next profile")
        case .previous: return String(localized: "Previous profile")
        }
    }

    init(_ action: KeyAction?) {
        switch action {
        case nil: self = .none
        case .keys?: self = .keys
        case .text?: self = .text
        case .profileSlot?: self = .profile
        case .nextProfile?: self = .next
        case .previousProfile?: self = .previous
        }
    }

    var defaultAction: KeyAction? {
        switch self {
        case .none: return nil
        case .keys: return .keys(KeyCombo(key: "space"))
        case .text: return .text("")
        case .profile: return .profileSlot(1)
        case .next: return .nextProfile
        case .previous: return .previousProfile
        }
    }
}

extension G13Key {
    var label: String {
        switch self {
        case .left: return String(localized: "Left thumb key")
        case .right: return String(localized: "Lower thumb key")
        case .stick: return String(localized: "Press stick")
        case .bd: return String(localized: "BD (below display)")
        case .l1, .l2, .l3, .l4: return String(localized: "\(rawValue) (below display)")
        default: return rawValue
        }
    }
}

/// Die Einstellungen der im Bild gewählten Taste.
struct KeyEditor: View {
    let key: G13Key
    @Binding var action: KeyAction?
    let profileNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(key.label).font(.headline)
            HStack(spacing: 12) {
                Picker("Action", selection: kindBinding) {
                    ForEach(ActionKind.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 160)
                editor
                Spacer(minLength: 0)
            }
            .frame(minHeight: 28)
            Text("Click a key in the picture or press it on the G13. Shortcuts stay pressed as long as you hold the G13 key.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    @ViewBuilder private var editor: some View {
        switch action {
        case .keys(let combo)?:
            ShortcutField(combo: Binding(get: { combo }, set: { action = .keys($0) }))
        case .text(let text)?:
            TextField("Text to type", text: Binding(get: { text }, set: { action = .text($0) }))
        case .profileSlot(let slot)?:
            Picker("", selection: Binding(get: { slot }, set: { action = .profileSlot($0) })) {
                ForEach(Array(profileNames.enumerated()), id: \.offset) { index, name in
                    Text(verbatim: "\(index + 1): \(name)").tag(index + 1)
                }
                if slot > profileNames.count {
                    Text("\(slot): (missing)").tag(slot)
                }
            }
            .labelsHidden()
            .frame(width: 200)
        default:
            EmptyView()
        }
    }

    private var kindBinding: Binding<ActionKind> {
        Binding(
            get: { ActionKind(action) },
            set: { kind in
                if kind != ActionKind(action) { action = kind.defaultAction }
            }
        )
    }
}

/// Tastenkürzel als Text ("cmd+shift+4") eingeben oder per Aufnahme festlegen.
struct ShortcutField: View {
    @Binding var combo: KeyCombo
    @State private var text = ""
    @State private var monitor: Any?

    private var isValid: Bool { KeyCombo(text) != nil }

    var body: some View {
        HStack(spacing: 8) {
            TextField("e.g. cmd+shift+4", text: $text)
                .frame(width: 150)
                .foregroundStyle(isValid ? Color.primary : Color.red)
                .onChange(of: text) { _, newValue in
                    if let parsed = KeyCombo(newValue), parsed != combo { combo = parsed }
                }
            Text(combo.displayString)
                .foregroundStyle(.secondary)
                .frame(minWidth: 70, alignment: .leading)
            Button(monitor == nil ? "Record" : "Press a key…") {
                monitor == nil ? startRecording() : stopRecording()
            }
        }
        .onAppear { text = combo.description }
        .onChange(of: combo) { _, newValue in
            if KeyCombo(text) != newValue { text = newValue.description }
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if let recorded = KeyCombo(event: event) {
                combo = recorded
                text = recorded.description
            }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

extension KeyCombo {
    /// Übernimmt einen echten Tastendruck auf der Mac-Tastatur.
    init?(event: NSEvent) {
        var modifiers: KeyModifiers = []
        let flags = event.modifierFlags
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        // Sondertasten (Pfeile, F-Tasten, Return …) über den Tastencode.
        if let name = KeyCodes.name(for: event.keyCode), name.count > 1 {
            self.init(key: name, modifiers: modifiers)
            return
        }
        // Zeichen-Tasten über das aktuelle Layout, ohne Shift/Option-Varianten.
        guard let characters = event.characters(byApplyingModifiers: []), characters.count == 1 else { return nil }
        self.init(key: characters, modifiers: modifiers)
    }
}
