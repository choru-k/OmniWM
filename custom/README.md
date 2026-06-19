# Custom features (this fork)

Features ported onto upstream `BarutSRB/OmniWM` from the earlier `guria/nehir` fork. All are
**off by default** — upstream behavior is unchanged until you opt in.

- [Zones](zones.md) — named "anchor" regions in the single Niri column strip; jump to / send windows to a zone.
- [Leader](leader.md) — a configurable, vim-style single-key menu tree, shown as a Command Palette tab (⌘4).
- [F15 chord layer](f15.md) — hold-F15 + key runs commands (editable in `f15.json`); double-tap opens the Leader tab; includes tabbed-column toggle + wrap-around tab cycling.
- [Mouse resize](mouse.md) — resize with left-button + modifier drag (trackpad-friendly), not just right-button.
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
- `~/.config/omniwm/f15.json` — the F15 hold-chord map (`key` → action id).

After enabling F15, grant **Input Monitoring** (System Settings → Privacy & Security → Input Monitoring);
tiling needs **Accessibility** as usual.

## Setting up on a new Mac

Full toolchain / GhosttyKit stub / SDK shim details are in [build.md](build.md). Short version:

1. Install Swift 6.3.2 via swiftly and build: `~/.swiftly/bin/swiftly run swift build -c release`.
2. Provide the `GhosttyKit.xcframework` stub under `Frameworks/` (see [build.md](build.md#ghosttykit-stub-quake-terminal)) — it's gitignored.
3. Assemble `dist/OmniWM.app` (binaries + Info.plist + Resources — see [build.md](build.md#packaging--install-local)).
4. **Sign + install with the stable identity** so permissions don't reset on every rebuild:
   ```sh
   zsh scripts-local/sign-and-install.sh
   ```
   On first run per machine it creates a self-signed `OmniWM Local Signing` identity (stashed at
   `~/.config/omniwm/signing/`), signs, installs to `/Applications`, symlinks `omniwmctl`, and resets
   TCC once. Grant **Accessibility** + **Input Monitoring** to OmniWM that one time.
5. Re-run the same script after any rebuild — it reuses the identity, so the grants **persist** (no
   re-enabling). TCC anchors the grant to the cert's leaf hash, which is stable across rebuilds.

> Why this exists: ad-hoc signing (`codesign --sign -`) has no stable identity, so TCC keys the grant
> to the binary's cdhash, which changes every build → Accessibility + Input Monitoring get wiped on
> each install. The self-signed identity fixes that. Details + manual steps: [build.md](build.md#permissions-tcc).
