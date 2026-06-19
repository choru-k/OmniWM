import Foundation

/// A live window as seen by the zone engine: an opaque id (the layout layer uses "pid:windowId")
/// plus its app bundle id (for bundle-based zone assignment).
struct ZoneWindow: Equatable {
    var id: String
    var bundleID: String

    init(id: String, bundleID: String) {
        self.id = id
        self.bundleID = bundleID
    }
}

/// Persisted zone state. Window ids are opaque strings; zone ids are 1-based ints.
struct ZoneState: Codable, Equatable {
    static let currentVersion = 1

    var stateVersion: Int
    var currentZone: Int
    var windowZoneTags: [String: Int]
    /// Last-focused window per zone, so switching back to a zone (separate mode) restores focus.
    var focusedWindowIDByZone: [Int: String]

    init(
        stateVersion: Int = Self.currentVersion,
        currentZone: Int = 1,
        windowZoneTags: [String: Int] = [:],
        focusedWindowIDByZone: [Int: String] = [:]
    ) {
        self.stateVersion = stateVersion
        self.currentZone = currentZone
        self.windowZoneTags = windowZoneTags
        self.focusedWindowIDByZone = focusedWindowIDByZone
    }

    static let defaults = ZoneState()

    private enum CodingKeys: String, CodingKey {
        case stateVersion, currentZone, windowZoneTags, focusedWindowIDByZone
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stateVersion = try container.decodeIfPresent(Int.self, forKey: .stateVersion) ?? Self.currentVersion
        currentZone = try container.decodeIfPresent(Int.self, forKey: .currentZone) ?? 1
        windowZoneTags = try container.decodeIfPresent([String: Int].self, forKey: .windowZoneTags) ?? [:]
        // JSON object keys are strings; zone ids were stored as their string form.
        let decoded = try container.decodeIfPresent([String: String].self, forKey: .focusedWindowIDByZone) ?? [:]
        focusedWindowIDByZone = decoded.reduce(into: [Int: String]()) { result, pair in
            if let zoneID = Int(pair.key) { result[zoneID] = pair.value }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stateVersion, forKey: .stateVersion)
        try container.encode(currentZone, forKey: .currentZone)
        try container.encode(windowZoneTags, forKey: .windowZoneTags)
        let focusByZoneStringKeys = focusedWindowIDByZone.reduce(into: [String: String]()) { result, pair in
            result[String(pair.key)] = pair.value
        }
        try container.encode(focusByZoneStringKeys, forKey: .focusedWindowIDByZone)
    }
}

/// Pure zone state machine, ported from madang's ZoneEngine. No AppKit/layout dependency:
/// it reorders opaque window-id lists by zone and tracks the current zone + per-zone focus.
struct ZoneEngine {
    private(set) var config: ZonesConfig
    private(set) var state: ZoneState

    init(config: ZonesConfig = .defaults, state: ZoneState = .defaults) {
        self.config = config
        self.state = state.stateVersion == ZoneState.currentVersion ? state : .defaults
        normalizeCurrentZone()
    }

    mutating func configure(_ config: ZonesConfig) {
        self.config = config
        state.windowZoneTags = state.windowZoneTags.filter { isValidZoneID($0.value) }
        normalizeCurrentZone()
    }

    mutating func replaceState(_ state: ZoneState) {
        self.state = state.stateVersion == ZoneState.currentVersion ? state : .defaults
        self.state.windowZoneTags = self.state.windowZoneTags.filter { isValidZoneID($0.value) }
        normalizeCurrentZone()
    }

    mutating func reconciledOrder(windows: [ZoneWindow], orderedWindowIDs: [String]) -> [String] {
        guard config.enabled else { return orderedWindowIDs }
        let liveIDs = Set(windows.map(\.id))
        let orderedWindowIDs = uniqueOrder(orderedWindowIDs).filter { liveIDs.contains($0) }
        reconcile(windows: windows)
        return sortedOrder(orderedWindowIDs: orderedWindowIDs)
    }

    mutating func reconcile(windows: [ZoneWindow]) {
        guard config.enabled else { return }
        let currentIDs = Set(windows.map(\.id))
        state.windowZoneTags = state.windowZoneTags.filter { currentIDs.contains($0.key) && isValidZoneID($0.value) }
        state.focusedWindowIDByZone = state.focusedWindowIDByZone
            .filter { currentIDs.contains($0.value) && isValidZoneID($0.key) }

        // Initial placement only: a bundle assignment decides a window's zone the first time we see
        // it (untagged); an unmapped app lands in the current/active zone. After that the tag is
        // sticky and independent of the app — so a manual move-window-to-zone persists, and zones
        // aren't re-forced every cycle. A reopened app gets a fresh window id, so it's placed again.
        for window in windows where state.windowZoneTags[window.id] == nil {
            if let zoneID = config.bundleAssignments[window.bundleID], isValidZoneID(zoneID) {
                state.windowZoneTags[window.id] = zoneID
            } else {
                state.windowZoneTags[window.id] = isValidZoneID(state.currentZone)
                    ? state.currentZone
                    : (orderedZoneIDs().first ?? 1)
            }
        }
    }

    func sortedOrder(orderedWindowIDs: [String]) -> [String] {
        guard config.enabled else { return orderedWindowIDs }
        let orderedWindowIDs = uniqueOrder(orderedWindowIDs)
        let orderedIndex = Dictionary(
            orderedWindowIDs.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        return orderedWindowIDs.sorted { lhs, rhs in
            let lhsZone = sortRank(for: state.windowZoneTags[lhs])
            let rhsZone = sortRank(for: state.windowZoneTags[rhs])
            if lhsZone != rhsZone { return lhsZone < rhsZone }
            return (orderedIndex[lhs] ?? Int.max) < (orderedIndex[rhs] ?? Int.max)
        }
    }

    mutating func move(windowID: String, toZone zoneID: Int, orderedWindowIDs: [String]) -> [String] {
        guard config.enabled else { return orderedWindowIDs }
        let orderedWindowIDs = uniqueOrder(orderedWindowIDs)
        guard isValidZoneID(zoneID), orderedWindowIDs.contains(windowID) else { return orderedWindowIDs }
        state.windowZoneTags[windowID] = zoneID
        state.currentZone = zoneID
        return sortedOrder(orderedWindowIDs: orderedWindowIDs)
    }

    mutating func updateCurrentZone(focusedWindowID: String?) {
        guard config.enabled, let focusedWindowID, let zoneID = state.windowZoneTags[focusedWindowID] else { return }
        state.currentZone = zoneID
    }

    /// Directly set the active zone, including an empty zone (which `updateCurrentZone` can't express).
    mutating func setCurrentZone(_ zoneID: Int) {
        guard config.enabled, isValidZoneID(zoneID) else { return }
        state.currentZone = zoneID
    }

    mutating func setLayoutMode(_ mode: ZoneLayoutMode) {
        config.layoutMode = mode
    }

    /// Record the window last focused within a zone, so returning to it restores focus.
    mutating func rememberFocus(windowID: String, inZone zoneID: Int) {
        guard config.enabled, isValidZoneID(zoneID), state.windowZoneTags[windowID] == zoneID else { return }
        state.focusedWindowIDByZone[zoneID] = windowID
    }

    /// The window to focus when switching to a zone: the remembered one if still live & tagged,
    /// else the zone's first window, else nil (empty zone).
    func restoredFocusTarget(forZone zoneID: Int, orderedWindowIDs: [String]) -> String? {
        guard config.enabled, isValidZoneID(zoneID) else { return nil }
        if let remembered = state.focusedWindowIDByZone[zoneID],
           state.windowZoneTags[remembered] == zoneID,
           orderedWindowIDs.contains(remembered)
        {
            return remembered
        }
        return focusTarget(zoneID: zoneID, orderedWindowIDs: orderedWindowIDs)
    }

    func zoneIDOrder() -> [Int] { orderedZoneIDs() }

    func focusTarget(zoneID: Int, orderedWindowIDs: [String]) -> String? {
        guard config.enabled, isValidZoneID(zoneID) else { return nil }
        return orderedWindowIDs.first { state.windowZoneTags[$0] == zoneID }
    }

    func nextZoneTarget(direction: Int, orderedWindowIDs: [String]) -> (zoneID: Int, windowID: String)? {
        guard config.enabled, !orderedWindowIDs.isEmpty else { return nil }
        let ids = orderedZoneIDs()
        guard !ids.isEmpty else { return nil }
        var index = ids.firstIndex(of: state.currentZone) ?? 0
        for _ in ids {
            index = (index + direction + ids.count) % ids.count
            let zoneID = ids[index]
            if let windowID = focusTarget(zoneID: zoneID, orderedWindowIDs: orderedWindowIDs) {
                return (zoneID, windowID)
            }
        }
        return nil
    }

    func zoneID(forWindowID windowID: String) -> Int? { state.windowZoneTags[windowID] }

    func containsZone(_ zoneID: Int) -> Bool { isValidZoneID(zoneID) }

    private mutating func normalizeCurrentZone() {
        if !isValidZoneID(state.currentZone) { state.currentZone = orderedZoneIDs().first ?? 1 }
    }

    private func orderedZoneIDs() -> [Int] { config.definitions.map(\.id).filter { $0 > 0 } }

    private func isValidZoneID(_ zoneID: Int) -> Bool { orderedZoneIDs().contains(zoneID) }

    private func sortRank(for zoneID: Int?) -> Int {
        guard let zoneID, let index = orderedZoneIDs().firstIndex(of: zoneID) else { return Int.max }
        return index
    }

    private func uniqueOrder(_ orderedWindowIDs: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for id in orderedWindowIDs where !seen.contains(id) {
            seen.insert(id)
            unique.append(id)
        }
        return unique
    }
}
