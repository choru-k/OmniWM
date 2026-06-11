import ApplicationServices
import CoreGraphics
import XCTest
@testable import OmniWM

final class EventIntakeReplayTests: XCTestCase {
    @MainActor
    private final class RecordingSink: EventIntakeSink {
        var received: [StampedIntakeEvent] = []

        func handleIntakeEvent(_ stamped: StampedIntakeEvent) {
            received.append(stamped)
        }
    }

    @MainActor
    func testIntakeStampsMonotonicallyAndPreservesOrder() {
        let intake = EventIntake()
        let sink = RecordingSink()
        intake.open(sink: sink)
        defer { intake.close() }

        intake.enqueue(.appActivated(pid: 1))
        intake.enqueue(.cgs(.frameChanged(windowId: 7)))
        intake.enqueue(.appDeactivated(pid: 1))
        intake.drainNow()
        intake.enqueue(.appHidden(pid: 1))
        intake.drainNow()

        XCTAssertEqual(sink.received.count, 4)
        let seqs = sink.received.map(\.seq)
        XCTAssertEqual(seqs, seqs.sorted())
        XCTAssertEqual(Set(seqs).count, seqs.count)
        guard case .appActivated = sink.received[0].event,
              case .cgs(.frameChanged) = sink.received[1].event,
              case .appDeactivated = sink.received[2].event,
              case .appHidden = sink.received[3].event
        else {
            return XCTFail("Events drained out of order: \(sink.received)")
        }
    }

    @MainActor
    func testCGSFrameEventsCoalescePerWindowAndClearOnDestroy() {
        let intake = EventIntake()
        let sink = RecordingSink()
        intake.open(sink: sink)
        defer { intake.close() }

        intake.enqueue(.cgs(.frameChanged(windowId: 7)))
        intake.enqueue(.cgs(.frameChanged(windowId: 7)))
        intake.enqueue(.cgs(.frameChanged(windowId: 8)))
        intake.enqueue(.cgs(.destroyed(windowId: 7, spaceId: 1)))
        intake.drainNow()

        let frames = sink.received.compactMap { stamped -> UInt32? in
            if case let .cgs(.frameChanged(windowId)) = stamped.event {
                return windowId
            }
            return nil
        }
        XCTAssertEqual(frames, [8])
        XCTAssertEqual(sink.received.count, 2)
    }

    @MainActor
    func testMouseMovedCoalescesToLatestLocationInPlace() {
        let intake = EventIntake()
        let sink = RecordingSink()
        intake.open(sink: sink)
        defer { intake.close() }

        intake.enqueue(.mouseMoved(location: CGPoint(x: 10, y: 10)))
        intake.enqueue(.appActivated(pid: 1))
        intake.enqueue(.mouseMoved(location: CGPoint(x: 20, y: 20)))
        intake.drainNow()

        XCTAssertEqual(sink.received.count, 2)
        guard case let .mouseMoved(location) = sink.received[0].event else {
            return XCTFail("Expected coalesced mouseMoved first: \(sink.received)")
        }
        XCTAssertEqual(location, CGPoint(x: 20, y: 20))
        guard case .appActivated = sink.received[1].event else {
            return XCTFail("Expected appActivated second: \(sink.received)")
        }
    }

    @MainActor
    func testScrollAccumulatesSameAxisAndSplitsOnFlip() {
        let intake = EventIntake()
        let sink = RecordingSink()
        intake.open(sink: sink)
        defer { intake.close() }

        intake.enqueue(.mouseScroll(scroll(deltaY: 5)))
        intake.enqueue(.mouseScroll(scroll(deltaY: 3)))
        intake.enqueue(.mouseScroll(scroll(deltaY: -2)))
        intake.drainNow()

        let deltas = sink.received.compactMap { stamped -> CGFloat? in
            if case let .mouseScroll(payload) = stamped.event {
                return payload.deltaY
            }
            return nil
        }
        XCTAssertEqual(deltas, [8, -2])
    }

    private func scroll(deltaY: CGFloat) -> MouseScrollIntake {
        MouseScrollIntake(
            location: .zero,
            deltaX: 0,
            deltaY: deltaY,
            momentumPhase: 0,
            phase: 0,
            modifiersRawValue: 0
        )
    }

    private final class FakeWindowSystem {
        var focusedWindowIdByPid: [pid_t: Int] = [:]
        var staleFocusedWindowIds: [Int] = []
    }

    @MainActor
    private struct ReplayScenario {
        let controller: WMController
        let system: FakeWindowSystem
        let tokenA: WindowToken
        let tokenB: WindowToken
        let workspaceId: WorkspaceDescriptor.ID

        func drainToQuiescence() {
            var iterations = 0
            while controller.eventIntake.hasPendingEvents, iterations < 64 {
                controller.eventIntake.drainNow()
                iterations += 1
            }
        }

        func committedState() -> String {
            let focused = controller.workspaceManager.focusedToken?.windowId ?? -1
            let intents = controller.intentLedger.entries
                .filter { $0.kind.isFocusWindow }
                .map { intent in
                    "\(intent.kind.focusTargetToken?.windowId ?? -1):\(intent.phase)"
                }
                .joined(separator: ",")
            return "focused=\(focused) intents=[\(intents)]"
        }

        func tearDown() {
            controller.deadlineWheel.stop()
            controller.eventIntake.close()
        }
    }

    @MainActor
    func testStaleActivationFactsCannotCancelNewerFocusIntent() throws {
        let pid: pid_t = 100
        let staleFacts = IntakeEvent.activationFactsResolved(
            ActivationFacts(
                pid: pid,
                source: .focusedWindowChanged,
                origin: .external,
                requestedAtSeq: 0,
                focusedWindow: FocusedWindowFact(
                    axRef: AXWindowRef(element: AXUIElementCreateApplication(pid), windowId: 42),
                    isFullscreen: false
                )
            )
        )
        let observationStream: [IntakeEvent] = [
            .cgs(.frontAppChanged(pid: pid)),
            .axFocusedWindowChanged(pid: pid)
        ]

        var outcomes: [String] = []
        for events in Self.interleavings([staleFacts], observationStream) {
            let scenario = try makeScenario(pid: pid)
            for event in events {
                scenario.controller.eventIntake.enqueue(event)
            }
            scenario.drainToQuiescence()
            XCTAssertEqual(scenario.controller.workspaceManager.focusedToken, scenario.tokenB)
            outcomes.append(scenario.committedState())
            scenario.tearDown()
        }

        XCTAssertEqual(Set(outcomes).count, 1, "Interleavings diverged: \(outcomes)")
    }

    @MainActor
    func testStaleFocusEchoOfConfirmedIntentDoesNotPreemptNewerIntent() throws {
        let pid: pid_t = 100
        let echoStream: [IntakeEvent] = [
            .axFocusedWindowChanged(pid: pid),
            .axFocusedWindowChanged(pid: pid)
        ]
        let hintStream: [IntakeEvent] = [
            .cgs(.frontAppChanged(pid: pid))
        ]

        var outcomes: [String] = []
        for events in Self.interleavings(echoStream, hintStream) {
            let scenario = try makeScenario(pid: pid)
            scenario.system.staleFocusedWindowIds = [scenario.tokenA.windowId]
            for event in events {
                scenario.controller.eventIntake.enqueue(event)
            }
            scenario.drainToQuiescence()
            XCTAssertEqual(scenario.controller.workspaceManager.focusedToken, scenario.tokenB)
            let newestIntentForB = scenario.controller.intentLedger.entries
                .last { $0.kind.focusTargetToken == scenario.tokenB }
            XCTAssertEqual(newestIntentForB?.phase, .confirmed)
            outcomes.append(scenario.committedState())
            scenario.tearDown()
        }

        XCTAssertEqual(Set(outcomes).count, 1, "Interleavings diverged: \(outcomes)")
    }

    @MainActor
    private func makeScenario(pid: pid_t) throws -> ReplayScenario {
        let system = FakeWindowSystem()
        let controller = WMController(
            settings: Self.settingsStore(),
            windowFocusOperations: WindowFocusOperations(
                activateApp: { _ in },
                focusSpecificWindow: { pid, windowId, _ in
                    system.focusedWindowIdByPid[pid] = Int(windowId)
                },
                raiseWindow: { _ in }
            )
        )
        let workspaceId = try XCTUnwrap(controller.workspaceManager.workspaceId(for: "1", createIfMissing: true))
        _ = controller.workspaceManager.focusWorkspace(named: "1")
        controller.niriLayoutHandler.enableNiriLayout()

        let tokenA = try addNiriWindow(controller, pid: pid, windowId: 42, workspaceId: workspaceId)
        let tokenB = try addNiriWindow(controller, pid: pid, windowId: 43, workspaceId: workspaceId)

        controller.factResolver.factProvider = { pid in
            let windowId: Int?
            if system.staleFocusedWindowIds.isEmpty {
                windowId = system.focusedWindowIdByPid[pid]
            } else {
                windowId = system.staleFocusedWindowIds.removeFirst()
            }
            guard let windowId else { return nil }
            return FocusedWindowFact(
                axRef: AXWindowRef(element: AXUIElementCreateApplication(pid), windowId: windowId),
                isFullscreen: false
            )
        }
        controller.hasStartedServices = true
        controller.eventIntake.open(sink: controller.eventInterpreter)

        let scenario = ReplayScenario(
            controller: controller,
            system: system,
            tokenA: tokenA,
            tokenB: tokenB,
            workspaceId: workspaceId
        )

        controller.focusWindow(tokenA)
        controller.eventIntake.enqueue(.axFocusedWindowChanged(pid: pid))
        scenario.drainToQuiescence()
        XCTAssertEqual(controller.workspaceManager.focusedToken, tokenA)

        controller.focusWindow(tokenB)
        return scenario
    }

    @MainActor
    private func addNiriWindow(
        _ controller: WMController,
        pid: pid_t,
        windowId: Int,
        workspaceId: WorkspaceDescriptor.ID
    ) throws -> WindowToken {
        let token = controller.workspaceManager.addWindow(
            AXWindowRef(element: AXUIElementCreateApplication(pid), windowId: windowId),
            pid: pid,
            windowId: windowId,
            to: workspaceId
        )
        let node = try XCTUnwrap(
            controller.niriEngine?.addWindow(
                token: token,
                to: workspaceId,
                afterSelection: nil
            )
        )
        let frame = CGRect(x: 0, y: 0, width: 200, height: 150)
        node.frame = frame
        node.renderedFrame = frame
        return token
    }

    private static func interleavings(_ a: [IntakeEvent], _ b: [IntakeEvent]) -> [[IntakeEvent]] {
        if a.isEmpty { return [b] }
        if b.isEmpty { return [a] }
        var result: [[IntakeEvent]] = []
        for merged in interleavings(Array(a.dropFirst()), b) {
            result.append([a[0]] + merged)
        }
        for merged in interleavings(a, Array(b.dropFirst())) {
            result.append([b[0]] + merged)
        }
        return result
    }

    @MainActor
    private static func settingsStore() -> SettingsStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMReplayTests-\(UUID().uuidString)", isDirectory: true)
        return SettingsStore(
            persistence: SettingsFilePersistence(
                directory: root.appendingPathComponent("config", isDirectory: true),
                startWatching: false,
                deferSaves: false
            ),
            runtimeState: RuntimeStateStore(
                directory: root.appendingPathComponent("state", isDirectory: true),
                deferSaves: false
            ),
            autosaveEnabled: false
        )
    }
}
