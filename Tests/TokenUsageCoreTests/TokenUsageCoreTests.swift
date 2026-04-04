import Foundation
import XCTest
@testable import TokenUsageCore

final class TokenUsageCoreTests: XCTestCase {
    func testCodexSessionsUseFinalTokenSnapshot() throws {
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
            XCTAssertEqual(sessions[0].projectPath, "/Users/mac/Vova/Projects/tokens-widget")
        }
    }

    func testClaudeSessionsSumAssistantUsageAcrossMessages() throws {
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
            XCTAssertEqual(sessions[0].tokens.totalTokens, 115)
            XCTAssertEqual(sessions[0].model, "claude-sonnet-4-6")
        }
    }

    func testImporterBuildsDailyAggregationAcrossProviders() throws {
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

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

            let snapshot = try UsageImporter(calendar: calendar).importUsage(
                from: UsageImportRequest(codexRoot: codexRoot, claudeRoot: claudeRoot),
                now: Date(timeIntervalSince1970: 0)
            )

            XCTAssertEqual(snapshot.sessions.count, 2)
            XCTAssertEqual(snapshot.totalTokens, 2_320)
            XCTAssertEqual(snapshot.dailyTotals.count, 1)
            XCTAssertEqual(snapshot.dailyTotals[0].sessionCount, 2)
            XCTAssertEqual(snapshot.dailyTotals[0].providerTotals[.codex], 2_205)
            XCTAssertEqual(snapshot.dailyTotals[0].providerTotals[.claudeCode], 115)
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
{"timestamp":"2026-04-04T10:36:27.830Z","type":"event_msg","payload":{"type":"token_count","info":null}}
{"timestamp":"2026-04-04T10:37:58.240Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1500,"cached_input_tokens":500,"output_tokens":120,"reasoning_output_tokens":20,"total_tokens":1640}}}}
{"timestamp":"2026-04-04T10:39:09.980Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1900,"cached_input_tokens":200,"output_tokens":255,"reasoning_output_tokens":50,"total_tokens":2205}}}}
"""

private let claudeFixture = """
{"parentUuid":null,"type":"user","message":{"role":"user","content":"hello"},"uuid":"user-1","timestamp":"2026-04-04T10:35:11.249Z","entrypoint":"cli","cwd":"/Users/mac/Vova/Projects/tokens-widget","sessionId":"claude-session","version":"2.1.81"}
{"parentUuid":"user-1","message":{"model":"claude-sonnet-4-6","id":"msg-1","type":"message","role":"assistant","content":[{"type":"text","text":"Hi"}],"usage":{"input_tokens":30,"cache_creation_input_tokens":10,"cache_read_input_tokens":0,"output_tokens":7}},"type":"assistant","uuid":"assistant-1","timestamp":"2026-04-04T10:35:13.466Z","entrypoint":"cli","cwd":"/Users/mac/Vova/Projects/tokens-widget","sessionId":"claude-session","version":"2.1.81"}
{"parentUuid":"assistant-1","message":{"model":"claude-sonnet-4-6","id":"msg-2","type":"message","role":"assistant","content":[{"type":"text","text":"More"}],"usage":{"input_tokens":48,"cache_creation_input_tokens":0,"cache_read_input_tokens":5,"output_tokens":15}},"type":"assistant","uuid":"assistant-2","timestamp":"2026-04-04T10:39:13.466Z","entrypoint":"cli","cwd":"/Users/mac/Vova/Projects/tokens-widget","sessionId":"claude-session","version":"2.1.81"}
"""
