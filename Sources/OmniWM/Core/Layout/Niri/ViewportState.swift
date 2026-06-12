import AppKit
import Foundation

enum ViewOffset: Equatable {
    case `static`(CGFloat)
    case spring(SpringAnimation)

    static func == (lhs: ViewOffset, rhs: ViewOffset) -> Bool {
        switch (lhs, rhs) {
        case let (.static(lhsOffset), .static(rhsOffset)):
            lhsOffset == rhsOffset
        case let (.spring(lhsAnimation), .spring(rhsAnimation)):
            lhsAnimation === rhsAnimation
        default:
            false
        }
    }

    func current() -> CGFloat {
        switch self {
        case let .static(offset):
            offset
        case let .spring(anim):
            CGFloat(anim.value(at: CACurrentMediaTime()))
        }
    }

    func value(at time: TimeInterval) -> CGFloat {
        switch self {
        case let .static(offset):
            offset
        case let .spring(anim):
            CGFloat(anim.value(at: time))
        }
    }

    func target() -> CGFloat {
        switch self {
        case let .static(offset):
            offset
        case let .spring(anim):
            CGFloat(anim.target)
        }
    }

    var isAnimating: Bool {
        switch self {
        case .spring:
            true
        case .static:
            false
        }
    }

    mutating func offset(delta: Double) {
        switch self {
        case .static(let offset):
            self = .static(CGFloat(Double(offset) + delta))
        case .spring(let anim):
            anim.offsetBy(delta)
        }
    }

    func currentVelocity(at time: TimeInterval = CACurrentMediaTime()) -> Double {
        switch self {
        case .static:
            0
        case let .spring(anim):
            anim.velocity(at: time)
        }
    }

    func velocity(at time: TimeInterval) -> Double {
        switch self {
        case .static:
            0
        case let .spring(anim):
            anim.velocity(at: time)
        }
    }
}

struct ViewportState: Equatable {
    var activeColumnIndex: Int = 0

    var viewOffsetPixels: ViewOffset = .static(0.0)

    var selectionProgress: CGFloat = 0.0

    var selectedNodeId: NodeId?

    var viewOffsetToRestore: CGFloat?

    var activatePrevColumnOnRemoval: CGFloat?

    let springConfig: SpringConfig = .niriHorizontalViewMovement

    var displayRefreshRate: Double = 60.0
}

extension ViewportState {
    mutating func resolveCommitConflicts(against current: ViewportState, hasStaleSelection: Bool) {
        if hasStaleSelection {
            selectedNodeId = current.selectedNodeId
            activeColumnIndex = current.activeColumnIndex
            selectionProgress = current.selectionProgress
        }
    }
}
