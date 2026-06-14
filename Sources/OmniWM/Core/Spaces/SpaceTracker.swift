import Foundation

@MainActor
final class SpaceTracker {
    weak var controller: WMController?

    init(controller: WMController) {
        self.controller = controller
    }

    private var isEnabled: Bool {
        controller?.settings.spacesTrackingEnabled ?? false
    }

    func start() {
        refresh()
    }

    func refresh() {
        guard let controller, isEnabled else { return }
        let managed = SkyLight.shared.managedSpaces()
        guard !managed.isEmpty else { return }

        var topology = SpaceTopology()
        topology.displays = managed.map {
            SpaceTopology.DisplaySpaces(
                displayIdentifier: $0.displayIdentifier,
                spaceIds: $0.spaceIds,
                currentSpaceId: $0.currentSpaceId
            )
        }
        topology.fullscreenSpaceIds = managed.reduce(into: Set<UInt64>()) { $0.formUnion($1.fullscreenSpaceIds) }
        topology.activeSpaceId = SkyLight.shared.activeSpace() ?? 0
        for entry in controller.workspaceManager.allEntries() {
            let windowId = entry.windowId
            guard windowId > 0, let spaceId = SkyLight.shared.spaceForWindow(UInt32(windowId)) else { continue }
            topology.windowSpace[windowId] = spaceId
        }
        controller.workspaceManager.commitSpaceTopology(topology)
    }

    func noteWindowSpace(windowId: Int, spaceId: UInt64) {
        guard let controller, isEnabled, spaceId != 0 else { return }
        guard controller.workspaceManager.entry(forWindowId: windowId) != nil else { return }
        var topology = controller.workspaceManager.spaceTopology
        guard topology.windowSpace[windowId] != spaceId else { return }
        topology.windowSpace[windowId] = spaceId
        controller.workspaceManager.commitSpaceTopology(topology)
    }

    func noteWindowDestroyed(windowId: Int) {
        guard let controller, isEnabled else { return }
        var topology = controller.workspaceManager.spaceTopology
        guard topology.windowSpace.removeValue(forKey: windowId) != nil else { return }
        controller.workspaceManager.commitSpaceTopology(topology)
    }
}
