import CoreGraphics
import Foundation

@MainActor
struct WorldView {
    private let controller: WMController

    init(controller: WMController) {
        self.controller = controller
    }

    var hasStartedServices: Bool {
        controller.hasStartedServices
    }

    var monitors: [Monitor] {
        controller.workspaceManager.monitors
    }

    func committedFrame(forWindowId windowId: Int) -> CGRect? {
        controller.axManager.pendingFrameWrite(for: windowId)
            ?? controller.axManager.lastAppliedFrame(for: windowId)
    }
}
