@MainActor protocol LayoutFocusable: AnyObject {
    func focusNeighbor(direction: Direction) -> Bool
}

@MainActor protocol LayoutSizable: AnyObject {
    func cycleSize(forward: Bool)
    func balanceSizes()
}
