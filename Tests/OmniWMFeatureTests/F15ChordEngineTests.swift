import Carbon
@testable import OmniWM
import Testing

@Suite struct F15ChordEngineTests {
    private let f15 = UInt32(kVK_F15)
    private let escape = UInt32(kVK_Escape)
    private var hKey: UInt32 { KeySymbolMapper.keyCode(named: "H")! }
    private var qKey: UInt32 { KeySymbolMapper.keyCode(named: "Q")! }

    private func makeEngine() -> F15ChordEngine {
        let engine = F15ChordEngine()
        engine.configure(enabled: true, doubleTapSeconds: 0.3)
        return engine
    }

    @Test func holdF15ThenChordKeyRunsCommandAndSwallows() {
        let engine = makeEngine()
        _ = engine.handle(type: .keyDown, keyCode: f15, isRepeat: false, modifiers: 0, now: 1.0)
        let result = engine.handle(type: .keyDown, keyCode: hKey, isRepeat: false, modifiers: 0, now: 1.1)
        #expect(result == .init(action: .command(.focus(.left)), shouldSwallow: true))
    }

    @Test func shiftChordResolvesToMove() {
        let engine = makeEngine()
        _ = engine.handle(type: .keyDown, keyCode: f15, isRepeat: false, modifiers: 0, now: 1.0)
        let result = engine.handle(
            type: .keyDown, keyCode: hKey, isRepeat: false, modifiers: UInt32(shiftKey), now: 1.1
        )
        #expect(result.action == .command(.move(.left)))
    }

    @Test func doubleTapF15OpensPalette() {
        let engine = makeEngine()
        _ = engine.handle(type: .keyDown, keyCode: f15, isRepeat: false, modifiers: 0, now: 1.0)
        _ = engine.handle(type: .keyUp, keyCode: f15, isRepeat: false, modifiers: 0, now: 1.05)
        let result = engine.handle(type: .keyDown, keyCode: f15, isRepeat: false, modifiers: 0, now: 1.2)
        #expect(result == .init(action: .openPalette, shouldSwallow: true))
    }

    @Test func slowSecondTapDoesNotOpenPalette() {
        let engine = makeEngine()
        _ = engine.handle(type: .keyDown, keyCode: f15, isRepeat: false, modifiers: 0, now: 1.0)
        let result = engine.handle(type: .keyDown, keyCode: f15, isRepeat: false, modifiers: 0, now: 2.0)
        #expect(result.action == .none)
    }

    @Test func escapeWhileHeldCancelsLayer() {
        let engine = makeEngine()
        _ = engine.handle(type: .keyDown, keyCode: f15, isRepeat: false, modifiers: 0, now: 1.0)
        let esc = engine.handle(type: .keyDown, keyCode: escape, isRepeat: false, modifiers: 0, now: 1.1)
        #expect(esc == .swallowed)
        // After cancel, a chord key is no longer captured.
        let after = engine.handle(type: .keyDown, keyCode: hKey, isRepeat: false, modifiers: 0, now: 1.2)
        #expect(after == .ignored)
    }

    @Test func unmappedKeyWhileHeldPassesThrough() {
        let engine = makeEngine()
        _ = engine.handle(type: .keyDown, keyCode: f15, isRepeat: false, modifiers: 0, now: 1.0)
        let result = engine.handle(type: .keyDown, keyCode: qKey, isRepeat: false, modifiers: 0, now: 1.1)
        #expect(result == .ignored)
    }

    @Test func staleHoldStopsCapturingChords() {
        let engine = makeEngine()
        _ = engine.handle(type: .keyDown, keyCode: f15, isRepeat: false, modifiers: 0, now: 1.0)
        // > 3s with no activity: the hold is considered stale, so normal typing is not swallowed.
        let result = engine.handle(type: .keyDown, keyCode: hKey, isRepeat: false, modifiers: 0, now: 5.0)
        #expect(result == .ignored)
    }

    @Test func chordKeyWithoutF15HeldIsIgnored() {
        let engine = makeEngine()
        let result = engine.handle(type: .keyDown, keyCode: hKey, isRepeat: false, modifiers: 0, now: 1.0)
        #expect(result == .ignored)
    }
}
