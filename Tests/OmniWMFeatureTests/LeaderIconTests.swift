@testable import OmniWM
import Testing

@Suite struct LeaderIconTests {
    @Test func sfPrefixResolvesToSymbolName() {
        #expect(LeaderIcon.symbolName("sf:gearshape.fill") == "gearshape.fill")
        #expect(LeaderIcon.symbolName("sf:") == nil) // empty symbol → not a symbol
        #expect(LeaderIcon.symbolName("🚀") == nil) // emoji is not a symbol ref
    }

    @Test func autoSymbolReflectsItemKind() {
        #expect(LeaderIcon.autoSymbol(for: .init(key: "a", title: "G", menu: "sub")) == "folder")
        #expect(LeaderIcon.autoSymbol(for: .init(key: "a", title: "S", script: "echo hi")) == "terminal")
        #expect(LeaderIcon.autoSymbol(for: .init(key: "a", title: "A", app: "com.apple.Safari")) == "app")
        #expect(LeaderIcon.autoSymbol(for: .init(key: "a", title: "X", action: "focus.left")) == "bolt")
    }
}
