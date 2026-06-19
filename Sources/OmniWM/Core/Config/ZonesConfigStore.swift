import Foundation

/// Loads (and seeds) zone definitions + app→zone assignments from `~/.config/omniwm/zones.json`.
/// The on/off switch stays in settings.toml ([general] zonesEnabled); this file is just the map.
/// Mirrors `LeaderConfigStore` — custom-feature config lives in its own JSON file, not the
/// canonical TOML.
enum ZonesConfigStore {
    static func fileURL(paths: OmniWMStoragePaths = .live) -> URL {
        paths.configDirectory.appendingPathComponent("zones.json")
    }

    /// Load the config, writing the defaults on first run. Falls back to defaults on any error
    /// (treat the file as untrusted input — never trap).
    static func loadOrSeed(paths: OmniWMStoragePaths = .live) -> ZonesConfig {
        let url = fileURL(paths: paths)
        if let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(ZonesConfig.self, from: data)
        {
            return config
        }
        let defaults = ZonesConfig.defaults
        try? write(defaults, paths: paths)
        return defaults
    }

    static func write(_ config: ZonesConfig, paths: OmniWMStoragePaths = .live) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.configDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.writePreservingSymlink(to: fileURL(paths: paths))
    }
}
