import AppKit
import SwiftUI

/// Renders a leader item's icon. Resolution: a custom `icon` (emoji, or `sf:symbol.name`
/// for an SF Symbol) wins; otherwise auto-derive — real app icon for App items, a folder
/// for submenus, a terminal glyph for scripts, a bolt for actions.
struct LeaderIconView: View {
    let item: LeaderMenuItem
    var size: CGFloat = 18

    var body: some View {
        content
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private var content: some View {
        if let custom = item.icon, !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            if let symbol = LeaderIcon.symbolName(custom) {
                Image(systemName: symbol).font(.system(size: size * 0.85))
            } else {
                Text(custom).font(.system(size: size * 0.9)) // emoji / short text
            }
        } else if let appIcon = LeaderIcon.autoAppImage(for: item) {
            Image(nsImage: appIcon).resizable().scaledToFit()
        } else {
            Image(systemName: LeaderIcon.autoSymbol(for: item))
                .font(.system(size: size * 0.8))
                .foregroundStyle(.secondary)
        }
    }
}

enum LeaderIcon {
    /// `sf:gear` → "gear". Returns nil when the value isn't an SF-symbol reference.
    static func symbolName(_ raw: String) -> String? {
        guard raw.hasPrefix("sf:") else { return nil }
        let name = String(raw.dropFirst(3))
        return name.isEmpty ? nil : name
    }

    /// The real app icon for App items (path or bundle id), else nil.
    static func autoAppImage(for item: LeaderMenuItem) -> NSImage? {
        guard let target = item.app, !target.isEmpty else { return nil }
        let workspace = NSWorkspace.shared
        if target.hasPrefix("/") || target.hasSuffix(".app") {
            return workspace.icon(forFile: target)
        }
        if let url = workspace.urlForApplication(withBundleIdentifier: target) {
            return workspace.icon(forFile: url.path)
        }
        return nil
    }

    static func autoSymbol(for item: LeaderMenuItem) -> String {
        if item.menu != nil { return "folder" }
        if item.script != nil { return "terminal" }
        if item.app != nil { return "app" }
        return "bolt"
    }
}
