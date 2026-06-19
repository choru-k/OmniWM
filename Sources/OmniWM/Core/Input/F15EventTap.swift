import Carbon
import CoreGraphics
import Foundation

/// Installs a CGEvent tap that observes F15 key events and drives `F15ChordEngine`.
/// F15 can't be a Carbon hotkey (it isn't a modifier), so this sits alongside `HotkeyCenter`.
/// Requires the Input Monitoring permission; gracefully no-ops without it.
@MainActor
final class F15EventTap {
    var onCommand: ((HotkeyCommand) -> Void)?

    private let engine = F15ChordEngine()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var didRequestInputMonitoring = false
    private(set) var statusDescription = "not configured"

    func configure(
        enabled: Bool,
        doubleTapSeconds: Double,
        chords: [KeyBinding: HotkeyCommand] = F15ChordEngine.defaultChords
    ) {
        engine.setChords(chords)
        engine.configure(enabled: enabled, doubleTapSeconds: doubleTapSeconds)
        reinstall()
    }

    func remove() {
        engine.reset()
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func reinstall() {
        remove()
        guard engine.isEnabled else {
            statusDescription = "F15 disabled"
            return
        }
        guard CGPreflightListenEventAccess() else {
            statusDescription = "F15 needs Input Monitoring"
            // Prompt once per session when the user has opted in.
            if !didRequestInputMonitoring {
                didRequestInputMonitoring = true
                _ = CGRequestListenEventAccess()
            }
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            statusDescription = "F15 tap install failed"
            return
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            statusDescription = "F15 runloop install failed"
            return
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        statusDescription = "F15 ready"
    }

    private enum TapDecision {
        case passThrough
        case swallow
    }

    /// Runs on the MainActor with only Sendable primitives (no `CGEvent`), so the C callback
    /// can read the event fields in its nonisolated context and hand them across cleanly.
    private func process(typeRaw: UInt32, keyCode: UInt32, isRepeat: Bool, modifiers: UInt32) -> TapDecision {
        let type = CGEventType(rawValue: typeRaw)
        // macOS disables a tap that is too slow or interrupted; re-enable and pass through.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return .passThrough
        }
        guard let type, type == .keyDown || type == .keyUp else { return .passThrough }
        let result = engine.handle(
            type: type,
            keyCode: keyCode,
            isRepeat: isRepeat,
            modifiers: modifiers,
            now: ProcessInfo.processInfo.systemUptime
        )
        switch result.action {
        case .none:
            break
        case let .command(command):
            let onCommand = onCommand
            DispatchQueue.main.async { onCommand?(command) }
        case .openPalette:
            // Double-tap F15 opens the Leader tab (which itself falls back to the normal palette
            // when leader.json sets doubleTapOpensLeader = false).
            let onCommand = onCommand
            DispatchQueue.main.async { onCommand?(.openLeader) }
        }
        return result.shouldSwallow ? .swallow : .passThrough
    }

    private static func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
        if flags.contains(.maskControl) { modifiers |= UInt32(controlKey) }
        if flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        // Read event fields here (nonisolated) and pass only Sendable primitives across — CGEvent
        // is not Sendable, so it must not be captured into the MainActor closure.
        let typeRaw = type.rawValue
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let modifiers = carbonModifiers(from: event.flags)
        let tap = Unmanaged<F15EventTap>.fromOpaque(userInfo).takeUnretainedValue()
        let decision = MainActor.assumeIsolated {
            tap.process(typeRaw: typeRaw, keyCode: keyCode, isRepeat: isRepeat, modifiers: modifiers)
        }
        switch decision {
        case .swallow:
            return nil
        case .passThrough:
            return Unmanaged.passUnretained(event)
        }
    }
}
