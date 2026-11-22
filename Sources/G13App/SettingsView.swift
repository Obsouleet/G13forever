// SettingsView.swift
// Fenster zum Bearbeiten der Profile: Name, Farbe, Bild/GIF, Joystick, Tasten.

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

    private var slot: Int? { model.library.index(of: profile.id).map { $0 + 1 } }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section {
                    TextField("Name", text: $profile.name)
                    ColorPicker("Hintergrundfarbe", selection: colorBinding, supportsOpacity: false)
                    HStack {
                        if model.library.activeProfileID == profile.id {
                            Label("Aktives Profil", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Button("Jetzt aktivieren") { model.activate(profile.id) }
                        }
                        Spacer()
                        if let slot, slot <= 3 {
                            Text("Taste M\(slot) wechselt hierher").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Profil")
                }

                Section {
                    LCDAnimationView(frames: model.frames(for: profile))
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                    HStack {
                        Button("Bild oder GIF wählen …", action: chooseImage)
                        if profile.display.imageFile != nil {
                            Button("Bild entfernen") { model.removeImage(for: profile.id) }
                        }
                        Spacer()
                        Text(profile.display.imageFile == nil ? "Ohne Bild steht der Profilname auf dem Display." : "Am schärfsten: genau 160 × 43 Pixel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Picker("Skalierung", selection: $profile.display.scale) {
                        Text("Einpassen").tag(ScaleMode.fit)
                        Text("Füllen").tag(ScaleMode.fill)
                        Text("Strecken").tag(ScaleMode.stretch)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Dithering (gut für Fotos und Verläufe)", isOn: $profile.display.dither)
                    if !profile.display.dither {
                        HStack {
                            Text("Schwellwert")
                            Slider(value: thresholdBinding, in: 0...255)
                            Text("\(profile.display.threshold)").monospacedDigit().frame(width: 32, alignment: .trailing)
                        }
                    }
                    Toggle("Invertieren (dunkle Bildteile leuchten)", isOn: $profile.display.invert)
                } header: {
                    Text("Display")
                }

                Section {
                    Picker("Joystick", selection: $profile.joystick) {
                        Text("Aus").tag(JoystickMode.off)
                        Text("Pfeiltasten").tag(JoystickMode.arrows)
                        Text("W A S D").tag(JoystickMode.wasd)
                    }
                } header: {
                    Text("Joystick")
                }

                Section {
                    ForEach(G13Profile.bindableKeys, id: \.self) { key in
                        BindingRow(
                            key: key,
                            action: $profile.bindings[key],
                            profileNames: model.library.profiles.map(\.name),
                            highlighted: model.lastPressedKey == key
                        )
                        .id(key)
                    }
                } header: {
                    Text("Tastenbelegung")
                } footer: {
                    Text("Tipp: Eine Taste auf der G13 drücken, dann springt die Liste zu ihr. Tastenkürzel werden gehalten, solange die G13-Taste gedrückt ist.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .onChange(of: model.lastPressedKey) { _, key in
                guard let key, G13Profile.bindableKeys.contains(key) else { return }
                withAnimation { proxy.scrollTo(key, anchor: .center) }
            }
        }
        .navigationTitle(profile.name)
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { profile.backlight.color },
            set: { color in
                let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
                func byte(_ value: CGFloat) -> UInt8 { UInt8(max(0, min(255, (value * 255).rounded()))) }
                profile.backlight = RGBColor(red: byte(ns.redComponent), green: byte(ns.greenComponent), blue: byte(ns.blueComponent))
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

extension RGBColor {
    var color: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}
