import Foundation

public struct ClaudeSessionParser: Sendable {
    public init() {}

    public func parseSessions(at root: URL) throws -> [UsageSession] {
        let projectsRoot = ParsingSupport.resolveUsageRoot(root: root, expectedLeaf: "projects")
        guard FileManager.default.fileExists(atPath: projectsRoot.path) else {
            return []
        }

        return ParsingSupport
            .jsonlFiles(in: projectsRoot)
            .compactMap(parseSessionFile)
            .sorted { $0.updatedAt < $1.updatedAt }
    }

    private func parseSessionFile(at fileURL: URL) -> UsageSession? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }

        var sessionID = fileURL.deletingPathExtension().lastPathComponent
        var rawSurface: String?
        var projectPath: String?
        var startedAt = Date.distantPast
        var updatedAt = Date.distantPast
        var tokens = TokenBreakdown.zero
        var models: Set<String> = []

        for line in content.split(whereSeparator: \.isNewline) {
            guard let object = ParsingSupport.parseObject(from: String(line)) else {
                continue
            }

            let lineTimestamp = ParsingSupport.parseTimestamp(ParsingSupport.string(object["timestamp"]))
            if let lineTimestamp {
                startedAt = min(startedAt, lineTimestamp)
                updatedAt = max(updatedAt, lineTimestamp)
            }

            sessionID = ParsingSupport.string(object["sessionId"]) ?? sessionID
            rawSurface = ParsingSupport.string(object["entrypoint"]) ?? rawSurface
            projectPath = ParsingSupport.string(object["cwd"]) ?? projectPath

            guard ParsingSupport.string(object["type"]) == "assistant",
                  let message = ParsingSupport.dictionary(object["message"]),
                  let usage = ParsingSupport.dictionary(message["usage"]) else {
                continue
            }

            let inputTokens = ParsingSupport.integer(usage["input_tokens"])
            let outputTokens = ParsingSupport.integer(usage["output_tokens"])
            let cacheReadTokens = ParsingSupport.integer(usage["cache_read_input_tokens"])
            let cacheCreationTokens = ParsingSupport.integer(usage["cache_creation_input_tokens"])
            let totalTokens = inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens

            tokens.inputTokens += inputTokens
            tokens.outputTokens += outputTokens
            tokens.cachedInputTokens += cacheReadTokens + cacheCreationTokens
            tokens.totalTokens += totalTokens

            if let model = ParsingSupport.string(message["model"]) {
                models.insert(model)
            }
        }

        guard tokens.totalTokens > 0 else {
            return nil
        }

        if startedAt == .distantPast {
            startedAt = updatedAt == .distantPast ? Date.now : updatedAt
        }

        if updatedAt == .distantPast {
            updatedAt = startedAt
        }

        let resolvedModel: String?
        switch models.count {
        case 0:
            resolvedModel = nil
        case 1:
            resolvedModel = models.first
        default:
            resolvedModel = models.sorted().joined(separator: ", ")
        }

        return UsageSession(
            id: sessionID,
            provider: .claudeCode,
            surface: UsageSurface.from(rawValue: rawSurface),
            rawSurface: rawSurface,
            model: resolvedModel,
            projectPath: projectPath,
            originator: "Claude Code",
            startedAt: startedAt,
            updatedAt: updatedAt,
            tokens: tokens,
            metadata: [
                "transcript_path": fileURL.path
            ]
        )
    }
}
