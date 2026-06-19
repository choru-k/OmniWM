# Debugging focus & reconcile issues

How to capture what OmniWM is doing when focus/layout misbehaves, plus a log of issues we've
already chased so they're recognizable next time.

## Diagnostic toolkit

### Live stderr traces (run from a terminal)
The app only prints these when launched from a terminal (stderr isn't visible under a normal
`open`). Quit the running copy first; grants persist (same signing identity), so this is safe:

```sh
osascript -e 'quit app "OmniWM"'
OMNIWM_DEBUG_RECONCILE_TRACE=1 OMNIWM_DEBUG_NIRI_CREATE_FOCUS=1 \
  /Applications/OmniWM.app/Contents/MacOS/OmniWM 2>&1 | tee ~/omniwm-trace.log
```

| Env var | Stream | Shows |
|---------|--------|-------|
| `OMNIWM_DEBUG_RECONCILE_TRACE=1` | `[Reconcile] …` | **every** state-machine transaction live (the queryable buffer is only the last 256): `user_command`, `selection_changed`, `viewport_committed`, `managed_focus_requested/confirmed`, `focus_lease_changed`, `managed_replacement_metadata_changed`, `hidden_state_changed`, plus `plan=…` / `violations=…` |
| `OMNIWM_DEBUG_NIRI_CREATE_FOCUS=1` | `[NiriCreateFocus] …` | the focus pipeline: `pending_focus_started`, `activation_source_observed`, `activation_deferred`, `focus_confirmed` |
| `OMNIWM_DEBUG_MANAGED_REPLACEMENT=1` | `[ManagedReplacement] …` | window create/destroy replacement correlation |

### Query / subscribe (no relaunch needed)
```sh
omniwmctl query focused-window           # who OmniWM thinks is focused
omniwmctl query reconcile-debug          # snapshot + last 50 trace records + invariant status
omniwmctl subscribe focus                # stream focus changes as they happen
```

### WM-focus vs macOS-key divergence
`scripts-local/focus-desync-watch.sh` polls OmniWM's focused window against the real macOS key app
every 0.4s and logs only divergences to `~/omniwm-focus-debug.log`. Catches "screen shows X but
keys go to Y" — but it compares **bundle ids (apps)**, so it's blind to a *same-app, different-window*
desync. (It previously mis-parsed `lsappinfo` and logged a false DESYNC on every poll — fixed to use
`awk -F'"'`.)

## Known issues (resolved)

### Focus silently dropped after F15+h/l navigation (random)
**Symptom:** you navigate with the chord; the target window scrolls into view (screen looks right)
but keyboard focus stays on the **old** window. Random, *not* tied to press speed; worse when a busy
app (e.g. a terminal) is in the strip.

**Root cause:** focusing on h/l is deferred until after relayout via
`NiriLayoutHandler.requestSelectedWindowFocusAfterLayout`, whose post-layout action was **seq-gated**
on `[.workspace, .layout, .focus]`. A terminal rewrites its **title** constantly as commands run;
each update fires `managed_replacement_metadata_changed`, which bumps exactly those domains
(`WorkspaceManager.noteInvalidation`). That made the pending focus action look stale, so it was
dropped — the viewport had already scrolled, but `focusWindow()` never ran. `focus_remembered`
(fired during the same navigation) also bumps `.focus`, so the path was fragile even without the
terminal storm.

**Trace signature:** a navigation that shows `selection_changed` + `viewport_committed` but **no
following `managed_focus_requested`** — `focused=` never changes. A burst of
`managed_replacement_metadata_changed` for one token right after the navigation is the tell.

**Fix:** the post-layout focus action now uses **empty invalidation domains** (`postLayoutDomains: []`),
so it always runs after layout. Safe because the action re-reads the live selection and re-validates
the workspace at execution time — it was never correct to gate it on layout/title churn.
(`Sources/OmniWM/Core/Controller/NiriLayoutHandler.swift`.)

### Stale native-activation can steal focus (minor)
A late, unsolicited `workspaceDidActivateApplication` (e.g. a terminal self-activating seconds after
you moved away) is followed by OmniWM and can yank focus. Guarded in
`AXEventHandler.handleAppActivation` via `isStaleSupersededNativeActivation`: a native echo for a
different app than the one we fronted within the last 0.4s is treated as a stale self-activation and
ignored. Separate from the focus-drop bug above.
