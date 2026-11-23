// ProfileLibrary.swift
// Alle Profile plus das aktive, und das Speichern als JSON unter
// ~/Library/Application Support/G13forever/.

import Foundation

public struct ProfileLibrary: Codable, Equatable, Sendable {
    public var version: Int
    public var profiles: [G13Profile]
    public var activeProfileID: UUID?

    public init(profiles: [G13Profile], activeProfileID: UUID? = nil) {
        self.version = 1
        self.profiles = profiles
        self.activeProfileID = activeProfileID ?? profiles.first?.id
    }

    /// Drei Profile, passend zu M1/M2/M3.
    public static func makeDefault() -> ProfileLibrary {
        ProfileLibrary(profiles: [
            G13Profile(name: String(localized: "Profile \(1)"), backlight: RGBColor(red: 0, green: 120, blue: 255)),
            G13Profile(name: String(localized: "Profile \(2)"), backlight: RGBColor(red: 255, green: 80, blue: 0)),
            G13Profile(name: String(localized: "Profile \(3)"), backlight: RGBColor(red: 0, green: 200, blue: 60)),
        ])
    }

    /// Index des aktiven Profils. Fällt auf das erste zurück, falls die ID fehlt.
    public var activeIndex: Int? {
        if let id = activeProfileID, let index = profiles.firstIndex(where: { $0.id == id }) { return index }
        return profiles.isEmpty ? nil : 0
    }

    public var activeProfile: G13Profile? {
        activeIndex.map { profiles[$0] }
    }

    public func index(of id: UUID) -> Int? {
        profiles.firstIndex { $0.id == id }
    }

    /// Wechselt zu Profil Nummer `slot` (ab 1). Gibt `false` zurück, wenn es das nicht gibt.
    @discardableResult
    public mutating func activate(slot: Int) -> Bool {
        guard slot >= 1, slot <= profiles.count else { return false }
        activeProfileID = profiles[slot - 1].id
        return true
    }

    public mutating func activateNext() {
        guard let index = activeIndex else { return }
        activeProfileID = profiles[(index + 1) % profiles.count].id
    }

    public mutating func activatePrevious() {
        guard let index = activeIndex else { return }
        activeProfileID = profiles[(index + profiles.count - 1) % profiles.count].id
    }

    private enum CodingKeys: String, CodingKey { case version, profiles, activeProfileID }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        profiles = try c.decodeIfPresent([G13Profile].self, forKey: .profiles) ?? []
        activeProfileID = try c.decodeIfPresent(UUID.self, forKey: .activeProfileID)
    }
}

/// Liest und schreibt die Profile und verwaltet die Bilder dazu.
public struct ProfileStore: Sendable {
    public let directory: URL

    public init(directory: URL = ProfileStore.defaultDirectory) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("G13forever", isDirectory: true)
    }

    public var libraryURL: URL { directory.appendingPathComponent("profiles.json") }
    public var imagesDirectory: URL { directory.appendingPathComponent("Images", isDirectory: true) }

    /// Lädt die Profile. Ohne Datei (erster Start) gibt es die Standardprofile.
    public func load() throws -> ProfileLibrary {
        guard FileManager.default.fileExists(atPath: libraryURL.path) else { return .makeDefault() }
        let data = try Data(contentsOf: libraryURL)
        var library = try JSONDecoder().decode(ProfileLibrary.self, from: data)
        if library.profiles.isEmpty { library = .makeDefault() }
        return library
    }

    public func save(_ library: ProfileLibrary) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(library).write(to: libraryURL, options: .atomic)
    }

    /// Kopiert ein Bild in den Bilder-Ordner und gibt den neuen Dateinamen zurück.
    public func importImage(from source: URL) throws -> String {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let ext = source.pathExtension.isEmpty ? "img" : source.pathExtension.lowercased()
        let name = "\(UUID().uuidString).\(ext)"
        try FileManager.default.copyItem(at: source, to: imagesDirectory.appendingPathComponent(name))
        return name
    }

    public func imageURL(for fileName: String) -> URL {
        imagesDirectory.appendingPathComponent(fileName)
    }

    /// Löscht Bilder, die kein Profil mehr verwendet.
    public func removeUnusedImages(keeping library: ProfileLibrary) {
        let used = Set(library.profiles.compactMap(\.display.imageFile))
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path) else { return }
        for file in files where !used.contains(file) {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(file))
        }
    }
}
