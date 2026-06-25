import AppKit
import Carbon
import SwiftUI

/// Settings tab for the F15 leader system: enable/timing, the hold-chord map (f15.json),
/// and the double-tap Leader menu tree (leader.json). All three are file-backed and edited
/// in place here; chord edits push a live `reloadF15Config()`, while the Leader palette
/// re-reads leader.json on every open so menu edits need no reload hook.
struct LeaderSettingsView: View {
    @Bindable var settings: SettingsStore
    @Bindable var controller: WMController

    @State private var f15Config = F15Config.defaults
    @State private var leaderConfig = LeaderConfig.defaults
    @State private var loaded = false
    @State private var recordingChordIndex: Int?
    /// Which group rows are expanded, keyed by their tree path id (see `flatten`).
    @State private var expanded: Set<String> = []

    var body: some View {
        SettingsPage(subtitle: "Configure the leader key: hold \(leaderKeyName) with a key to fire a chord, or double-tap \(leaderKeyName) to open the Leader menu.") {
            leaderKeySection
            chordsSection
            menuSection
        }
        .onAppear(perform: loadIfNeeded)
    }

    // MARK: - Section A: Leader key

    private var leaderKeySection: some View {
        Section("Leader Key") {
            Toggle("Enable Leader", isOn: $settings.f15Enabled)
                .onChange(of: settings.f15Enabled) { _, _ in controller.reloadF15Config() }

            Picker("Leader key", selection: $settings.f15LeaderKeyCode) {
                ForEach(Self.leaderKeyChoices, id: \.code) { choice in
                    Text(choice.name).tag(choice.code)
                }
            }
            .onChange(of: settings.f15LeaderKeyCode) { _, _ in controller.reloadF15Config() }

            SettingsSliderRow(
                label: "Double-tap window",
                value: $settings.f15DoubleTapSeconds,
                range: 0.15 ... 0.6,
                step: 0.05,
                valueText: String(format: "%.2f s", settings.f15DoubleTapSeconds),
                valueWidth: 64
            )
            .onChange(of: settings.f15DoubleTapSeconds) { _, _ in controller.reloadF15Config() }

            Toggle("Double-tap opens Leader menu", isOn: Binding(
                get: { leaderConfig.doubleTapOpensLeader },
                set: { leaderConfig.doubleTapOpensLeader = $0; saveLeader() }
            ))

            SettingsCaption("F15 chords and the Leader menu need Input Monitoring permission to work.")
        }
    }

    // MARK: - Section B: Hold chords

    private var chordsSection: some View {
        Section("Hold Chords") {
            SettingsCaption("Hold \(leaderKeyName) and press the key to run the action.")

            ForEach(Array(f15Config.chords.enumerated()), id: \.offset) { index, item in
                LabeledContent {
                    HStack(spacing: 8) {
                        chordKeyControl(index: index, item: item)
                        actionPicker(selection: Binding(
                            get: { f15Config.chords[index].action },
                            set: { f15Config.chords[index].action = $0; saveF15() }
                        ))
                        Button {
                            recordingChordIndex = nil
                            f15Config.chords.remove(at: index)
                            saveF15()
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove this chord")
                    }
                } label: {
                    Text("\(leaderKeyName) +")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Add Chord") {
                    f15Config.chords.append(F15ChordItem(key: "", action: "focus.left"))
                    saveF15()
                }
                Spacer()
                Button("Reset to Defaults") {
                    recordingChordIndex = nil
                    f15Config.chords = F15Config.defaultChords
                    saveF15()
                }
            }
        }
    }

    @ViewBuilder
    private func chordKeyControl(index: Int, item: F15ChordItem) -> some View {
        if recordingChordIndex == index {
            KeyRecorderView(
                accessibilityLabel: "Recording chord key",
                allowsBareKeys: true,
                onCapture: { binding in
                    f15Config.chords[index].key = binding.humanReadableString
                    recordingChordIndex = nil
                    saveF15()
                },
                onCancel: { recordingChordIndex = nil }
            )
            .frame(minWidth: 150, minHeight: 34)
        } else {
            Button {
                recordingChordIndex = index
            } label: {
                Text(item.key.isEmpty ? "Set key…" : item.key)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 90)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Section C: Leader menu (inline expandable tree)

    private var menuSection: some View {
        Section("Leader Menu") {
            SettingsCaption("Double-tap \(leaderKeyName) then a key. Build nested groups; each key opens an app, runs a script, or runs an action.")

            columnHeader

            ForEach(treeRows) { row in
                if let index = row.index {
                    itemRow(menu: row.menu, index: index, rowID: row.id, depth: row.depth)
                } else {
                    addRow(menu: row.menu, menuPrefix: row.menuPrefix, depth: row.depth)
                }
            }

            Button {
                LeaderConfigStore.revealInFinder()
            } label: {
                Label("Reveal leader.json in Finder", systemImage: "folder")
            }
        }
    }

    /// Column titles aligned to the item-row field widths, so it's clear what each input is.
    private var columnHeader: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: 12)              // chevron
            Color.clear.frame(width: 18)              // icon preview
            Text("Key").frame(width: 44)
            Text("Title").frame(width: 100, alignment: .leading)
            Text("Type").frame(width: 96, alignment: .leading)
            Text("Target").frame(minWidth: 150, alignment: .leading)
            Text("Icon").frame(width: 64, alignment: .leading)
            Color.clear.frame(width: 16)              // delete
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    /// One flattened tree row: an editable item (`index != nil`) or a menu's add-buttons row.
    private struct TreeRow: Identifiable {
        let id: String
        let menu: String       // the menu this row lives in
        let menuPrefix: String // path prefix for items of `menu` (their children key off this)
        let index: Int?        // nil => add-buttons row
        let depth: Int
    }

    private var treeRows: [TreeRow] {
        var rows: [TreeRow] = []
        flatten(menu: leaderConfig.rootMenu, prefix: "root", depth: 0, visited: [leaderConfig.rootMenu], into: &rows)
        return rows
    }

    private func flatten(menu: String, prefix: String, depth: Int, visited: Set<String>, into rows: inout [TreeRow]) {
        let items = leaderConfig.menus[menu] ?? []
        for index in items.indices {
            let rowID = "\(prefix)/\(index)"
            rows.append(TreeRow(id: rowID, menu: menu, menuPrefix: prefix, index: index, depth: depth))
            if let sub = items[index].menu, expanded.contains(rowID), !visited.contains(sub) {
                flatten(menu: sub, prefix: rowID, depth: depth + 1, visited: visited.union([sub]), into: &rows)
            }
        }
        rows.append(TreeRow(id: "\(prefix)/+", menu: menu, menuPrefix: prefix, index: nil, depth: depth))
    }

    @ViewBuilder
    private func itemRow(menu: String, index: Int, rowID: String, depth: Int) -> some View {
        let item = Binding<LeaderMenuItem>(
            get: { leaderConfig.menus[menu]?[index] ?? LeaderMenuItem(key: "", title: "") },
            set: { leaderConfig.menus[menu]?[index] = $0; saveLeader() }
        )
        let isGroup = item.wrappedValue.menu != nil

        HStack(spacing: 8) {
            indent(depth)

            Button {
                if expanded.contains(rowID) { expanded.remove(rowID) } else { expanded.insert(rowID) }
            } label: {
                Image(systemName: expanded.contains(rowID) ? "chevron.down" : "chevron.right")
                    .frame(width: 12)
            }
            .buttonStyle(.borderless)
            .opacity(isGroup ? 1 : 0)
            .disabled(!isGroup)

            LeaderIconView(item: item.wrappedValue, size: 18)

            TextField("Key", text: Binding(
                get: { item.wrappedValue.key },
                set: { item.wrappedValue.key = String($0.suffix(1)) } // one key only; keep the latest char
            ), prompt: Text("key"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(width: 44)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
                .help("A single key to press for this item")

            TextField("Title", text: item.title, prompt: Text("Title"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)

            Picker("Type", selection: itemTypeBinding(item)) {
                Text("App").tag(LeaderItemType.app)
                Text("Script").tag(LeaderItemType.script)
                Text("Action").tag(LeaderItemType.action)
                Text("Group").tag(LeaderItemType.submenu)
            }
            .labelsHidden()
            .frame(width: 96)

            itemValue(item)

            TextField("Icon", text: Binding(
                get: { item.wrappedValue.icon ?? "" },
                set: { item.wrappedValue.icon = $0.isEmpty ? nil : $0 }
            ), prompt: Text("emoji"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)
                .help("Custom icon: an emoji, or sf:symbol.name for an SF Symbol. Leave blank to auto-pick.")

            Button {
                deleteItem(menu: menu, index: index)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove this item")
        }
    }

    @ViewBuilder
    private func itemValue(_ item: Binding<LeaderMenuItem>) -> some View {
        switch itemType(item.wrappedValue) {
        case .submenu:
            Label("opens this group", systemImage: "folder")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 150, alignment: .leading)
        case .app:
            HStack(spacing: 6) {
                TextField("App", text: Binding(
                    get: { item.wrappedValue.app ?? "" },
                    set: { item.wrappedValue.app = $0 }
                ), prompt: Text("bundle id or /path/to/App.app"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 140)
                Button("Choose…") { chooseFile(item, kind: .app) }
            }
            .frame(minWidth: 150, alignment: .leading)
        case .script:
            HStack(spacing: 6) {
                TextField("Script", text: Binding(
                    get: { item.wrappedValue.script ?? "" },
                    set: { item.wrappedValue.script = $0 }
                ), prompt: Text("shell command"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 140)
                    .font(.system(.body, design: .monospaced))
                Button("Choose…") { chooseFile(item, kind: .script) }
            }
            .frame(minWidth: 150, alignment: .leading)
        case .action:
            actionPicker(selection: Binding(
                get: { item.wrappedValue.action ?? "" },
                set: { item.wrappedValue.action = $0 }
            ))
            .frame(minWidth: 150, alignment: .leading)
        }
    }

    @ViewBuilder
    private func addRow(menu: String, menuPrefix: String, depth: Int) -> some View {
        HStack(spacing: 8) {
            indent(depth)
            Button {
                leaderConfig.menus[menu, default: []].append(
                    LeaderMenuItem(key: "", title: "New", action: "focus.left")
                )
                saveLeader()
            } label: {
                Label("Add action", systemImage: "bolt")
            }
            Button {
                let name = uniqueMenuName()
                leaderConfig.menus[name] = []
                let newIndex = leaderConfig.menus[menu, default: []].count
                leaderConfig.menus[menu, default: []].append(
                    LeaderMenuItem(key: "", title: "New Group", menu: name)
                )
                expanded.insert("\(menuPrefix)/\(newIndex)")
                saveLeader()
            } label: {
                Label("Add group", systemImage: "folder.badge.plus")
            }
            Spacer()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func indent(_ depth: Int) -> some View {
        Color.clear.frame(width: CGFloat(depth) * 18, height: 1)
    }

    /// Remove an item; if it was a group, prune its submenu when nothing else references it.
    private func deleteItem(menu: String, index: Int) {
        guard var items = leaderConfig.menus[menu], items.indices.contains(index) else { return }
        let removed = items.remove(at: index)
        leaderConfig.menus[menu] = items
        if let sub = removed.menu, !menuIsReferenced(sub) {
            leaderConfig.menus[sub] = nil
        }
        saveLeader()
    }

    private func menuIsReferenced(_ name: String) -> Bool {
        name == leaderConfig.rootMenu
            || leaderConfig.menus.values.contains { $0.contains { $0.menu == name } }
    }

    private enum ChooseKind { case app, script }

    private func chooseFile(_ item: Binding<LeaderMenuItem>, kind: ChooseKind) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        switch kind {
        case .app:
            panel.allowedContentTypes = [.application]
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
        case .script:
            panel.canChooseFiles = true
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        switch kind {
        case .app:
            item.wrappedValue.app = url.path
            if item.wrappedValue.title.isEmpty || item.wrappedValue.title == "New" {
                item.wrappedValue.title = url.deletingPathExtension().lastPathComponent
            }
        case .script:
            item.wrappedValue.script = url.path
        }
    }

    // MARK: - Shared action picker

    @ViewBuilder
    private func actionPicker(selection: Binding<String>) -> some View {
        Picker("Action", selection: selection) {
            // Keep an unknown/custom id selectable rather than silently blanking it.
            if !selection.wrappedValue.isEmpty, ActionCatalog.spec(for: selection.wrappedValue) == nil {
                Text(selection.wrappedValue).tag(selection.wrappedValue)
            }
            ForEach(HotkeyCategory.allCases, id: \.self) { category in
                Section(category.rawValue) {
                    ForEach(specs(in: category), id: \.id) { spec in
                        Text(spec.title).tag(spec.id)
                    }
                }
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    // MARK: - Helpers

    /// Function keys that have no default macOS binding, so they make good leaders.
    private static let leaderKeyChoices: [(code: Int, name: String)] = [
        (kVK_F13, "F13"), (kVK_F14, "F14"), (kVK_F15, "F15"), (kVK_F16, "F16"),
        (kVK_F17, "F17"), (kVK_F18, "F18"), (kVK_F19, "F19"), (kVK_F20, "F20")
    ]

    private enum LeaderItemType { case submenu, app, script, action }

    private func itemType(_ item: LeaderMenuItem) -> LeaderItemType {
        if item.menu != nil { return .submenu }
        if item.script != nil { return .script }
        if item.app != nil { return .app }
        return .action
    }

    private func itemTypeBinding(_ item: Binding<LeaderMenuItem>) -> Binding<LeaderItemType> {
        Binding(
            get: { itemType(item.wrappedValue) },
            set: { newType in
                var value = item.wrappedValue
                value.menu = nil
                value.app = nil
                value.script = nil
                value.action = nil
                switch newType {
                case .submenu:
                    let name = uniqueMenuName()
                    leaderConfig.menus[name] = [] // materialize the group so the palette can descend
                    value.menu = name
                case .app: value.app = ""
                case .script: value.script = ""
                case .action: value.action = "focus.left"
                }
                item.wrappedValue = value
            }
        )
    }

    private var leaderKeyName: String {
        Self.leaderKeyChoices.first { $0.code == settings.f15LeaderKeyCode }?.name ?? "Leader"
    }

    private var menuNames: [String] {
        leaderConfig.menus.keys.sorted()
    }

    private func specs(in category: HotkeyCategory) -> [ActionSpec] {
        ActionCatalog.allSpecs().filter { $0.category == category }
    }

    private func uniqueMenuName() -> String {
        var n = leaderConfig.menus.count + 1
        var name = "menu\(n)"
        while leaderConfig.menus[name] != nil {
            n += 1
            name = "menu\(n)"
        }
        return name
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        f15Config = F15ConfigStore.loadOrSeed()
        leaderConfig = LeaderConfigStore.loadOrSeed()
        loaded = true
    }

    private func saveF15() {
        try? F15ConfigStore.write(f15Config)
        controller.reloadF15Config()
    }

    private func saveLeader() {
        try? LeaderConfigStore.write(leaderConfig)
    }
}
