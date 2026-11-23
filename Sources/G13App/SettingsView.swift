// SettingsView.swift
// Fenster zum Bearbeiten der Profile: Name, Farbe, Bild/GIF, Joystick
// und die Tastenbelegung am Bild der G13.

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import G13Kit

struct SettingsView: View {
    static let windowID = "profiles"

    @EnvironmentObject private var model: AppModel
    @State private var selection: UUID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(model.library.profiles) { profile in
                    HStack {
                        Circle()
                            .fill(profile.backlight.color)
                            .frame(width: 10, height: 10)
                        Text(profile.name)
                        Spacer()
                        if model.library.activeProfileID == profile.id {
                            Image(systemName: "checkmark").foregroundStyle(.secondary)
                        }
                    }
                    .tag(profile.id)
                }
                .onMove { model.moveProfiles(from: $0, to: $1) }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 4) {
                    Button { model.addProfile(); selection = model.library.profiles.last?.id } label: {
                        Image(systemName: "plus")
                    }
                    .help("Neues Profil")
                    Button {
                        if let id = selection { model.duplicateProfile(id) }
                    } label: { Image(systemName: "plus.square.on.square") }
                    .help("Profil duplizieren")
                    .disabled(selection == nil)
                    Button {
                        if let id = selection {
                            model.removeProfile(id)
                            selection = model.library.activeProfileID
                        }
                    } label: { Image(systemName: "minus") }
                    .help("Profil löschen")
                    .disabled(selection == nil || model.library.profiles.count <= 1)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
        } detail: {
            if let id = selection, let binding = profileBinding(id) {
                ProfileEditor(profile: binding)
                    .id(id)
            } else {
                Text("Profil auswählen").foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if selection == nil { selection = model.library.activeProfileID }
        }
    }

    private func profileBinding(_ id: UUID) -> Binding<G13Profile>? {
        guard let current = model.library.profiles.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { model.library.profiles.first(where: { $0.id == id }) ?? current },
            set: { newValue in
                if let index = model.library.index(of: id) { model.library.profiles[index] = newValue }
            }
        )
    }
}

// MARK: - Profil-Editor

struct ProfileEditor: View {
    @EnvironmentObject private var model: AppModel
    @Binding var profile: G13Profile
    /// Die im Bild gewählte Taste.
    @State private var selectedKey: G13Key = .g1

    private var slot: Int? { model.library.index(of: profile.id).map { $0 + 1 } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                keyRegion
                    .frame(minWidth: 580, maxWidth: .infinity)
                Divider()
                profileRegion
                    .frame(width: 380)
            }
        }
        .navigationTitle(profile.name)
        .onChange(of: model.lastKeyPress) { _, press in
            guard let press, G13Profile.bindableKeys.contains(press.key) else { return }
            selectedKey = press.key
        }
    }

    // MARK: Kopf

    private var header: some View {
        HStack(spacing: 16) {
            TextField("Profilname", text: $profile.name)
                .textFieldStyle(.plain)
                .font(.title.weight(.semibold))
            if let slot, slot <= 3 {
                Text("Taste M\(slot) wechselt hierher")
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            if model.library.activeProfileID == profile.id {
                Label("Aktives Profil", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .fixedSize()
            } else {
                Button("Jetzt aktivieren") { model.activate(profile.id) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: Links: G13 und gewählte Taste

    private var keyRegion: some View {
        VStack(spacing: 0) {
            G13PictureView(profile: profile, frames: model.frames(for: profile), selection: $selectedKey)
                .padding(16)
            Divider()
            KeyEditor(
                key: selectedKey,
                action: $profile.bindings[selectedKey],
                profileNames: model.library.profiles.map(\.name)
            )
            // Pro Taste ein eigener Editor, sonst liefe eine Aufnahme in der nächsten Taste weiter.
            .id(selectedKey)
        }
    }

    // MARK: Rechts: Profileinstellungen

    private var profileRegion: some View {
        Form {
            Section("Profil") {
                ColorPicker("Hintergrundfarbe", selection: colorBinding, supportsOpacity: false)
            }

            Section("Display") {
                LCDAnimationView(frames: model.frames(for: profile))
                    .frame(maxWidth: .infinity)
                HStack {
                    Button("Bild oder GIF wählen …", action: chooseImage)
                    if profile.display.imageFile != nil {
                        Button("Entfernen") { model.removeImage(for: profile.id) }
                    }
                }
                Text(profile.display.imageFile == nil ? "Ohne Bild steht der Profilname auf dem Display." : "Am schärfsten: genau 160 × 43 Pixel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Skalierung", selection: $profile.display.scale) {
                    Text("Einpassen").tag(ScaleMode.fit)
                    Text("Füllen").tag(ScaleMode.fill)
                    Text("Strecken").tag(ScaleMode.stretch)
                }
                Toggle("Dithering (gut für Fotos und Verläufe)", isOn: $profile.display.dither)
                if !profile.display.dither {
                    HStack {
                        Text("Schwellwert")
                        Slider(value: thresholdBinding, in: 0...255)
                        Text("\(profile.display.threshold)").monospacedDigit().frame(width: 32, alignment: .trailing)
                    }
                }
                Toggle("Invertieren (dunkle Bildteile leuchten)", isOn: $profile.display.invert)
            }

            Section("Joystick") {
                Picker("Joystick", selection: $profile.joystick) {
                    Text("Aus").tag(JoystickMode.off)
                    Text("Pfeiltasten").tag(JoystickMode.arrows)
                    Text("W A S D").tag(JoystickMode.wasd)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { profile.backlight.color },
            set: { color in
                let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
                func byte(_ value: CGFloat) -> UInt8 { UInt8(max(0, min(255, (value * 255).rounded()))) }
                profile.backlight = G13Kit.RGBColor(red: byte(ns.redComponent), green: byte(ns.greenComponent), blue: byte(ns.blueComponent))
            }
        )
    }

    private var thresholdBinding: Binding<Double> {
        Binding(
            get: { Double(profile.display.threshold) },
            set: { profile.display.threshold = UInt8(max(0, min(255, $0.rounded()))) }
        )
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.message = "Bild oder GIF für das G13-Display wählen"
        if panel.runModal() == .OK, let url = panel.url {
            model.setImage(url, for: profile.id)
        }
    }
}

extension G13Kit.RGBColor {
    var color: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}
