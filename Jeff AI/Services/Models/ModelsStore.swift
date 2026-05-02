import Foundation
import SwiftUI
import Combine

@MainActor
final class ModelsStore: ObservableObject {
    struct InstalledModel: Identifiable, Hashable, Sendable {
        let repoID: String
        let directory: URL
        var id: String { repoID }
    }

    @Published private(set) var installed: [InstalledModel] = []
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var downloadingRepoID: String?
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var downloadStatus: String = ""
    @Published var lastError: String?

    let baseDirectory: URL
    let modelsDirectory: URL

    private let settings: SettingsStore
    private static let defaultKey = "defaultModel"

    init(settings: SettingsStore) {
        self.settings = settings
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.baseDirectory = home.appendingPathComponent(".jeff", isDirectory: true)
        self.modelsDirectory = baseDirectory.appendingPathComponent("models", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        refresh()
    }

    var defaultRepoID: String? { settings[ModelsStore.defaultKey] }

    func directory(for repoID: String) -> URL {
        let parts = repoID.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return modelsDirectory.appendingPathComponent(repoID) }
        return modelsDirectory
            .appendingPathComponent(parts[0], isDirectory: true)
            .appendingPathComponent(parts[1], isDirectory: true)
    }

    func setDefault(_ repoID: String?) {
        if let repoID, !repoID.isEmpty {
            settings.set(ModelsStore.defaultKey, to: repoID)
        } else {
            settings.remove(ModelsStore.defaultKey)
        }
        objectWillChange.send()
    }

    func refresh() {
        let fm = FileManager.default
        guard let owners = try? fm.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            installed = []
            return
        }
        var found: [InstalledModel] = []
        for owner in owners {
            let isDir = (try? owner.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            guard let repos = try? fm.contentsOfDirectory(
                at: owner,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for repo in repos {
                let isRepoDir = (try? repo.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isRepoDir else { continue }
                let id = "\(owner.lastPathComponent)/\(repo.lastPathComponent)"
                found.append(InstalledModel(repoID: id, directory: repo))
            }
        }
        installed = found.sorted { $0.repoID < $1.repoID }
    }

    func delete(_ model: InstalledModel) {
        try? FileManager.default.removeItem(at: model.directory)
        let owner = model.directory.deletingLastPathComponent()
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: owner.path),
           contents.isEmpty {
            try? FileManager.default.removeItem(at: owner)
        }
        if defaultRepoID == model.repoID {
            setDefault(nil)
        }
        refresh()
    }

    func download(repoID rawID: String) async {
        let repoID = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repoID.isEmpty, !isDownloading else { return }
        guard repoID.split(separator: "/").count == 2 else {
            lastError = "Repo ID must be in the form 'owner/name'."
            return
        }

        isDownloading = true
        downloadingRepoID = repoID
        downloadProgress = 0
        downloadStatus = "Listing files…"
        lastError = nil
        defer {
            isDownloading = false
            downloadingRepoID = nil
            downloadProgress = 0
            downloadStatus = ""
        }

        do {
            let entries = try await Self.listFiles(repoID: repoID)
            let wanted = entries.filter { Self.shouldDownload($0.path) }
            guard !wanted.isEmpty else {
                throw DownloadError.message("No model files found in this repo.")
            }
            let totalBytes = wanted.reduce(0) { $0 + max($1.size, 0) }
            let destDir = directory(for: repoID)
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

            var downloaded: Int64 = 0
            for (idx, entry) in wanted.enumerated() {
                downloadStatus = "Downloading \(entry.path) (\(idx + 1)/\(wanted.count))"
                let url = URL(string: "https://huggingface.co/\(repoID)/resolve/main/\(entry.path)")!
                let dest = destDir.appendingPathComponent(entry.path)
                try FileManager.default.createDirectory(
                    at: dest.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let (tmpURL, _) = try await URLSession.shared.download(from: url)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: tmpURL, to: dest)
                downloaded += max(entry.size, 0)
                if totalBytes > 0 {
                    downloadProgress = Double(downloaded) / Double(totalBytes)
                } else {
                    downloadProgress = Double(idx + 1) / Double(wanted.count)
                }
            }
            refresh()
            if defaultRepoID == nil {
                setDefault(repoID)
            }
        } catch let DownloadError.message(msg) {
            lastError = msg
        } catch {
            lastError = "Download failed: \(error.localizedDescription)"
        }
    }

    // MARK: - HF tree listing

    private struct TreeEntry: Decodable, Sendable {
        let type: String
        let path: String
        let size: Int64
    }

    private enum DownloadError: Error {
        case message(String)
    }

    private static func shouldDownload(_ path: String) -> Bool {
        let lower = path.lowercased()
        if lower.hasSuffix(".safetensors") { return true }
        if lower.hasSuffix(".json") { return true }
        if lower.hasSuffix(".txt") { return true }
        if lower.hasSuffix(".model") { return true }
        if (lower as NSString).lastPathComponent.hasPrefix("tokenizer") { return true }
        return false
    }

    private static func listFiles(repoID: String) async throws -> [TreeEntry] {
        var all: [TreeEntry] = []
        var cursor: String? = nil
        repeat {
            var components = URLComponents(string: "https://huggingface.co/api/models/\(repoID)/tree/main")!
            components.queryItems = [URLQueryItem(name: "recursive", value: "true")]
            if let cursor {
                components.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
            }
            let (data, response) = try await URLSession.shared.data(from: components.url!)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw DownloadError.message("HTTP \(http.statusCode) listing files for \(repoID).")
            }
            let page = try JSONDecoder().decode([TreeEntry].self, from: data)
            all.append(contentsOf: page.filter { $0.type == "file" })
            if let http = response as? HTTPURLResponse,
               let link = http.value(forHTTPHeaderField: "Link"),
               let next = Self.parseNextCursor(link)
            {
                cursor = next
            } else {
                cursor = nil
            }
        } while cursor != nil
        return all
    }

    private static func parseNextCursor(_ link: String) -> String? {
        for part in link.split(separator: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("rel=\"next\""),
                  let lt = trimmed.firstIndex(of: "<"),
                  let gt = trimmed.firstIndex(of: ">"),
                  lt < gt
            else { continue }
            let urlString = String(trimmed[trimmed.index(after: lt)..<gt])
            if let url = URL(string: urlString),
               let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let cursor = comps.queryItems?.first(where: { $0.name == "cursor" })?.value
            {
                return cursor
            }
        }
        return nil
    }
}
