import Foundation

/// Loads (and seeds) the leader tree from `~/.config/omniwm/leader.json`.
enum LeaderConfigStore {
    static func fileURL(paths: OmniWMStoragePaths = .live) -> URL {
        paths.configDirectory.appendingPathComponent("leader.json")
    }

    /// Load the config, writing the default tree on first run. Falls back to defaults on any error
    /// (treat the file as untrusted input — never trap).
    static func loadOrSeed(paths: OmniWMStoragePaths = .live) -> LeaderConfig {
        let url = fileURL(paths: paths)
        if let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(LeaderConfig.self, from: data)
        {
            return config
        }
        let defaults = LeaderConfig.defaults
        try? write(defaults, paths: paths)
        return defaults
    }

    static func write(_ config: LeaderConfig, paths: OmniWMStoragePaths = .live) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.configDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL(paths: paths), options: .atomic)
    }
}
