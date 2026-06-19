import Foundation
@testable import OmniWM
import Testing

@Suite struct LeaderConfigTests {
    @Test func defaultTreeHasRootAndFolders() {
        let c = LeaderConfig.defaults
        #expect(c.rootMenu == "main")
        #expect(c.menus["main"] != nil)
        #expect(c.menus["ai"] != nil)
        #expect(c.menus["move"] != nil)
        #expect(c.menus["switch"] != nil)
        // main has folder + app + action items
        let main = c.menus["main"]!
        #expect(main.first { $0.key == "a" }?.menu == "ai")
        #expect(main.first { $0.key == "c" }?.app == "com.tinyspeck.slackmacgap")
        #expect(main.first { $0.key == "f" }?.action == "toggleFullscreen")
    }

    @Test func defaultActionIdsResolveToCommands() {
        // Every `action` id in the default tree must resolve via ActionCatalog.
        for (_, items) in LeaderConfig.defaultMenus {
            for item in items where item.action != nil {
                #expect(ActionCatalog.spec(for: item.action!)?.command != nil, "unresolved action \(item.action!)")
            }
        }
    }

    @Test func decodesPartialJSONWithDefaults() throws {
        let json = #"{ "menus": { "main": [ {"key":"x","title":"X","action":"toggleFullscreen"} ] } }"#
        let c = try JSONDecoder().decode(LeaderConfig.self, from: Data(json.utf8))
        #expect(c.rootMenu == "main")
        #expect(c.doubleTapOpensLeader == true)
        #expect(c.menus["main"]?.first?.key == "x")
    }

    @Test func navigatorDescendsRunsAndMisses() {
        let c = LeaderConfig.defaults
        #expect(LeaderNavigator.resolve(config: c, menu: "main", key: "a") == .descend("ai"))
        if case let .run(item) = LeaderNavigator.resolve(config: c, menu: "main", key: "f") {
            #expect(item.action == "toggleFullscreen")
        } else {
            Issue.record("expected .run for key f")
        }
        #expect(LeaderNavigator.resolve(config: c, menu: "main", key: "z") == .none)
    }

    @Test func navigatorTreatsFolderWithMissingSubmenuAsRun() {
        let c = LeaderConfig(menus: ["main": [LeaderMenuItem(key: "x", title: "X", menu: "ghost")]])
        // submenu doesn't exist -> not a descend; resolves to run (a no-op item)
        if case .run = LeaderNavigator.resolve(config: c, menu: "main", key: "x") {} else {
            Issue.record("expected .run when submenu missing")
        }
    }
}
