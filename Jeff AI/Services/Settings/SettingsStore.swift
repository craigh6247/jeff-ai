import Foundation
import SwiftUI
import Combine

final class SettingsStore: ObservableObject {
    @Published private(set) var entries: [String: String] = [:]

    private let fileURL: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.fileURL = home
            .appendingPathComponent(".jeff", isDirectory: true)
            .appendingPathComponent("settings.json")
        load()
    }

    var path: String { fileURL.path }

    subscript(key: String) -> String? { entries[key] }

    func set(_ key: String, to value: String) {
        entries[key] = value
        persist()
    }

    func remove(_ key: String) {
        entries.removeValue(forKey: key)
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        entries = decoded
    }

    private func persist() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
