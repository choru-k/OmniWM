import Foundation

@MainActor
final class EventInterpreter: EventIntakeSink {
    weak var controller: WMController?

    init(controller: WMController) {
        self.controller = controller
    }

    func handleIntakeEvent(_ stamped: StampedIntakeEvent) {
        guard let controller else { return }

        switch stamped.event {
        case .activeSpaceChanged:
            controller.serviceLifecycleManager.handleActiveSpaceDidChange()

        case let .appActivated(pid):
            controller.axEventHandler.handleAppActivation(
                pid: pid,
                source: .workspaceDidActivateApplication
            )

        case let .appDeactivated(pid):
            controller.axEventHandler.handleAppDeactivated(pid: pid)

        case let .appHidden(pid):
            controller.axEventHandler.handleAppHidden(pid: pid)

        case .appLaunched:
            controller.serviceLifecycleManager.handleAppLaunched()

        case let .appTerminated(pid):
            controller.serviceLifecycleManager.handleAppTerminated(pid: pid)

        case let .appUnhidden(pid):
            controller.axEventHandler.handleAppUnhidden(pid: pid)

        case let .axFocusedWindowChanged(pid):
            controller.axEventHandler.handleAppActivation(
                pid: pid,
                source: .focusedWindowChanged
            )

        case let .axWindowDestroyed(pid, windowId):
            controller.axEventHandler.handleRemoved(pid: pid, winId: windowId)

        case let .axWindowMiniaturized(pid, windowId):
            controller.axEventHandler.handleWindowMiniaturized(pid: pid, windowId: windowId)

        case let .cgs(event):
            controller.axEventHandler.handleCGSEvent(event)

        case let .display(event):
            controller.serviceLifecycleManager.handleDisplayEvent(event)

        case let .hotkeyCommand(command):
            _ = controller.commandHandler.handleHotkeyCommand(command)

        case let .ipcCommand(intake):
            intake.completion(intake.perform(controller))

        case .systemSleep:
            _ = controller.workspaceManager.recordReconcileEvent(.systemSleep(source: .service))

        case .systemWake:
            _ = controller.workspaceManager.recordReconcileEvent(.systemWake(source: .service))
            controller.layoutRefreshController.requestFullRescan(reason: .unlock)
        }
    }
}
