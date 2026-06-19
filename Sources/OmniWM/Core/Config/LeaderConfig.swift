import Foundation

/// One entry in a leader menu: a single key that either descends into a folder (`menu`),
/// activates an app (`app` = bundle id), or runs an ActionCatalog action (`action` = action id).
struct LeaderMenuItem: Codable, Equatable {
    var key: String
    var title: String
    var menu: String?
    var app: String?
    var action: String?

    init(key: String, title: String, menu: String? = nil, app: String? = nil, action: String? = nil) {
        self.key = key
        self.title = title
        self.menu = menu
        self.app = app
        self.action = action
    }
}

/// A configurable, tree-structured leader: a flat map of named menus, where folder items
/// reference a submenu by name. Loaded from `~/.config/omniwm/leader.json`.
struct LeaderConfig: Codable, Equatable {
    var doubleTapOpensLeader: Bool
    var rootMenu: String
    var menus: [String: [LeaderMenuItem]]

    init(
        doubleTapOpensLeader: Bool = true,
        rootMenu: String = "main",
        menus: [String: [LeaderMenuItem]] = LeaderConfig.defaultMenus
    ) {
        self.doubleTapOpensLeader = doubleTapOpensLeader
        self.rootMenu = rootMenu
        self.menus = menus
    }

    static let defaults = LeaderConfig()

    private enum CodingKeys: String, CodingKey {
        case doubleTapOpensLeader, rootMenu, menus
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        doubleTapOpensLeader = try c.decodeIfPresent(Bool.self, forKey: .doubleTapOpensLeader) ?? true
        rootMenu = try c.decodeIfPresent(String.self, forKey: .rootMenu) ?? "main"
        menus = try c.decodeIfPresent([String: [LeaderMenuItem]].self, forKey: .menus) ?? LeaderConfig.defaultMenus
    }

    /// Mirrors the user's Hammerspoon `leader.lua` tree.
    static let defaultMenus: [String: [LeaderMenuItem]] = [
        "main": [
            LeaderMenuItem(key: "c", title: "Slack", app: "com.tinyspeck.slackmacgap"),
            LeaderMenuItem(key: "t", title: "WezTerm", app: "com.github.wez.wezterm"),
            LeaderMenuItem(key: "w", title: "Web", app: "com.kagi.kagimacOS"),
            LeaderMenuItem(key: "n", title: "Notes", app: "md.obsidian"),
            LeaderMenuItem(key: "f", title: "Full", action: "toggleFullscreen"),
            LeaderMenuItem(key: "g", title: "Float", action: "toggleFocusedWindowFloating"),
            LeaderMenuItem(key: "a", title: "AI", menu: "ai"),
            LeaderMenuItem(key: "m", title: "Move", menu: "move"),
            LeaderMenuItem(key: "s", title: "Switch", menu: "switch")
        ],
        "ai": [
            LeaderMenuItem(key: "c", title: "Claude", app: "com.anthropic.claudefordesktop"),
            LeaderMenuItem(key: "o", title: "ChatGPT", app: "com.openai.chat")
        ],
        "move": [
            LeaderMenuItem(key: "h", title: "Swap Left", action: "move.left"),
            LeaderMenuItem(key: "j", title: "Swap Down", action: "move.down"),
            LeaderMenuItem(key: "k", title: "Swap Up", action: "move.up"),
            LeaderMenuItem(key: "l", title: "Swap Right", action: "move.right"),
            LeaderMenuItem(key: "1", title: "→ Meeting", action: "moveWindowToZone.1"),
            LeaderMenuItem(key: "2", title: "→ Note", action: "moveWindowToZone.2"),
            LeaderMenuItem(key: "3", title: "→ Cat", action: "moveWindowToZone.3"),
            LeaderMenuItem(key: "4", title: "→ Duck", action: "moveWindowToZone.4"),
            LeaderMenuItem(key: "5", title: "→ Web", action: "moveWindowToZone.5"),
            LeaderMenuItem(key: "6", title: "→ AI", action: "moveWindowToZone.6")
        ],
        "switch": [
            LeaderMenuItem(key: "1", title: "Meeting", action: "focusZone.1"),
            LeaderMenuItem(key: "2", title: "Note", action: "focusZone.2"),
            LeaderMenuItem(key: "3", title: "Cat", action: "focusZone.3"),
            LeaderMenuItem(key: "4", title: "Duck", action: "focusZone.4"),
            LeaderMenuItem(key: "5", title: "Web", action: "focusZone.5"),
            LeaderMenuItem(key: "6", title: "AI", action: "focusZone.6"),
            LeaderMenuItem(key: "H", title: "← Monitor", action: "focusMonitorPrevious"),
            LeaderMenuItem(key: "L", title: "→ Monitor", action: "focusMonitorNext")
        ]
    ]
}

/// Pure resolver for a keypress within a leader menu — testable without AppKit.
enum LeaderResolution: Equatable {
    case none
    case descend(String)
    case run(LeaderMenuItem)
}

enum LeaderNavigator {
    static func items(in config: LeaderConfig, menu: String) -> [LeaderMenuItem] {
        config.menus[menu] ?? []
    }

    static func resolve(config: LeaderConfig, menu: String, key: String) -> LeaderResolution {
        guard let item = items(in: config, menu: menu).first(where: { $0.key == key }) else { return .none }
        if let submenu = item.menu, config.menus[submenu] != nil {
            return .descend(submenu)
        }
        return .run(item)
    }
}
