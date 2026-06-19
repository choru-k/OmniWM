import Foundation

/// One F15 hold-chord: a key combo (e.g. "T", "Shift+J") that runs an ActionCatalog action id.
/// `action` ids are the same strings used by leader.json and the `[[hotkeys]]` table.
struct F15ChordItem: Codable, Equatable {
    var key: String
    var action: String
}

/// F15 hold-chord layer config, loaded from `~/.config/omniwm/f15.json`.
/// (Enable/timing stay in settings.toml `[general]`; the double-tap *leader* menu is leader.json.)
struct F15Config: Codable, Equatable {
    var chords: [F15ChordItem]

    init(chords: [F15ChordItem] = F15Config.defaultChords) {
        self.chords = chords
    }

    static let defaults = F15Config()

    private enum CodingKeys: String, CodingKey { case chords }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chords = try c.decodeIfPresent([F15ChordItem].self, forKey: .chords) ?? F15Config.defaultChords
    }

    /// Single source of truth for the default chord map (mirrors the user's Hammerspoon map).
    static let defaultChords: [F15ChordItem] = [
        F15ChordItem(key: "H", action: "focus.left"),
        F15ChordItem(key: "L", action: "focus.right"),
        F15ChordItem(key: "J", action: "focus.down"),
        F15ChordItem(key: "K", action: "focus.up"),
        F15ChordItem(key: "Shift+H", action: "move.left"),
        F15ChordItem(key: "Shift+L", action: "move.right"),
        F15ChordItem(key: "Shift+J", action: "move.down"),
        F15ChordItem(key: "Shift+K", action: "move.up"),
        F15ChordItem(key: "F", action: "toggleColumnFullWidth"),
        F15ChordItem(key: "T", action: "toggleColumnTabbed"),
        F15ChordItem(key: "C", action: "expandColumnToAvailableWidth"),
        F15ChordItem(key: "0", action: "cycleColumnWidthForward"),
        F15ChordItem(key: "-", action: "consumeWindowIntoColumn"),
        F15ChordItem(key: "=", action: "expelWindowFromColumn")
    ]

    /// Resolve to the engine's binding→command map. Unparseable keys / unknown action ids are
    /// dropped silently (treat the file as untrusted input).
    func resolvedChords() -> [KeyBinding: HotkeyCommand] {
        var map: [KeyBinding: HotkeyCommand] = [:]
        for item in chords {
            guard let binding = KeySymbolMapper.fromHumanReadable(item.key), !binding.isUnassigned,
                  let command = HotkeyBindingRegistry.command(for: item.action) else { continue }
            map[binding] = command
        }
        return map
    }
}

/// Loads (and seeds) the F15 chord map from `~/.config/omniwm/f15.json`.
enum F15ConfigStore {
    static func fileURL(paths: OmniWMStoragePaths = .live) -> URL {
        paths.configDirectory.appendingPathComponent("f15.json")
    }

    /// Load the config, writing the default map on first run. Falls back to defaults on any error.
    static func loadOrSeed(paths: OmniWMStoragePaths = .live) -> F15Config {
        let url = fileURL(paths: paths)
        if let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(F15Config.self, from: data)
        {
            return config
        }
        let defaults = F15Config.defaults
        try? write(defaults, paths: paths)
        return defaults
    }

    static func write(_ config: F15Config, paths: OmniWMStoragePaths = .live) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.configDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.writePreservingSymlink(to: fileURL(paths: paths))
    }
}
