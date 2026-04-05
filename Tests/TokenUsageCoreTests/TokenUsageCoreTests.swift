import Foundation
import XCTest
@testable import TokenUsageCore

final class TokenUsageCoreTests: XCTestCase {
    func testCodexSessionsUseFinalTokenSnapshotAndParseReasoningEffort() throws {
        try withTemporaryDirectory { root in
            let codexRoot = root.appendingPathComponent(".codex", isDirectory: true)
            let sessionsDirectory = codexRoot
                .appendingPathComponent("sessions", isDirectory: true)
                .appendingPathComponent("2026", isDirectory: true)
                .appendingPathComponent("04", isDirectory: true)
                .appendingPathComponent("04", isDirectory: true)

            try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

            let fileURL = sessionsDirectory.appendingPathComponent("rollout-2026-04-04T13-33-30-test.jsonl")
            try codexFixture.write(to: fileURL, atomically: true, encoding: .utf8)

            let sessions = try CodexSessionParser().parseSessions(at: codexRoot)

            XCTAssertEqual(sessions.count, 1)
            XCTAssertEqual(sessions[0].provider, .codex)
            XCTAssertEqual(sessions[0].surface, .vscode)
            XCTAssertEqual(sessions[0].tokens.totalTokens, 2_205)
            XCTAssertEqual(sessions[0].tokens.inputTokens, 1_900)
            XCTAssertEqual(sessions[0].tokens.cachedInputTokens, 200)
            XCTAssertEqual(sessions[0].projectPath, "/Users/mac/Vova/Projects/tokens-widget")
            XCTAssertEqual(sessions[0].reasoningEffort, "xhigh")
            XCTAssertEqual(sessions[0].model, "gpt-5.4")
        }
    }

    func testClaudeSessionsSumAssistantUsageAcrossMessagesAndParseCacheMetadata() throws {
        try withTemporaryDirectory { root in
            let claudeRoot = root.appendingPathComponent(".claude", isDirectory: true)
            let projectDirectory = claudeRoot
                .appendingPathComponent("projects", isDirectory: true)
                .appendingPathComponent("-Users-mac-Vova-Projects-tokens-widget", isDirectory: true)

            try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

            let fileURL = projectDirectory.appendingPathComponent("session-1.jsonl")
            try claudeFixture.write(to: fileURL, atomically: true, encoding: .utf8)

            let sessions = try ClaudeSessionParser().parseSessions(at: claudeRoot)

            XCTAssertEqual(sessions.count, 1)
            XCTAssertEqual(sessions[0].provider, .claudeCode)
            XCTAssertEqual(sessions[0].surface, .cli)
            XCTAssertEqual(sessions[0].tokens.inputTokens, 78)
            XCTAssertEqual(sessions[0].tokens.outputTokens, 22)
            XCTAssertEqual(sessions[0].tokens.cachedInputTokens, 15)
            XCTAssertEqual(sessions[0].tokens.cacheReadTokens, 5)
            XCTAssertEqual(sessions[0].tokens.cacheCreationTokens, 10)
            XCTAssertEqual(sessions[0].tokens.cacheCreation5mTokens, 0)
            XCTAssertEqual(sessions[0].tokens.cacheCreation1hTokens, 10)
            XCTAssertEqual(sessions[0].tokens.totalTokens, 115)
            XCTAssertEqual(sessions[0].model, "claude-sonnet-4-6")
            XCTAssertEqual(sessions[0].speed, "standard")
            XCTAssertEqual(sessions[0].serviceTier, "standard")
        }
    }

    func testClaudeVSCodeSessionsMapToVSCodeSurface() throws {
        try withTemporaryDirectory { root in
            let claudeRoot = root.appendingPathComponent(".claude", isDirectory: true)
            let projectDirectory = claudeRoot
                .appendingPathComponent("projects", isDirectory: true)
                .appendingPathComponent("-Users-mac-Vova-Projects-tokens-widget", isDirectory: true)

            try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

            let fileURL = projectDirectory.appendingPathComponent("session-vscode.jsonl")
            try claudeVSCodeFixture.write(to: fileURL, atomically: true, encoding: .utf8)

            let sessions = try ClaudeSessionParser().parseSessions(at: claudeRoot)

            XCTAssertEqual(sessions.count, 1)
            XCTAssertEqual(sessions[0].surface, .vscode)
            XCTAssertEqual(sessions[0].rawSurface, "claude-vscode")
            XCTAssertEqual(sessions[0].tokens.totalTokens, 80)
        }
    }

    func testCodexCostEstimatorPricesInputCachedOutputAndReasoning() throws {
        let session = UsageSession(
            id: "codex-priced",
            provider: .codex,
            surface: .vscode,
            model: "gpt-5.4",
            startedAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            tokens: TokenBreakdown(
                inputTokens: 1_900,
                outputTokens: 255,
                cachedInputTokens: 200,
                reasoningTokens: 50,
                totalTokens: 2_205
            ),
            reasoningEffort: "high"
        )

        let estimate = UsageCostEstimator().estimate(for: session)
        let breakdown = try XCTUnwrap(estimate.breakdown)

        XCTAssertEqual(breakdown.inputCost, decimal("0.00425"))
        XCTAssertEqual(breakdown.cachedInputCost, decimal("0.00005"))
        XCTAssertEqual(breakdown.outputCost, decimal("0.003825"))
        XCTAssertEqual(breakdown.reasoningCost, decimal("0.00075"))
        XCTAssertEqual(breakdown.totalCost, decimal("0.008875"))
        XCTAssertTrue(estimate.notes.contains("fast_mode_not_detected"))
    }

    func testCodexCostEstimatorLeavesUnsupportedModelsUnpriced() {
        let session = UsageSession(
            id: "codex-unpriced",
            provider: .codex,
            surface: .vscode,
            model: "gpt-unknown",
            startedAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            tokens: TokenBreakdown(inputTokens: 100, outputTokens: 10, totalTokens: 110)
        )

        let estimate = UsageCostEstimator().estimate(for: session)

        XCTAssertNil(estimate.breakdown)
        XCTAssertEqual(estimate.notes, ["unsupported_model_unpriced"])
    }

    func testClaudeCostEstimatorPricesReadAndWriteCacheSeparately() throws {
        let session = UsageSession(
            id: "claude-priced",
            provider: .claudeCode,
            surface: .cli,
            model: "claude-sonnet-4-6",
            startedAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            tokens: TokenBreakdown(
                inputTokens: 78,
                outputTokens: 22,
                cachedInputTokens: 15,
                totalTokens: 115,
                cacheReadTokens: 5,
                cacheCreationTokens: 10,
                cacheCreation5mTokens: 0,
                cacheCreation1hTokens: 10
            ),
            speed: "standard",
            serviceTier: "standard"
        )

        let estimate = UsageCostEstimator().estimate(for: session)
        let breakdown = try XCTUnwrap(estimate.breakdown)

        XCTAssertEqual(breakdown.inputCost, decimal("0.000234"))
        XCTAssertEqual(breakdown.cachedInputCost, decimal("0.0000615"))
        XCTAssertEqual(breakdown.outputCost, decimal("0.00033"))
        XCTAssertEqual(breakdown.reasoningCost, .zero)
        XCTAssertEqual(breakdown.totalCost, decimal("0.0006255"))
    }

    func testClaudeCostEstimatorLeavesIncompleteCacheWriteSplitUnpriced() {
        let session = UsageSession(
            id: "claude-cache-split",
            provider: .claudeCode,
            surface: .cli,
            model: "claude-sonnet-4-6",
            startedAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            tokens: TokenBreakdown(
                inputTokens: 12,
                outputTokens: 5,
                cachedInputTokens: 12,
                totalTokens: 29,
                cacheReadTokens: 0,
                cacheCreationTokens: 12,
                cacheCreation5mTokens: 0,
                cacheCreation1hTokens: 0
            )
        )

        let estimate = UsageCostEstimator().estimate(for: session)

        XCTAssertNil(estimate.breakdown)
        XCTAssertEqual(estimate.notes, ["cache_write_split_missing_unpriced"])
    }

    func testClaudeCostEstimatorLeavesMixedModelSessionsUnpriced() throws {
        try withTemporaryDirectory { root in
            let claudeRoot = root.appendingPathComponent(".claude", isDirectory: true)
            let projectDirectory = claudeRoot
                .appendingPathComponent("projects", isDirectory: true)
                .appendingPathComponent("-Users-mac-Vova-Projects-tokens-widget", isDirectory: true)

            try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

            let fileURL = projectDirectory.appendingPathComponent("mixed-session.jsonl")
            try mixedClaudeFixture.write(to: fileURL, atomically: true, encoding: .utf8)

            let sessions = try ClaudeSessionParser().parseSessions(at: claudeRoot)
            let estimate = UsageCostEstimator().estimate(for: try XCTUnwrap(sessions.first))

            XCTAssertNil(estimate.breakdown)
            XCTAssertEqual(estimate.notes, ["mixed_model_unpriced"])
        }
    }

    func testImporterBuildsDailyAggregationAcrossProvidersAndCosts() throws {
        try withTemporaryDirectory { root in
            let codexRoot = root.appendingPathComponent(".codex", isDirectory: true)
            let claudeRoot = root.appendingPathComponent(".claude", isDirectory: true)

            let codexSessionsDirectory = codexRoot
                .appendingPathComponent("sessions", isDirectory: true)
                .appendingPathComponent("2026", isDirectory: true)
                .appendingPathComponent("04", isDirectory: true)
                .appendingPathComponent("04", isDirectory: true)
            try FileManager.default.createDirectory(at: codexSessionsDirectory, withIntermediateDirectories: true)
            try codexFixture.write(
                to: codexSessionsDirectory.appendingPathComponent("codex.jsonl"),
                atomically: true,
                encoding: .utf8
            )

            let claudeProjectsDirectory = claudeRoot
                .appendingPathComponent("projects", isDirectory: true)
                .appendingPathComponent("-Users-mac-Vova-Projects-tokens-widget", isDirectory: true)
            try FileManager.default.createDirectory(at: claudeProjectsDirectory, withIntermediateDirectories: true)
            try claudeFixture.write(
                to: claudeProjectsDirectory.appendingPathComponent("claude.jsonl"),
                atomically: true,
                encoding: .utf8
            )
            try mixedClaudeFixture.write(
                to: claudeProjectsDirectory.appendingPathComponent("claude-mixed.jsonl"),
                atomically: true,
                encoding: .utf8
            )

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

            let snapshot = try UsageImporter(calendar: calendar).importUsage(
                from: UsageImportRequest(codexRoot: codexRoot, claudeRoot: claudeRoot),
                now: Date(timeIntervalSince1970: 0)
            )

            XCTAssertEqual(snapshot.sessions.count, 3)
            XCTAssertEqual(snapshot.totalTokens, 2_345)
            XCTAssertEqual(snapshot.dailyTotals.count, 1)
            XCTAssertEqual(snapshot.dailyTotals[0].sessionCount, 3)
            XCTAssertEqual(snapshot.dailyTotals[0].providerTotals[.codex], 2_205)
            XCTAssertEqual(snapshot.dailyTotals[0].providerTotals[.claudeCode], 140)
            XCTAssertEqual(try XCTUnwrap(snapshot.estimatedCost), decimal("0.0095005"))
            XCTAssertEqual(try XCTUnwrap(snapshot.providerCostTotals[.codex]).totalCost, decimal("0.008875"))
            XCTAssertEqual(try XCTUnwrap(snapshot.providerCostTotals[.claudeCode]).totalCost, decimal("0.0006255"))
            XCTAssertEqual(snapshot.pricedSessionCount, 2)
            XCTAssertEqual(snapshot.unpricedSessionCount, 1)
            XCTAssertEqual(snapshot.unpricedReasonSummary["mixed_model_unpriced"], 1)
            XCTAssertEqual(try XCTUnwrap(snapshot.dailyTotals[0].estimatedCost), decimal("0.0095005"))
        }
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try body(root)
}

private let codexFixture = """
{"timestamp":"2026-04-04T10:36:27.638Z","type":"session_meta","payload":{"id":"codex-session","timestamp":"2026-04-04T10:33:30.781Z","cwd":"/Users/mac/Vova/Projects/tokens-widget","originator":"Codex Desktop","cli_version":"0.118.0-alpha.2","source":"vscode","model_provider":"openai"}}
{"timestamp":"2026-04-04T10:36:27.700Z","type":"turn_context","payload":{"turn_id":"turn-1","cwd":"/Users/mac/Vova/Projects/tokens-widget","model":"gpt-5.4","effort":"xhigh","collaboration_mode":{"mode":"default","settings":{"reasoning_effort":"high"}}}}
{"timestamp":"2026-04-04T10:36:27.830Z","type":"event_msg","payload":{"type":"token_count","info":null}}
{"timestamp":"2026-04-04T10:37:58.240Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1500,"cached_input_tokens":500,"output_tokens":120,"reasoning_output_tokens":20,"total_tokens":1640}}}}
{"timestamp":"2026-04-04T10:39:09.980Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1900,"cached_input_tokens":200,"output_tokens":255,"reasoning_output_tokens":50,"total_tokens":2205}}}}
"""

private let claudeFixture = """
{"parentUuid":null,"type":"user","message":{"role":"user","content":"hello"},"uuid":"user-1","timestamp":"2026-04-04T10:35:11.249Z","entrypoint":"cli","cwd":"/Users/mac/Vova/Projects/tokens-widget","sessionId":"claude-session","version":"2.1.81"}
{"parentUuid":"user-1","message":{"model":"claude-sonnet-4-6","id":"msg-1","type":"message","role":"assistant","content":[{"type":"text","text":"Hi"}],"usage":{"input_tokens":30,"cache_creation_input_tokens":10,"cache_read_input_tokens":0,"output_tokens":7,"service_tier":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":10},"speed":"standard"}},"type":"assistant","uuid":"assistant-1","timestamp":"2026-04-04T10:35:13.466Z","entrypoint":"cli","cwd":"/Users/mac/Vova/Projects/tokens-widget","sessionId":"claude-session","version":"2.1.81"}
{"parentUuid":"assistant-1","message":{"model":"claude-sonnet-4-6","id":"msg-2","type":"message","role":"assistant","content":[{"type":"text","text":"More"}],"usage":{"input_tokens":48,"cache_creation_input_tokens":0,"cache_read_input_tokens":5,"output_tokens":15,"service_tier":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0},"speed":"standard"}},"type":"assistant","uuid":"assistant-2","timestamp":"2026-04-04T10:39:13.466Z","entrypoint":"cli","cwd":"/Users/mac/Vova/Projects/tokens-widget","sessionId":"claude-session","version":"2.1.81"}
"""

private let claudeVSCodeFixture = """
{"parentUuid":null,"type":"user","message":{"role":"user","content":[{"type":"text","text":"yooo"}]},"uuid":"user-vscode-1","timestamp":"2026-04-05T12:32:02.049Z","entrypoint":"claude-vscode","cwd":"/Users/mac/Vova/Projects/tokens-widget","sessionId":"claude-vscode-session","version":"2.1.92"}
{"parentUuid":"user-vscode-1","message":{"model":"claude-opus-4-6","id":"msg-vscode-1","type":"message","role":"assistant","content":[{"type":"text","text":"yo!"}],"usage":{"input_tokens":3,"cache_creation_input_tokens":60,"cache_read_input_tokens":0,"output_tokens":17,"service_tier":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":60},"speed":"standard"}},"type":"assistant","uuid":"assistant-vscode-1","timestamp":"2026-04-05T12:32:07.609Z","entrypoint":"claude-vscode","cwd":"/Users/mac/Vova/Projects/tokens-widget","sessionId":"claude-vscode-session","version":"2.1.92"}
"""

private let mixedClaudeFixture = """
{"parentUuid":null,"type":"user","message":{"role":"user","content":"hello"},"uuid":"user-2","timestamp":"2026-04-04T10:36:11.249Z","entrypoint":"cli","cwd":"/Users/mac/Vova/Projects/tokens-widget","sessionId":"claude-mixed-session","version":"2.1.81"}
{"parentUuid":"user-2","message":{"model":"claude-sonnet-4-6","id":"msg-3","type":"message","role":"assistant","content":[{"type":"text","text":"Hi"}],"usage":{"input_tokens":10,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":4,"service_tier":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0},"speed":"standard"}},"type":"assistant","uuid":"assistant-3","timestamp":"2026-04-04T10:36:13.466Z","entrypoint":"cli","cwd":"/Users/mac/Vova/Projects/tokens-widget","sessionId":"claude-mixed-session","version":"2.1.81"}
{"parentUuid":"assistant-3","message":{"model":"claude-opus-4-6","id":"msg-4","type":"message","role":"assistant","content":[{"type":"text","text":"More"}],"usage":{"input_tokens":8,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":3,"service_tier":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0},"speed":"standard"}},"type":"assistant","uuid":"assistant-4","timestamp":"2026-04-04T10:37:13.466Z","entrypoint":"cli","cwd":"/Users/mac/Vova/Projects/tokens-widget","sessionId":"claude-mixed-session","version":"2.1.81"}
"""

private func decimal(_ value: String) -> Decimal {
    Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
}
