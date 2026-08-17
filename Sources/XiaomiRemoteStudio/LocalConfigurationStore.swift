import Foundation

enum LocalConfigurationStoreError: LocalizedError, Equatable {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "当前版本的 MiCoding 无法读取配置版本 \(version)"
        }
    }
}

struct LocalConfigurationStore {
    private let fileManager: FileManager
    let fileURL: URL

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base
                .appendingPathComponent("XiaomiRemoteStudio", isDirectory: true)
                .appendingPathComponent("config.json", isDirectory: false)
        }
    }

    func load() throws -> PersistedConfiguration? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let configuration = try JSONDecoder().decode(PersistedConfiguration.self, from: data)
        guard configuration.version == PersistedConfiguration.currentVersion else {
            throw LocalConfigurationStoreError.unsupportedVersion(configuration.version)
        }
        return configuration
    }

    /// Keeps the original bytes recoverable before the app falls back to
    /// defaults. The copy lives beside config.json so it is included when the
    /// user opens the local-data folder from Settings.
    func makeRecoveryCopy() throws -> URL? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let recoveryURL = directory.appendingPathComponent(
            "config-unreadable-\(UUID().uuidString).json",
            isDirectory: false
        )
        try fileManager.copyItem(at: fileURL, to: recoveryURL)
        return recoveryURL
    }

    func save(_ configuration: PersistedConfiguration) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        try data.write(to: fileURL, options: .atomic)
    }
}
