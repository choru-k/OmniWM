import AppKit
import Foundation

struct OffsetTransition: Equatable {
    enum Kind: Equatable {
        case jump
        case spring(SpringConfig)
    }

    var rebaseDelta: CGFloat = 0
    var kind: Kind?
}

struct ViewportState: Equatable {
    var activeColumnIndex: Int = 0

    var viewOffset: CGFloat = 0.0

    var offsetTransition = OffsetTransition()

    var selectionProgress: CGFloat = 0.0

    var selectedNodeId: NodeId?

    var viewOffsetToRestore: CGFloat?

    var activatePrevColumnOnRemoval: CGFloat?

    var displayRefreshRate: Double = 60.0
}

extension ViewportState {
    var hasPendingSpringTransition: Bool {
        if case .spring = offsetTransition.kind { return true }
        return false
    }

    mutating func rebaseOffset(by delta: CGFloat) {
        viewOffset += delta
        offsetTransition.rebaseDelta += delta
    }

    mutating func jumpOffset(to offset: CGFloat) {
        offsetTransition.rebaseDelta += offset - viewOffset
        viewOffset = offset
        offsetTransition.kind = .jump
    }

    mutating func springOffset(to offset: CGFloat, config: SpringConfig? = nil) {
        viewOffset = offset
        offsetTransition.kind = .spring(config ?? .niriHorizontalViewMovement)
    }

    mutating func clearOffsetTransition() {
        offsetTransition = OffsetTransition()
    }
}
