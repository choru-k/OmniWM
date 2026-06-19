@testable import OmniWM
import Testing

@Suite struct NiriTabCycleTests {
    @Test func wrapsForwardPastLastToFirst() {
        #expect(NiriTabCycle.wrappedIndex(current: 2, step: 1, count: 3) == 0)
    }

    @Test func wrapsBackwardPastFirstToLast() {
        #expect(NiriTabCycle.wrappedIndex(current: 0, step: -1, count: 3) == 2)
    }

    @Test func movesNormallyInRange() {
        #expect(NiriTabCycle.wrappedIndex(current: 0, step: 1, count: 3) == 1)
        #expect(NiriTabCycle.wrappedIndex(current: 2, step: -1, count: 3) == 1)
    }

    @Test func singleTabHasNothingToCycle() {
        #expect(NiriTabCycle.wrappedIndex(current: 0, step: 1, count: 1) == nil)
        #expect(NiriTabCycle.wrappedIndex(current: 0, step: -1, count: 0) == nil)
    }
}
