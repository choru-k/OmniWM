import Carbon
import Foundation

/// Tracks whether F15 is being held, auto-clearing if a keyUp is missed (stale).
/// Ported from madang's ActivityTrackedKeyHold.
private struct ActivityTrackedKeyHold {
    let staleTimeout: TimeInterval
    private(set) var isHeld = false
    private var lastActivityAt: TimeInterval?

    init(staleTimeout: TimeInterval) {
        self.staleTimeout = staleTimeout
    }

    mutating func setHeld(_ held: Bool, at now: TimeInterval) {
        isHeld = held
        lastActivityAt = held ? now : nil
    }

    mutating func noteActivity(at now: TimeInterval) {
        guard isHeld else { return }
        lastActivityAt = now
    }

    mutating func clear() {
        isHeld = false
        lastActivityAt = nil
    }

    mutating func isActive(at now: TimeInterval) -> Bool {
        guard isHeld, let lastActivityAt, now - lastActivityAt <= staleTimeout else {
            clear()
            return false
        }
        return true
    }
}

/// Pure F15 chord state machine: hold F15 + key → command; double-tap F15 → open palette.
/// F15 is not a macOS modifier, so this is driven by a CGEvent tap (see `F15EventTap`).
/// No AppKit, no I/O — unit-testable.
final class F15ChordEngine {
    enum Action: Equatable {
        case none
        case command(HotkeyCommand)
        case openPalette
    }

    struct Result: Equatable {
        let action: Action
        let shouldSwallow: Bool

        static let ignored = Result(action: .none, shouldSwallow: false)
        static let swallowed = Result(action: .none, shouldSwallow: true)
    }

    private(set) var isEnabled = false
    private var doubleTapSeconds: TimeInterval = 0.3
    private var chords: [KeyBinding: HotkeyCommand] = F15ChordEngine.defaultChords
    private var hold = ActivityTrackedKeyHold(staleTimeout: 3.0)
    private var lastF15TapTime: TimeInterval?

    func configure(enabled: Bool, doubleTapSeconds: Double) {
        isEnabled = enabled
        self.doubleTapSeconds = max(0.05, doubleTapSeconds)
        reset()
    }

    /// Override the chord map (from `~/.config/omniwm/f15.json`). Empty falls back to defaults.
    func setChords(_ chords: [KeyBinding: HotkeyCommand]) {
        self.chords = chords.isEmpty ? F15ChordEngine.defaultChords : chords
    }

    func reset() {
        hold.clear()
        lastF15TapTime = nil
    }

    /// `modifiers` is a Carbon modifier mask (cmdKey/optionKey/controlKey/shiftKey), matching `KeyBinding`.
    func handle(
        type: CGEventType,
        keyCode: UInt32,
        isRepeat: Bool,
        modifiers: UInt32,
        now: TimeInterval
    ) -> Result {
        switch type {
        case .keyDown:
            if keyCode == Self.f15KeyCode {
                return handleF15KeyDown(isRepeat: isRepeat, now: now)
            }
            guard hold.isActive(at: now) else { return .ignored }
            hold.noteActivity(at: now)
            if keyCode == UInt32(kVK_Escape), modifiers == 0 {
                hold.clear()
                return .swallowed
            }
            guard let command = chords[KeyBinding(keyCode: keyCode, modifiers: modifiers)] else {
                return .ignored
            }
            return Result(action: .command(command), shouldSwallow: true)

        case .keyUp:
            if keyCode == Self.f15KeyCode {
                hold.clear()
                return .swallowed
            }
            let active = hold.isActive(at: now)
            if active { hold.noteActivity(at: now) }
            let swallow = active && chords[KeyBinding(keyCode: keyCode, modifiers: modifiers)] != nil
            return Result(action: .none, shouldSwallow: swallow)

        default:
            return .ignored
        }
    }

    private func handleF15KeyDown(isRepeat: Bool, now: TimeInterval) -> Result {
        guard !isRepeat else {
            hold.setHeld(true, at: now)
            return .swallowed
        }
        if let lastF15TapTime, now - lastF15TapTime <= doubleTapSeconds {
            self.lastF15TapTime = nil
            hold.clear()
            return Result(action: .openPalette, shouldSwallow: true)
        }
        lastF15TapTime = now
        hold.setHeld(true, at: now)
        return .swallowed
    }

    private static let f15KeyCode = UInt32(kVK_F15)

    // Built-in defaults; overridable per-user via ~/.config/omniwm/f15.json (see F15Config).
    static let defaultChords: [KeyBinding: HotkeyCommand] = F15Config.defaults.resolvedChords()
}
