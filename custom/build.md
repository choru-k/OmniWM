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

## FoundationModels issue engine (on-device AI rewrite)
Upstream's `Core/IssueReporter/FoundationModelsIssueEngine.swift` uses the `@Generable`/`@Guide`
macros from Apple's `FoundationModels` framework. That macro plugin (`FoundationModelsMacros`) ships
only with a full Apple-Intelligence Xcode toolchain — neither the swiftly 6.3.2 nor the CLT/Xcode
swift on this box can expand it, so the file fails to compile. `Package.swift` therefore **excludes
that one file by default**; `IssueRewritingFactory` falls back to `.unsupportedOS` (the AI rewrite is
just disabled, the rest of the issue reporter works). Opt back in on a toolchain that has the plugin:
```sh
OMNIWM_INCLUDE_FOUNDATIONMODELS=1 ~/.swiftly/bin/swiftly run swift build
```
(That env var also defines `OMNIWM_FOUNDATION_MODELS`, which re-enables the `#if`-gated factory branch.)

## macOS-15 SDK shims
The toolchain now targets `macosx26.0` (swiftly Swift 6.3.2), so the macOS-26 SDK is present.

- `Sources/OmniWM/UI/VisualEffectsCompatibility.swift` — **restored** to upstream's real Liquid Glass
  (`glassEffect`/`backgroundExtensionEffect`) behind `#available(macOS 26.0, *)`, with the macOS-15
  `ultraThinMaterial` fallbacks kept for older systems. (The macOS 26 NavigationSplitView still renders
  the settings sidebar flat on long/scrolling pages and floating on short ones — that's OS behavior,
  not these APIs.)
- `Sources/OmniWM/Core/Surface/SurfaceReconciler.swift` — still carries the `DesiredSurfaceScene.empty`
  → `nonisolated(unsafe) static let` shim (Sendable flagged on the 15.5 SDK). Harmless on 26; revert if
  it ever warns.

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
# Sign with the STABLE self-signed identity (see Permissions) so TCC grants survive rebuilds:
codesign --force --sign "OmniWM Local Signing" --entitlements OmniWM.entitlements dist/OmniWM.app/Contents/MacOS/omniwmctl
codesign --force --sign "OmniWM Local Signing" --entitlements OmniWM.entitlements dist/OmniWM.app/Contents/MacOS/OmniWM
codesign --force --sign "OmniWM Local Signing" --entitlements OmniWM.entitlements dist/OmniWM.app
ditto dist/OmniWM.app /Applications/OmniWM.app
ln -sf /Applications/OmniWM.app/Contents/MacOS/omniwmctl /opt/homebrew/bin/omniwmctl
```

## Permissions (TCC)
Grant **Accessibility** (tiling) + **Input Monitoring** (F15) to OmniWM.

**Stable signing identity (so grants survive rebuilds).** Ad-hoc (`--sign -`) signing has no stable
identity, so TCC keys the grant to the binary's cdhash — every rebuild wipes Accessibility +
Input Monitoring. The fix is a one-time self-signed code-signing cert; TCC then anchors the grant to
the cert (stable across rebuilds). The identity **`OmniWM Local Signing`** already lives in the login
keychain; its cert/key are stashed at `~/.config/omniwm/signing/` for re-import. To recreate it:
```sh
cd ~/.config/omniwm/signing   # or regenerate omniwm-cert.conf with CN="OmniWM Local Signing",
                              #   basicConstraints=critical,CA:false, extendedKeyUsage=critical,codeSigning
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout omniwm.key -out omniwm.crt -config omniwm-cert.conf
openssl pkcs12 -export -legacy -out omniwm.p12 -inkey omniwm.key -in omniwm.crt -passout pass:omniwm
security import omniwm.p12 -k ~/Library/Keychains/login.keychain-db -P omniwm -T /usr/bin/codesign
```
`security find-identity -p codesigning` lists it as `CSSMERR_TP_NOT_TRUSTED` — that's fine, `codesign`
signs with it anyway (it doesn't need to be a trusted anchor; TCC pins the leaf cert hash).

**One-time grant.** The first install under a new identity still needs a fresh grant — reset once,
relaunch, toggle Accessibility + Input Monitoring on. After that, rebuilds signed with the *same*
identity keep the grants:
```sh
tccutil reset Accessibility com.barut.OmniWM && tccutil reset ListenEvent com.barut.OmniWM
```
(Only needed when switching identities — not on ordinary rebuilds anymore.)
