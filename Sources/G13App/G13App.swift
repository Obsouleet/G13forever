// G13App.swift
// Menüleisten-App für die Logitech G13: Profile wechseln, Tasten belegen,
// Bild oder GIF pro Profil aufs Display.

import AppKit
import SwiftUI
import G13Kit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Kein Dock-Symbol, auch wenn die App ohne Info.plist (swift run) läuft.
        NSApp.setActivationPolicy(.accessory)
        model.start()
        if KeyTest.isRequested { KeyTest.run() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
    }
}

@main
struct G13foreverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(delegate.model)
        } label: {
            Image(systemName: "keyboard")
        }
        .menuBarExtraStyle(.menu)

        Window("G13 Profiles", id: SettingsView.windowID) {
            SettingsView()
                .environmentObject(delegate.model)
                .frame(minWidth: 1180, minHeight: 680)
        }
        .defaultSize(width: 1240, height: 820)
    }
}

struct MenuContent: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.statusText)
        if !model.canSendKeys {
            Button("Allow Key Presses (Accessibility)…") { model.requestKeyPermission() }
        }
        Divider()
        ForEach(Array(model.library.profiles.enumerated()), id: \.element.id) { index, profile in
            Toggle(isOn: Binding(
                get: { model.library.activeProfileID == profile.id },
                set: { _ in model.activate(profile.id) }
            )) {
                Text(index < 3 ? "\(profile.name)  (M\(index + 1))" : profile.name)
            }
        }
        Divider()
        Button("Edit Profiles…") {
            openWindow(id: SettingsView.windowID)
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        Toggle("Launch at Login", isOn: Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        ))
        Divider()
        Button("Quit G13forever") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
