import Carbon
@testable import OmniWM
import Testing

@Suite struct F15ConfigTests {
    @Test func defaultsResolveToCommands() {
        let map = F15Config.defaults.resolvedChords()
        let t = KeySymbolMapper.fromHumanReadable("T")!
        #expect(map[t] == .toggleColumnTabbed)
        #expect(map.count == F15Config.defaultChords.count)
    }

    @Test func missingChordsFallBackToDefaults() throws {
        let json = Data("{}".utf8)
        let config = try JSONDecoder().decode(F15Config.self, from: json)
        #expect(config == F15Config.defaults)
    }

    @Test func unknownKeyOrActionIsDropped() {
        let config = F15Config(chords: [
            F15ChordItem(key: "T", action: "toggleColumnTabbed"),
            F15ChordItem(key: "not-a-key", action: "move.down"),
            F15ChordItem(key: "J", action: "no.such.action")
        ])
        let map = config.resolvedChords()
        #expect(map.count == 1)
        #expect(map[KeySymbolMapper.fromHumanReadable("T")!] == .toggleColumnTabbed)
    }

    @Test func customChordOverridesEngine() {
        let engine = F15ChordEngine()
        let jKey = KeySymbolMapper.keyCode(named: "J")!
        engine.setChords(F15Config(chords: [
            F15ChordItem(key: "J", action: "toggleColumnTabbed")
        ]).resolvedChords())
        engine.configure(enabled: true, doubleTapSeconds: 0.3)
        _ = engine.handle(type: .keyDown, keyCode: UInt32(kVK_F15), isRepeat: false, modifiers: 0, now: 1.0)
        let result = engine.handle(type: .keyDown, keyCode: jKey, isRepeat: false, modifiers: 0, now: 1.1)
        #expect(result.action == .command(.toggleColumnTabbed))
    }
}
