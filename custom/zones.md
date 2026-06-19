# Zones (anchor model)

Logical "zones" layered over OmniWM's single Niri column strip. A zone is an **anchor**: the
leftmost column of the windows tagged to it. There is always one strip — zones don't hide or split
it; they're named jump targets that keep related apps grouped. (Ported from the nehir fork's
`ZoneEngine`, originally from madang.)

## Behavior
- **`focus-zone N`** — jump focus to zone N's anchor (its first column), scrolling it into view. No-op if the zone is empty.
- **`move-window-to-zone N`** — tag the focused window's column to zone N and slide it into that zone's region of the strip.
- **Auto-sort** — whenever windows change, the strip is re-ordered into zone order (1 → 6) so apps stay grouped. No-op when zones are disabled or already sorted; the focused window stays focused across the re-sort.

### Zone = initial placement, then sticky (independent of the app)
A window's zone is decided **only the first time it's seen**: a `bundleAssignments` entry wins,
otherwise it lands in the **current/active zone** (the one you're focused in when it opens). After
that the tag is sticky: a manual `move-window-to-zone` persists, switching the active zone doesn't
drag it along, and reopening an app (a fresh window) places it again. Tags are recomputed each
session (not persisted across restart).

## Config: `~/.config/omniwm/zones.json`
The app→zone map and zone names live here (seeded on first run); the on/off switch is in
`settings.toml` (`[general] zonesEnabled`).
```json
{
  "bundleAssignments": { "us.zoom.xos": 1, "md.obsidian": 2, "com.tinyspeck.slackmacgap": 3 },
  "definitions": [ { "id": 1, "name": "meeting", "icon": "camera" } ]
}
```

## Enable & use
```toml
[general]
zonesEnabled = true   # default false
```
```sh
omniwmctl command focus-zone 3            # jump to zone 3
omniwmctl command move-window-to-zone 2   # send focused window to zone 2
```
Also bindable as hotkeys / from the [Leader](leader.md) tree via action ids `focusZone.1…6` /
`moveWindowToZone.1…6`.

> The SketchyBar plugin (`~/dotfiles/system/sketchybar/plugins/zones.sh`) reads this same
> `zones.json` (via `jq`) and `omniwmctl query windows` — so it's the single source of truth.

## Implementation
- `Sources/OmniWM/Core/Layout/Niri/ZonesConfig.swift` — config + defaults (Codable; persists `bundleAssignments`/`definitions`).
- `Sources/OmniWM/Core/Layout/Niri/ZoneEngine.swift` — pure state machine (tag/sort/anchor/restore-focus), keyed by `"pid:windowId"`. Tested (`Tests/OmniWMFeatureTests/ZoneEngineTests.swift`).
- `Sources/OmniWM/Core/Config/ZonesConfigStore.swift` — load/seed `zones.json`.
- `Sources/OmniWM/Core/Layout/Niri/NiriLayoutEngine+ColumnOps.swift` — `applyZoneOrdering` (auto-sort), called from `NiriLayoutHandler.buildRelayoutPlan`.
- `Sources/OmniWM/Core/Controller/CommandHandler.swift` — `focusZoneInNiri` / `moveWindowToZoneInNiri` (reuse `focusColumn` / `moveColumnToIndex`).
- IPC/CLI: `focus-zone` / `move-window-to-zone` (1-based) in `OmniWMIPC/IPCModels.swift`, `IPCAutomationManifest.swift`, `IPC/IPCCommandRouter.swift`.
- ActionCatalog: `focusZone.N` / `moveWindowToZone.N` action ids.
