// AppModel.swift
// Hält Profile, Verbindung zur G13 und führt Tastenbelegungen aus.

import AppKit
import Combine
import G13Kit
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {

    @Published var library: ProfileLibrary {
        didSet { libraryDidChange(from: oldValue) }
    }
    @Published private(set) var isConnected = false
    @Published private(set) var statusText = "Suche G13 …"
    @Published private(set) var canSendKeys = KeyInjector.isTrusted
    /// Zuletzt auf der G13 gedrückte Taste, damit der Editor sie hervorheben kann.
    @Published private(set) var lastPressedKey: G13Key?
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    let store: ProfileStore
    private var device: G13Device?
    private var engine: BindingEngine
    private let injector = KeyInjector()
    private let player = DisplayPlayer()
    private var timers: [Timer] = []
    private var previewCache: [UUID: (settings: DisplaySettings, name: String, frames: [AnimationFrame])] = [:]
    private var loadError: String?

    init(store: ProfileStore = ProfileStore()) {
        self.store = store
        let loaded: ProfileLibrary
        do {
            loaded = try store.load()
        } catch {
            // Kaputte Datei nicht überschreiben, sondern beiseitelegen.
            let backup = store.libraryURL.deletingPathExtension().appendingPathExtension("defekt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: store.libraryURL, to: backup)
            loadError = "profiles.json war nicht lesbar und liegt jetzt als \(backup.lastPathComponent) daneben."
            loaded = .makeDefault()
        }
        library = loaded
        engine = BindingEngine(profile: loaded.activeProfile ?? G13Profile(name: "Profil"))
        player.output = { [weak self] frame in self?.send(frame) }
    }

    var activeProfile: G13Profile? { library.activeProfile }

    // MARK: Start und Ende

    func start() {
        if let loadError { statusText = loadError }
        try? store.save(library)
        connect()
        // Alle 2 s neu verbinden, falls die G13 fehlt, und die Bedienungshilfen-Freigabe prüfen.
        let timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.device == nil { self.connect() }
                let trusted = KeyInjector.isTrusted
                if trusted != self.canSendKeys { self.canSendKeys = trusted }
            }
        }
        timers.append(timer)
        if !canSendKeys { KeyInjector.requestTrust() }
    }

    func shutdown() {
        release()
        player.stop()
        if let device {
            try? device.send(.text("G13forever beendet"))
        }
    }

    // MARK: Gerät

    private func connect() {
        do {
            guard let found = try G13Device.findAll().first else {
                setDisconnected("G13 nicht gefunden")
                return
            }
            device = found
            isConnected = true
            statusText = "G13 verbunden"
            found.startInputMonitoring { [weak self] report in
                MainActor.assumeIsolated { self?.handle(report) }
            }
            found.onRemoval { [weak self] in
                MainActor.assumeIsolated { self?.setDisconnected("G13 abgezogen") }
            }
            applyActiveProfile(showBanner: true)
        } catch {
            setDisconnected("\(error)")
        }
    }

    private func setDisconnected(_ message: String) {
        release()
        player.stop()
        device?.stopMonitoring()
        device = nil
        isConnected = false
        statusText = message
    }

    private func send(_ frame: LCDFrame) {
        guard let device else { return }
        do {
            try device.send(frame)
        } catch {
            setDisconnected("Verbindung zur G13 verloren")
        }
    }

    // MARK: Tasten

    private func handle(_ report: G13InputReport) {
        if let key = report.changes(since: lastReport).pressed.min(by: { $0.bitIndex < $1.bitIndex }) {
            lastPressedKey = key
        }
        lastReport = report
        for output in engine.handle(report) {
            perform(output)
        }
    }
    private var lastReport = G13InputReport()

    private func perform(_ output: EngineOutput) {
        switch output {
        case .keyDown(let combo): if canSendKeys { injector.keyDown(combo) }
        case .keyUp(let combo): if canSendKeys { injector.keyUp(combo) }
        case .typeText(let text): if canSendKeys { injector.type(text) }
        case .switchToSlot(let slot): library.activate(slot: slot)
        case .nextProfile: library.activateNext()
        case .previousProfile: library.activatePrevious()
        }
    }

    private func release() {
        for output in engine.releaseAll() { perform(output) }
        injector.releaseAllModifiers()
        lastReport = G13InputReport()
    }

    // MARK: Profile

    func activate(_ id: UUID) {
        library.activeProfileID = id
    }

    func addProfile() {
        var profile = G13Profile(name: "Profil \(library.profiles.count + 1)")
        profile.backlight = G13Kit.RGBColor(red: 255, green: 255, blue: 255)
        library.profiles.append(profile)
    }

    func duplicateProfile(_ id: UUID) {
        guard let index = library.index(of: id) else { return }
        var copy = library.profiles[index]
        copy.id = UUID()
        copy.name += " Kopie"
        if let file = copy.display.imageFile,
           let newFile = try? store.importImage(from: store.imageURL(for: file)) {
            copy.display.imageFile = newFile
        }
        library.profiles.insert(copy, at: index + 1)
    }

    func removeProfile(_ id: UUID) {
        guard library.profiles.count > 1, let index = library.index(of: id) else { return }
        library.profiles.remove(at: index)
        if library.activeProfileID == id { library.activeProfileID = library.profiles.first?.id }
        store.removeUnusedImages(keeping: library)
    }

    func moveProfiles(from source: IndexSet, to destination: Int) {
        library.profiles.move(fromOffsets: source, toOffset: destination)
    }

    func setImage(_ url: URL, for id: UUID) {
        guard let index = library.index(of: id) else { return }
        do {
            let file = try store.importImage(from: url)
            library.profiles[index].display.imageFile = file
            store.removeUnusedImages(keeping: library)
        } catch {
            statusText = "Bild konnte nicht übernommen werden: \(error.localizedDescription)"
        }
    }

    func removeImage(for id: UUID) {
        guard let index = library.index(of: id) else { return }
        library.profiles[index].display.imageFile = nil
        store.removeUnusedImages(keeping: library)
    }

    /// Display-Frames eines Profils, zwischengespeichert für die Vorschau.
    func frames(for profile: G13Profile) -> [AnimationFrame] {
        if let cached = previewCache[profile.id], cached.settings == profile.display, cached.name == profile.name {
            return cached.frames
        }
        let frames = ProfileRenderer.frames(for: profile, store: store)
        previewCache[profile.id] = (profile.display, profile.name, frames)
        return frames
    }

    func requestKeyPermission() {
        KeyInjector.requestTrust()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            statusText = "Autostart geht nur aus der gebauten App (G13forever.app): \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Änderungen anwenden

    private func libraryDidChange(from old: ProfileLibrary) {
        do { try store.save(library) } catch { statusText = "Speichern fehlgeschlagen: \(error.localizedDescription)" }

        let oldActive = old.activeProfile
        guard let active = library.activeProfile else { return }
        engine.profile = active

        if oldActive?.id != active.id {
            applyActiveProfile(showBanner: true)
            return
        }
        guard let oldActive else { return }
        if oldActive.backlight != active.backlight { applyBacklight(active) }
        let nameShown = active.display.imageFile == nil && oldActive.name != active.name
        if oldActive.display != active.display || nameShown { applyDisplay(active, showBanner: false) }
        if library.activeIndex != old.activeIndex { applyLEDs() }
    }

    private func applyActiveProfile(showBanner: Bool) {
        guard let profile = library.activeProfile else { return }
        engine.profile = profile
        applyBacklight(profile)
        applyLEDs()
        applyDisplay(profile, showBanner: showBanner)
    }

    private func applyBacklight(_ profile: G13Profile) {
        try? device?.setBacklight(red: profile.backlight.red, green: profile.backlight.green, blue: profile.backlight.blue)
    }

    /// M1/M2/M3-LED passend zum Profil 1/2/3.
    private func applyLEDs() {
        let leds: [G13ModeLEDs] = [.m1, .m2, .m3]
        let index = library.activeIndex ?? 0
        try? device?.setModeLEDs(index < leds.count ? leds[index] : [])
    }

    private func applyDisplay(_ profile: G13Profile, showBanner: Bool) {
        guard device != nil else { return }
        let frames = self.frames(for: profile)
        let hasImage = profile.display.imageFile != nil
        player.play(frames, banner: showBanner && hasImage ? ProfileRenderer.banner(for: profile) : nil)
    }
}
