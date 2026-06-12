import Foundation
import QuartzCore

@MainActor
final class AnimationDriver {
    nonisolated static let gestureWorkingAreaMovement: Double = 1200.0

    final class ViewportGesture {
        let tracker = SwipeTracker()
        let isTrackpad: Bool
        private(set) var normFactor: Double = 1.0

        init(isTrackpad: Bool) {
            self.isTrackpad = isTrackpad
        }

        var relativeOffset: Double {
            tracker.position * normFactor
        }

        func update(delta: Double, timestamp: TimeInterval, viewportWidth: Double) {
            tracker.push(delta: delta, timestamp: timestamp)
            if isTrackpad {
                normFactor = viewportWidth / AnimationDriver.gestureWorkingAreaMovement
            }
        }
    }

    struct GestureEndSample {
        let relativeOffset: Double
        let relativeProjectedOffset: Double
        let velocity: Double
    }

    private var gestures: [WorkspaceDescriptor.ID: ViewportGesture] = [:]

    func hasGesture(in workspaceId: WorkspaceDescriptor.ID) -> Bool {
        gestures[workspaceId] != nil
    }

    func trackpadGestureActive(in workspaceId: WorkspaceDescriptor.ID) -> Bool {
        gestures[workspaceId]?.isTrackpad == true
    }

    func beginGesture(in workspaceId: WorkspaceDescriptor.ID, isTrackpad: Bool) {
        gestures[workspaceId] = ViewportGesture(isTrackpad: isTrackpad)
    }

    func updateGesture(
        in workspaceId: WorkspaceDescriptor.ID,
        delta: Double,
        timestamp: TimeInterval,
        isTrackpad: Bool,
        viewportWidth: Double
    ) {
        guard let gesture = gestures[workspaceId], gesture.isTrackpad == isTrackpad else { return }
        gesture.update(delta: delta, timestamp: timestamp, viewportWidth: viewportWidth)
    }

    func gestureLiveOffset(in workspaceId: WorkspaceDescriptor.ID, semanticOffset: CGFloat) -> CGFloat? {
        guard let gesture = gestures[workspaceId] else { return nil }
        return semanticOffset + CGFloat(gesture.relativeOffset)
    }

    func finishGesture(
        in workspaceId: WorkspaceDescriptor.ID,
        isTrackpad: Bool? = nil,
        viewportWidth: Double,
        timestamp: TimeInterval?
    ) -> GestureEndSample? {
        guard let gesture = gestures[workspaceId] else { return nil }
        if let isTrackpad, gesture.isTrackpad != isTrackpad { return nil }
        gestures.removeValue(forKey: workspaceId)
        gesture.update(delta: 0, timestamp: timestamp ?? CACurrentMediaTime(), viewportWidth: viewportWidth)
        return GestureEndSample(
            relativeOffset: gesture.relativeOffset,
            relativeProjectedOffset: gesture.tracker.projectedEndPosition() * gesture.normFactor,
            velocity: gesture.tracker.velocity() * gesture.normFactor
        )
    }

    @discardableResult
    func cancelGesture(in workspaceId: WorkspaceDescriptor.ID) -> Double? {
        gestures.removeValue(forKey: workspaceId)?.relativeOffset
    }

    func removeMotions<S: Sequence>(for workspaceIds: S) where S.Element == WorkspaceDescriptor.ID {
        for workspaceId in workspaceIds {
            gestures.removeValue(forKey: workspaceId)
        }
    }
}
