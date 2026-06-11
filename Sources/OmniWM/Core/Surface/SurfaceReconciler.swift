import CoreGraphics
import Foundation

struct DesiredSurfaceScene: Equatable {
    static let empty = DesiredSurfaceScene()
}

enum SurfaceDerivation {
    @MainActor
    static func derive(world: WorldView) -> DesiredSurfaceScene {
        guard world.hasStartedServices else { return .empty }
        return .empty
    }
}

@MainActor
final class SurfaceReconciler {
    private weak var controller: WMController?
    private var reconcileScheduled = false
    private(set) var appliedScene = DesiredSurfaceScene.empty

    init(controller: WMController) {
        self.controller = controller
    }

    func noteWorldChanged() {
        guard !reconcileScheduled else { return }
        reconcileScheduled = true
        let mainRunLoop = CFRunLoopGetMain()
        CFRunLoopPerformBlock(mainRunLoop, CFRunLoopMode.commonModes.rawValue) {
            MainActor.assumeIsolated {
                self.flushScheduledReconcile()
            }
        }
        CFRunLoopWakeUp(mainRunLoop)
    }

    func reconcileNow() {
        reconcileScheduled = false
        guard let controller else { return }
        apply(SurfaceDerivation.derive(world: WorldView(controller: controller)))
    }

    private func flushScheduledReconcile() {
        guard reconcileScheduled else { return }
        reconcileNow()
    }

    private func apply(_ desired: DesiredSurfaceScene) {
        guard desired != appliedScene else { return }
        appliedScene = desired
    }
}
