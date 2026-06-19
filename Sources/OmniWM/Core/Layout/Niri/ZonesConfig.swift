import Foundation

/// How the zones of a workspace's column strip are presented.
enum ZoneLayoutMode: String, Codable, Equatable {
    /// All zones share one continuous strip; a zone is an ordinal region. (default behavior.)
    case consecutive
    /// Each zone is its own space; only the current zone's columns are visible. (niri-style.)
    case separate
}

struct ZoneDefinition: Codable, Equatable {
    var id: Int
    var name: String
    var icon: String?

    init(id: Int, name: String, icon: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
    }
}

/// Ported from the nehir fork (originally madang's ZonesConfig). Bundle assignments map an app's
/// bundle id to a zone id so its windows auto-tag.
struct ZonesConfig: Codable, Equatable {
    var enabled: Bool
    var layoutMode: ZoneLayoutMode
    var definitions: [ZoneDefinition]
    var bundleAssignments: [String: Int]

    init(
        enabled: Bool = false,
        layoutMode: ZoneLayoutMode = .consecutive,
        definitions: [ZoneDefinition] = ZonesConfig.defaultDefinitions,
        bundleAssignments: [String: Int] = ZonesConfig.defaultBundleAssignments
    ) {
        self.enabled = enabled
        self.layoutMode = layoutMode
        self.definitions = definitions
        self.bundleAssignments = bundleAssignments
    }

    // Persisted form (~/.config/omniwm/zones.json) exposes only the user-editable map + zone names.
    // `enabled` stays in settings.toml ([general] zonesEnabled); layoutMode isn't user-facing yet
    // (only the anchor/consecutive model is implemented). Missing keys fall back to defaults.
    enum CodingKeys: String, CodingKey {
        case definitions, bundleAssignments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = false
        layoutMode = .consecutive
        definitions = try container.decodeIfPresent([ZoneDefinition].self, forKey: .definitions)
            ?? ZonesConfig.defaultDefinitions
        bundleAssignments = try container.decodeIfPresent([String: Int].self, forKey: .bundleAssignments)
            ?? ZonesConfig.defaultBundleAssignments
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(definitions, forKey: .definitions)
        try container.encode(bundleAssignments, forKey: .bundleAssignments)
    }

    static let defaults = ZonesConfig()

    static let defaultDefinitions: [ZoneDefinition] = [
        ZoneDefinition(id: 1, name: "meeting", icon: "camera"),
        ZoneDefinition(id: 2, name: "note", icon: "note"),
        ZoneDefinition(id: 3, name: "cat", icon: "chat"),
        ZoneDefinition(id: 4, name: "duck", icon: "terminal"),
        ZoneDefinition(id: 5, name: "web", icon: "web"),
        ZoneDefinition(id: 6, name: "ai", icon: "ai")
    ]

    static let defaultBundleAssignments: [String: Int] = [
        "us.zoom.xos": 1,
        "md.obsidian": 2,
        "com.tinyspeck.slackmacgap": 3,
        "com.github.wez.wezterm": 4,
        "com.kagi.kagimacOS": 5,
        "com.anthropic.claudefordesktop": 6,
        "com.openai.chat": 6
    ]
}
