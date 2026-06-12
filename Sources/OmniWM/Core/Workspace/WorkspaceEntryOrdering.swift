import Foundation

@MainActor
enum WorkspaceEntryOrdering {
    private struct SortKey {
        let group: Int
        let primary: Int
        let secondary: Int
    }

    static func orderedEntries(
        _ entries: [WindowModel.Entry],
        topology: LayoutTopology
    ) -> [WindowModel.Entry] {
        guard topology.hasColumns else { return entries }

        var orderMap: [WindowToken: SortKey] = [:]
        for (columnIndex, column) in topology.columns.enumerated() {
            for (rowIndex, tile) in column.tiles.enumerated() {
                orderMap[tile.token] = SortKey(group: 0, primary: columnIndex, secondary: rowIndex)
            }
        }

        let fallbackOrder = Dictionary(uniqueKeysWithValues: entries.enumerated()
            .map { ($0.element.handle.id, $0.offset) })

        return entries.sorted { lhs, rhs in
            let lhsKey = orderMap[lhs.handle.id] ?? SortKey(group: 2, primary: Int.max, secondary: Int.max)
            let rhsKey = orderMap[rhs.handle.id] ?? SortKey(group: 2, primary: Int.max, secondary: Int.max)

            if lhsKey.group != rhsKey.group { return lhsKey.group < rhsKey.group }
            if lhsKey.primary != rhsKey.primary { return lhsKey.primary < rhsKey.primary }
            if lhsKey.secondary != rhsKey.secondary { return lhsKey.secondary < rhsKey.secondary }

            let lhsFallback = fallbackOrder[lhs.handle.id] ?? 0
            let rhsFallback = fallbackOrder[rhs.handle.id] ?? 0
            return lhsFallback < rhsFallback
        }
    }
}
