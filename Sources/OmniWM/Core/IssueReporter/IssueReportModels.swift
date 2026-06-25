// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

struct RewrittenIssue: Equatable, Sendable {
    var title: String
    var body: String
}

enum IssueAIAvailability: Equatable, Sendable {
    case available
    case unsupportedOS
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady

    var message: String? {
        switch self {
        case .available:
            nil
        case .unsupportedOS:
            "On-device AI requires macOS 26 or later. You can still write and submit your issue manually."
        case .deviceNotEligible:
            "On-device AI requires a Mac with Apple Silicon (M1 or later). You can still write and submit manually."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in System Settings to use AI rewriting. You can still write and submit manually."
        case .modelNotReady:
            "The on-device model is still downloading — try again shortly. You can still write and submit manually."
        }
    }
}

enum IssueReportError: LocalizedError, Equatable {
    case unavailable
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "On-device AI is unavailable on this Mac."
        case let .generationFailed(detail):
            detail
        }
    }
}

@MainActor
protocol IssueRewriting {
    var availability: IssueAIAvailability { get }
    func rewrite(_ freeform: String, hotkeyContext: String) async throws -> RewrittenIssue
}

@MainActor
enum IssueRewritingFactory {
    static func make() -> (engine: (any IssueRewriting)?, availability: IssueAIAvailability) {
        // ponytail: FoundationModels macro plugin absent on the fork's toolchain; gated out in
        // Package.swift unless OMNIWM_INCLUDE_FOUNDATIONMODELS=1. Drop the #if when that's the default.
        #if OMNIWM_FOUNDATION_MODELS
        if #available(macOS 26.0, *) {
            let engine = FoundationModelsIssueEngine()
            return (engine, engine.availability)
        }
        #endif
        return (nil, .unsupportedOS)
    }
}
