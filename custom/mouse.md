# Mouse resize (trackpad-friendly)

Upstream resizes a window only with **right-button + modifier drag**. On a trackpad a "right click"
is a two-finger gesture that collides with scrolling and secondary-click, so the fork also accepts
**left-button + modifier drag** for resize.

## Behavior
- **`<modifier>` + drag** (left *or* right button) resizes the window under the cursor. The modifier
  is `mouseResizeModifierKey` in settings.toml (default **Option**).
- While a left-button resize is in progress, the left mouse down/drag/up events are **swallowed** so
  the app underneath doesn't see them (no text selection, no `⌃`-click context menu mid-resize) —
  mirroring how the right-button path already worked.

## Config
```toml
[general]
mouseResizeModifierKey = "option"   # option | command | control | shift
```

## Implementation
- `Sources/OmniWM/Core/Controller/MouseEventHandler.swift` — the resize trigger now matches
  `button == .right || button == .left`; `shouldSuppressLeftMouseEvent` suppresses left
  down/drag/up while `isResizing` on the left button.
