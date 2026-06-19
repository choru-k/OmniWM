# Building & running this fork

## Toolchain
Needs **Swift 6.3.2** (`.swift-version`); the machine default (CLT 6.1.x) can't build it.
```sh
~/.swiftly/bin/swiftly run swift build          # debug
~/.swiftly/bin/swiftly run swift build -c release
```

## GhosttyKit stub (quake terminal)
Upstream's `OmniWM` lib hard-depends on the `GhosttyKit` binary target (`import GhosttyKit`, links
`-lghostty`), but the clone ships no `Frameworks/`. This fork builds against a **stub** xcframework at
`Frameworks/GhosttyKit.xcframework/macos-arm64_x86_64/` (gitignored — bring your own, like upstream):
- `Headers/ghostty.h` — the real header from ghostty-org/ghostty `v1.3.1`.
- `Headers/module.modulemap` — `module GhosttyKit { header "ghostty.h" export * }`.
- `libghostty.a` — a **no-op** archive: every `ghostty_*` symbol asm-aliased to a stub returning 0.
- `Info.plist` — single arm64 slice.

The quake terminal is therefore **non-functional**; everything else works. To restore it, build real
Ghostty's universal `libghostty.a` and drop it in (see upstream `Scripts/ghostty-preflight.sh`).

## macOS-15 SDK shims
This machine has the 15.5 SDK only. Two upstream spots use macOS-26 APIs and were patched (marked `// ponytail:`):
- `Sources/OmniWM/UI/VisualEffectsCompatibility.swift` — Liquid Glass (`glassEffect`/`backgroundExtensionEffect`) replaced with the macOS-15 fallbacks (same `omniGlassEffect`/`omniBackgroundExtensionEffect` signatures).
- `Sources/OmniWM/Core/Surface/SurfaceReconciler.swift` — `DesiredSurfaceScene.empty` → `nonisolated(unsafe) static let` (Sendable flagged on the 15.5 SDK only).

Revert both when building against the Xcode 26 SDK.

## Tests
No active Xcode here → XCTest won't resolve → upstream's `OmniWMTests` won't compile. `Package.swift`
gates it behind `OMNIWM_INCLUDE_XCTEST=1` (default off). Fork features use swift-testing in
`Tests/OmniWMFeatureTests`, which runs under swiftly alone:
```sh
~/.swiftly/bin/swiftly run swift test --filter OmniWMFeatureTests   # 30 tests
```

## Packaging & install (local)
`Scripts/package-app.sh` is unusable here (its ghostty-preflight rejects the stub's SHA and forces a
universal build). Hand-assemble an arm64, ad-hoc-signed app instead:
```sh
swiftly run swift build -c release
# assemble dist/OmniWM.app/Contents/{MacOS/{OmniWM,omniwmctl},Info.plist,Resources/{AppIcon.icns,OmniWM_OmniWM.bundle}}
codesign --force --sign - --entitlements OmniWM.entitlements dist/OmniWM.app/Contents/MacOS/OmniWM
codesign --force --sign - --entitlements OmniWM.entitlements dist/OmniWM.app
ditto dist/OmniWM.app /Applications/OmniWM.app
ln -sf /Applications/OmniWM.app/Contents/MacOS/omniwmctl /opt/homebrew/bin/omniwmctl
```

## Permissions (TCC)
Grant **Accessibility** (tiling) + **Input Monitoring** (F15) to OmniWM. Ad-hoc signing means the
code identity changes on every rebuild, which **resets the grants** — after a rebuild, run
`tccutil reset Accessibility com.barut.OmniWM && tccutil reset ListenEvent com.barut.OmniWM`,
relaunch, and re-toggle. For permanent grants, sign with a stable self-signed identity instead of `--sign -`.
