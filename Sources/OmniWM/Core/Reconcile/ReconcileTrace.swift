// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

struct ReconcileTraceRecord: Equatable {
    let sequence: UInt64
    let timestamp: Date
    let event: WMEvent
    let normalizedEvent: WMEvent
    let plan: ActionPlan
    let snapshot: ReconcileSnapshot
    let invariantViolations: [ReconcileInvariantViolation]
}

@MainActor
final class ReconcileTraceRecorder {
    private static let defaultLimit = 256
    // OMNIWM_DEBUG_RECONCILE_TRACE=1 streams every reconcile record to stderr live
    // (the queryable buffer is only the last `limit`). Run OmniWM from a terminal to see it.
    private static let liveStreamEnabled =
        ProcessInfo.processInfo.environment["OMNIWM_DEBUG_RECONCILE_TRACE"] == "1"

    private var nextSequence: UInt64 = 1
    private var records: RingBuffer<ReconcileTraceRecord>

    init(limit: Int = defaultLimit) {
        records = RingBuffer(capacity: limit)
    }

    func append(
        event: WMEvent,
        normalizedEvent: WMEvent? = nil,
        plan: ActionPlan,
        snapshot: ReconcileSnapshot,
        invariantViolations: [ReconcileInvariantViolation] = [],
        timestamp: Date = Date()
    ) {
        let record = ReconcileTraceRecord(
            sequence: nextSequence,
            timestamp: timestamp,
            event: event,
            normalizedEvent: normalizedEvent ?? event,
            plan: plan,
            snapshot: snapshot,
            invariantViolations: invariantViolations
        )
        nextSequence += 1
        records.append(record)

        if Self.liveStreamEnabled {
            fputs("[Reconcile] \(ReconcileDebugDump.line(record))\n", stderr)
        }
    }

    func append(transaction: ReconcileTxn) {
        append(
            event: transaction.event,
            normalizedEvent: transaction.normalizedEvent,
            plan: transaction.plan,
            snapshot: transaction.snapshot,
            invariantViolations: transaction.invariantViolations,
            timestamp: transaction.timestamp
        )
    }

    func snapshot() -> [ReconcileTraceRecord] {
        records.snapshot()
    }

    func reset() {
        records.removeAll()
        nextSequence = 1
    }
}
