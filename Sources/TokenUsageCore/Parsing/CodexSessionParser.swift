import Foundation

public struct CodexSessionParser: Sendable {
    public init() {}

    public func parseSessions(at root: URL) throws -> [UsageSession] {
        let sessionsRoot = ParsingSupport.resolveUsageRoot(root: root, expectedLeaf: "sessions")
        guard FileManager.default.fileExists(atPath: sessionsRoot.path) else {
            return []
        }

        return ParsingSupport
            .jsonlFiles(in: sessionsRoot)
            .compactMap(parseSessionFile)
            .sorted { $0.updatedAt < $1.updatedAt }
    }

    private func parseSessionFile(at fileURL: URL) -> UsageSession? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }

        var sessionID = fileURL.deletingPathExtension().lastPathComponent
        var startedAt = Date.distantPast
        var updatedAt = Date.distantPast
        var projectPath: String?
        var originator: String?
        var rawSurface: String?
        var model: String?
        var finalTokens: TokenBreakdown?

        for line in content.split(whereSeparator: \.isNewline) {
            guard let object = ParsingSupport.parseObject(from: String(line)) else {
                continue
            }

            let lineTimestamp = ParsingSupport.parseTimestamp(ParsingSupport.string(object["timestamp"]))
            let type = ParsingSupport.string(object["type"])

            switch type {
            case "session_meta":
                guard let payload = ParsingSupport.dictionary(object["payload"]) else {
                    continue
                }

                sessionID = ParsingSupport.string(payload["id"]) ?? sessionID
                if let payloadTimestamp = ParsingSupport.parseTimestamp(ParsingSupport.string(payload["timestamp"])) {
                    startedAt = payloadTimestamp
                } else if let lineTimestamp {
                    startedAt = lineTimestamp
                }

                projectPath = ParsingSupport.string(payload["cwd"]) ?? projectPath
                originator = ParsingSupport.string(payload["originator"]) ?? originator
                rawSurface = ParsingSupport.string(payload["source"]) ?? rawSurface
                model = ParsingSupport.string(payload["model"]) ?? model

            case "event_msg":
                guard let payload = ParsingSupport.dictionary(object["payload"]),
                      ParsingSupport.string(payload["type"]) == "token_count",
                      let info = ParsingSupport.dictionary(payload["info"]),
                      let totalUsage = ParsingSupport.dictionary(info["total_token_usage"]) else {
                    continue
                }

                finalTokens = TokenBreakdown(
                    inputTokens: ParsingSupport.integer(totalUsage["input_tokens"]),
                    outputTokens: ParsingSupport.integer(totalUsage["output_tokens"]),
                    cachedInputTokens: ParsingSupport.integer(totalUsage["cached_input_tokens"]),
                    reasoningTokens: ParsingSupport.integer(totalUsage["reasoning_output_tokens"]),
                    totalTokens: ParsingSupport.integer(totalUsage["total_tokens"])
                )

                if let lineTimestamp {
                    updatedAt = lineTimestamp
                }

            default:
                continue
            }
        }

        guard let finalTokens else {
            return nil
        }

        if startedAt == .distantPast {
            startedAt = updatedAt == .distantPast ? Date.now : updatedAt
        }

        if updatedAt == .distantPast {
            updatedAt = startedAt
        }

        return UsageSession(
            id: sessionID,
            provider: .codex,
            surface: UsageSurface.from(rawValue: rawSurface),
            rawSurface: rawSurface,
            model: model,
            projectPath: projectPath,
            originator: originator,
            startedAt: startedAt,
            updatedAt: updatedAt,
            tokens: finalTokens,
            metadata: [
                "transcript_path": fileURL.path
            ]
        )
    }
}
