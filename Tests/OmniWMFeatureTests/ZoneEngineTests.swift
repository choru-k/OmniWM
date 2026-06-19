import Foundation
@testable import OmniWM
import Testing

@Suite struct ZoneEngineTests {
    private func twoZoneEngine() -> ZoneEngine {
        var engine = ZoneEngine(
            config: ZonesConfig(
                enabled: true,
                definitions: [ZoneDefinition(id: 1, name: "one"), ZoneDefinition(id: 2, name: "two")],
                bundleAssignments: ["app.one": 1, "app.two": 2]
            )
        )
        _ = engine.reconciledOrder(
            windows: [
                ZoneWindow(id: "a", bundleID: "app.one"),
                ZoneWindow(id: "b", bundleID: "app.one"),
                ZoneWindow(id: "c", bundleID: "app.two")
            ],
            orderedWindowIDs: ["a", "b", "c"]
        )
        return engine
    }

    @Test func untaggedWindowsGoToCurrentZone() {
        // Current/active zone is 2; bundle-mapped apps keep their configured zones, and an app with
        // no bundle assignment lands in the current zone (not inferred from neighbour position).
        var engine = ZoneEngine(
            config: ZonesConfig(
                enabled: true,
                definitions: [
                    ZoneDefinition(id: 1, name: "one"),
                    ZoneDefinition(id: 2, name: "two"),
                    ZoneDefinition(id: 3, name: "three")
                ],
                bundleAssignments: ["app.one": 1, "app.three": 3]
            ),
            state: ZoneState(currentZone: 2)
        )
        let order = engine.reconciledOrder(
            windows: [
                ZoneWindow(id: "a", bundleID: "app.one"),
                ZoneWindow(id: "x", bundleID: "app.unknown"),
                ZoneWindow(id: "c", bundleID: "app.three")
            ],
            orderedWindowIDs: ["a", "x", "c"]
        )
        #expect(engine.zoneID(forWindowID: "a") == 1)
        #expect(engine.zoneID(forWindowID: "x") == 2) // unmapped → current zone
        #expect(engine.zoneID(forWindowID: "c") == 3)
        #expect(order == ["a", "x", "c"]) // sorted by zone: 1, 2, 3
    }

    @Test func untaggedWindowStaysStickyWhenCurrentZoneChanges() {
        var engine = ZoneEngine(
            config: ZonesConfig(
                enabled: true,
                definitions: [ZoneDefinition(id: 1, name: "one"), ZoneDefinition(id: 2, name: "two")],
                bundleAssignments: [:]
            ),
            state: ZoneState(currentZone: 1)
        )
        _ = engine.reconciledOrder(windows: [ZoneWindow(id: "x", bundleID: "app.unknown")], orderedWindowIDs: ["x"])
        #expect(engine.zoneID(forWindowID: "x") == 1)
        // Switch the active zone and reconcile again: the already-placed window stays put.
        engine.setCurrentZone(2)
        _ = engine.reconciledOrder(windows: [ZoneWindow(id: "x", bundleID: "app.unknown")], orderedWindowIDs: ["x"])
        #expect(engine.zoneID(forWindowID: "x") == 1)
    }

    @Test func preservesOriginalOrderInsideZone() {
        var engine = ZoneEngine(
            config: ZonesConfig(
                enabled: true,
                definitions: [ZoneDefinition(id: 1, name: "one")],
                bundleAssignments: ["app.one": 1]
            )
        )
        let order = engine.reconciledOrder(
            windows: [ZoneWindow(id: "a", bundleID: "app.one"), ZoneWindow(id: "b", bundleID: "app.one")],
            orderedWindowIDs: ["b", "a"]
        )
        #expect(order == ["b", "a"])
    }

    @Test func sortedOrderHandlesDuplicateOrderedIDsWithoutTrapping() {
        let engine = ZoneEngine(
            config: ZonesConfig(
                enabled: true,
                definitions: [ZoneDefinition(id: 1, name: "one"), ZoneDefinition(id: 2, name: "two")],
                bundleAssignments: [:]
            ),
            state: ZoneState(windowZoneTags: ["a": 2, "b": 1])
        )
        #expect(engine.sortedOrder(orderedWindowIDs: ["a", "a", "b"]) == ["b", "a"])
    }

    @Test func moveWindowToZoneUpdatesStateAndSorts() {
        var engine = ZoneEngine(
            config: ZonesConfig(
                enabled: true,
                definitions: [ZoneDefinition(id: 1, name: "one"), ZoneDefinition(id: 2, name: "two")],
                bundleAssignments: [:]
            ),
            state: ZoneState(windowZoneTags: ["a": 2, "b": 2])
        )
        let order = engine.move(windowID: "b", toZone: 1, orderedWindowIDs: ["a", "b"])
        #expect(order == ["b", "a"])
        #expect(engine.state.currentZone == 1)
        #expect(engine.zoneID(forWindowID: "b") == 1)
    }

    @Test func bundleAssignmentIsInitialPlacementOnlyAndManualMovesStick() {
        // "a" auto-tags to its configured zone 1 on first sight.
        var engine = twoZoneEngine()
        #expect(engine.zoneID(forWindowID: "a") == 1)

        // Move it to zone 2 manually, then run another reconcile cycle (same live windows).
        _ = engine.move(windowID: "a", toZone: 2, orderedWindowIDs: ["a", "b", "c"])
        _ = engine.reconciledOrder(
            windows: [
                ZoneWindow(id: "a", bundleID: "app.one"),
                ZoneWindow(id: "b", bundleID: "app.one"),
                ZoneWindow(id: "c", bundleID: "app.two")
            ],
            orderedWindowIDs: ["a", "b", "c"]
        )
        // Sticky: the manual move survives — config no longer re-forces "a" back to zone 1.
        #expect(engine.zoneID(forWindowID: "a") == 2)
    }

    @Test func zonesConfigDecodesCustomAssignmentsAndDefaultsTheRest() throws {
        let json = #"{ "bundleAssignments": { "com.acme.app": 4 } }"#
        let config = try JSONDecoder().decode(ZonesConfig.self, from: Data(json.utf8))
        #expect(config.bundleAssignments == ["com.acme.app": 4]) // user map wins
        #expect(config.definitions == ZonesConfig.defaultDefinitions) // missing key → defaults
        #expect(config.enabled == false) // enabled is never read from the file
    }

    @Test func zonesConfigEncodingOmitsEnabledAndLayoutMode() throws {
        let data = try JSONEncoder().encode(ZonesConfig(enabled: true, bundleAssignments: ["a": 1]))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["enabled"] == nil)
        #expect(object?["layoutMode"] == nil)
        #expect((object?["bundleAssignments"] as? [String: Int]) == ["a": 1])
    }

    @Test func prunesStaleTags() {
        var engine = ZoneEngine(
            config: ZonesConfig(
                enabled: true,
                definitions: [ZoneDefinition(id: 1, name: "one")],
                bundleAssignments: [:]
            ),
            state: ZoneState(windowZoneTags: ["gone": 1, "keep": 1])
        )
        _ = engine.reconciledOrder(
            windows: [ZoneWindow(id: "keep", bundleID: "app.keep")],
            orderedWindowIDs: ["keep"]
        )
        #expect(engine.state.windowZoneTags == ["keep": 1])
    }

    @Test func disabledZonesLeaveOrderUnchanged() {
        var engine = ZoneEngine(
            config: ZonesConfig(
                enabled: false,
                definitions: [ZoneDefinition(id: 1, name: "one")],
                bundleAssignments: ["app.one": 1]
            )
        )
        let order = engine.reconciledOrder(
            windows: [ZoneWindow(id: "a", bundleID: "app.one")],
            orderedWindowIDs: ["b", "a"]
        )
        #expect(order == ["b", "a"])
        #expect(engine.zoneID(forWindowID: "a") == nil)
    }

    @Test func focusAndCycleZoneTargetsUseCurrentZone() {
        var engine = ZoneEngine(
            config: ZonesConfig(
                enabled: true,
                definitions: [
                    ZoneDefinition(id: 1, name: "one"),
                    ZoneDefinition(id: 2, name: "two"),
                    ZoneDefinition(id: 3, name: "three")
                ],
                bundleAssignments: [:]
            ),
            state: ZoneState(currentZone: 1, windowZoneTags: ["a": 1, "c": 3])
        )
        #expect(engine.focusTarget(zoneID: 3, orderedWindowIDs: ["a", "c"]) == "c")
        engine.updateCurrentZone(focusedWindowID: "a")
        let next = engine.nextZoneTarget(direction: 1, orderedWindowIDs: ["a", "c"])
        #expect(next?.zoneID == 3)
        #expect(next?.windowID == "c")
    }

    @Test func restoredFocusReturnsRememberedWindowWhenStillLiveAndTagged() {
        var engine = twoZoneEngine()
        engine.rememberFocus(windowID: "b", inZone: 1)
        #expect(engine.restoredFocusTarget(forZone: 1, orderedWindowIDs: ["a", "b", "c"]) == "b")
    }

    @Test func restoredFocusFallsBackToFirstWindowWhenRememberedGone() {
        var engine = twoZoneEngine()
        engine.rememberFocus(windowID: "b", inZone: 1)
        #expect(engine.restoredFocusTarget(forZone: 1, orderedWindowIDs: ["a", "c"]) == "a")
    }

    @Test func restoredFocusFallsBackWhenRememberedWindowRetagged() {
        var engine = twoZoneEngine()
        engine.rememberFocus(windowID: "b", inZone: 1)
        _ = engine.move(windowID: "b", toZone: 2, orderedWindowIDs: ["a", "b", "c"])
        #expect(engine.restoredFocusTarget(forZone: 1, orderedWindowIDs: ["a", "b", "c"]) == "a")
    }

    @Test func setCurrentZoneRejectsInvalidID() {
        var engine = twoZoneEngine()
        engine.setCurrentZone(2)
        #expect(engine.state.currentZone == 2)
        engine.setCurrentZone(99)
        #expect(engine.state.currentZone == 2)
    }

    @Test func focusedWindowByZoneSurvivesEncodeDecode() throws {
        var engine = twoZoneEngine()
        engine.rememberFocus(windowID: "b", inZone: 1)
        let data = try JSONEncoder().encode(engine.state)
        let decoded = try JSONDecoder().decode(ZoneState.self, from: data)
        #expect(decoded.focusedWindowIDByZone[1] == "b")
    }

    @Test func reconcilePrunesDeadPerZoneFocus() {
        var engine = twoZoneEngine()
        engine.rememberFocus(windowID: "b", inZone: 1)
        _ = engine.reconciledOrder(
            windows: [ZoneWindow(id: "a", bundleID: "app.one")],
            orderedWindowIDs: ["a"]
        )
        #expect(engine.state.focusedWindowIDByZone[1] == nil)
    }
}
