# Leader

A vim-style **leader menu** as a tab in OmniWM's Command Palette: a configurable, single-key
**tree** where each key either fires an action, focuses an app, or opens a **folder** (submenu).

## Opening
- **Double-tap F15** → palette opens on the **Leader** tab at the root menu (see [f15.md](f15.md)).
- Or pick the **Leader** tab manually (`⌘4`).

## Keys
- Press an item's **key** → fires immediately (no Enter). Folder items (shown with `▸`) descend into a submenu.
- **Esc** → back out one level; **Esc** at the root → close. **Backspace** also backs out.
- Arrow keys + **Enter** work too, if you prefer selecting.

## Config: `~/.config/omniwm/leader.json`
Seeded on first run; reloaded each time the leader opens, so edits apply on next open.
```json
{
  "doubleTapOpensLeader": true,
  "rootMenu": "main",
  "menus": {
    "main": [
      { "key": "c", "title": "Slack",  "app": "com.tinyspeck.slackmacgap" },
      { "key": "f", "title": "Full",   "action": "toggleFullscreen" },
      { "key": "s", "title": "Switch", "menu": "switch" }
    ],
    "switch": [ { "key": "1", "title": "Meeting", "action": "focusZone.1" } ]
  }
}
```

### Item schema
Each item is `{ "key", "title" }` plus **exactly one** of:
- `"menu"` — name of a submenu to open (folder).
- `"app"` — a bundle id; focuses the running app or launches it.
- `"action"` — an action id resolved via `ActionCatalog` (e.g. `focusZone.3`, `moveWindowToZone.2`, `toggleFullscreen`, `move.left`). Any catalog action id works.

`doubleTapOpensLeader: false` makes double-tap F15 open the normal palette instead.

## Implementation
- `Sources/OmniWM/Core/Config/LeaderConfig.swift` — `LeaderConfig` / `LeaderMenuItem` + default tree + pure `LeaderNavigator` (tested in `Tests/OmniWMFeatureTests/LeaderConfigTests.swift`).
- `Sources/OmniWM/Core/Config/LeaderConfigStore.swift` — load/seed `leader.json`.
- `Sources/OmniWM/Core/CommandPaletteMode.swift` — `.leader` mode.
- `Sources/OmniWM/UI/CommandPalette/CommandPaletteController.swift` — `.leader` palette handling: single-key dispatch, folder stack + breadcrumb, app/action dispatch, `CommandPaletteLeaderRow`.
- Opened via `HotkeyCommand.openLeader` → `WMController.openLeaderPalette()` → `CommandPaletteController.toggleLeader`.
