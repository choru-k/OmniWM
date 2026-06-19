# Leader

A vim-style **leader menu** as a tab in OmniWM's Command Palette: a configurable, single-key
**tree** where each key either fires an action, focuses an app, or opens a **folder** (submenu).

## Opening
- **Double-tap the leader key** (F15 by default; configurable, see [f15.md](f15.md)) → palette opens on the **Leader** tab at the root menu.
- Or pick the **Leader** tab manually (`⌘4`).

## Keys
- Press an item's **key** → fires immediately (no Enter). Folder items (shown with `▸`) descend into a submenu.
- **Esc** → back out one level; **Esc** at the root → close. **Backspace** also backs out.
- Arrow keys + **Enter** work too, if you prefer selecting.

## Configure in the app (recommended)
**Settings → Input → Leader (F15)** has an **inline tree editor** for the whole menu — no JSON
required. Each row has a key, title, optional icon, a type picker, and a value:
- **Group** rows expand/collapse inline; **Add action** / **Add group** build nested folders.
- **App** rows take a bundle id *or* a file path, with a **Choose…** button (file picker).
- **Script** rows take a shell command (or **Choose…** a script file).
- **Action** rows pick from the action catalog.
- **Icon** column: type an emoji, or `sf:symbol.name` for an SF Symbol; leave blank to auto-pick
  (real app icon for apps, folder for groups, terminal for scripts, bolt for actions). Icons also
  show in the palette.

The editor writes the same `leader.json` below, and there's a **Reveal leader.json in Finder** button.

## Config: `~/.config/omniwm/leader.json`
Seeded on first run; reloaded each time the leader opens, so edits apply on next open.
```json
{
  "doubleTapOpensLeader": true,
  "rootMenu": "main",
  "menus": {
    "main": [
      { "key": "c", "title": "Slack",  "app": "com.tinyspeck.slackmacgap", "icon": "💬" },
      { "key": "e", "title": "Editor", "app": "/Applications/Emacs.app" },
      { "key": "g", "title": "Gitsync","script": "cd ~/dev && git pull", "icon": "sf:arrow.triangle.2.circlepath" },
      { "key": "f", "title": "Full",   "action": "toggleFullscreen" },
      { "key": "s", "title": "Switch", "menu": "switch" }
    ],
    "switch": [ { "key": "1", "title": "Meeting", "action": "focusZone.1" } ]
  }
}
```

### Item schema
Each item is `{ "key", "title" }`, an optional `"icon"`, plus **exactly one** of:
- `"menu"` — name of a submenu to open (folder).
- `"app"` — a bundle id **or** an absolute path to a `.app`; focuses the running app or launches it.
- `"script"` — a shell command, run fire-and-forget via `/bin/zsh -lc` (the config is user-owned).
- `"action"` — an action id resolved via `ActionCatalog` (e.g. `focusZone.3`, `moveWindowToZone.2`, `toggleFullscreen`, `move.left`). Any catalog action id works.

`"icon"` is an emoji, or `sf:symbol.name` for an SF Symbol; when omitted the UI auto-derives one.

`doubleTapOpensLeader: false` makes double-tapping the leader key open the normal palette instead.

## Implementation
- `Sources/OmniWM/Core/Config/LeaderConfig.swift` — `LeaderConfig` / `LeaderMenuItem` (fields: `menu`/`app`/`script`/`action` + `icon`) + default tree + pure `LeaderNavigator` (tested in `Tests/OmniWMFeatureTests/LeaderConfigTests.swift`).
- `Sources/OmniWM/Core/Config/LeaderConfigStore.swift` — load/seed/write `leader.json` + `revealInFinder()`.
- `Sources/OmniWM/Core/CommandPaletteMode.swift` — `.leader` mode.
- `Sources/OmniWM/UI/CommandPalette/CommandPaletteController.swift` — `.leader` palette handling: single-key dispatch, folder stack + breadcrumb, `dispatchLeaderItem` (action/script/app-or-path), `CommandPaletteLeaderRow` (now with an icon).
- `Sources/OmniWM/UI/LeaderSettingsView.swift` — the in-app inline-tree editor (also edits the F15 chords + leader key).
- `Sources/OmniWM/UI/LeaderIconView.swift` — icon resolver (emoji / `sf:` symbol / auto app-icon), used by palette + editor. Tested in `Tests/OmniWMFeatureTests/LeaderIconTests.swift`.
- Opened via `HotkeyCommand.openLeader` → `WMController.openLeaderPalette()` → `CommandPaletteController.toggleLeader`.
