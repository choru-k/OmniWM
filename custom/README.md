# Custom features (this fork)

Features ported onto upstream `BarutSRB/OmniWM` from the earlier `guria/nehir` fork. All are
**off by default** — upstream behavior is unchanged until you opt in.

- [Zones](zones.md) — named "anchor" regions in the single Niri column strip; jump to / send windows to a zone.
- [Leader](leader.md) — a configurable, vim-style single-key menu tree, shown as a Command Palette tab (⌘4).
- [F15 chord layer](f15.md) — hold-F15 + key runs commands; double-tap opens the Leader tab.
- [Building & running this fork](build.md) — toolchain, the GhosttyKit stub, the macOS-15 SDK shims, packaging, permissions.

## Quick enable
`~/.config/omniwm/settings.toml`:
```toml
[general]
f15Enabled = true
zonesEnabled = true
# f15DoubleTapSeconds = 0.3   # optional
```
Structured custom-feature config lives in its own JSON file (seeded on first run):
- `~/.config/omniwm/leader.json` — the leader tree.
- `~/.config/omniwm/zones.json` — the app→zone map (`bundleAssignments`) + zone names.

After enabling F15, grant **Input Monitoring** (System Settings → Privacy & Security → Input Monitoring);
tiling needs **Accessibility** as usual.
