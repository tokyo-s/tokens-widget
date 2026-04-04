import Foundation

public struct UsageImportRequest: Sendable {
    public var codexRoot: URL?
    public var claudeRoot: URL?

    public init(codexRoot: URL? = nil, claudeRoot: URL? = nil) {
        self.codexRoot = codexRoot
        self.claudeRoot = claudeRoot
    }
}

public struct UsageImporter: Sendable {
    public var codexParser: CodexSessionParser
    public var claudeParser: ClaudeSessionParser
    public var calendar: Calendar

    public init(
        codexParser: CodexSessionParser = CodexSessionParser(),
        claudeParser: ClaudeSessionParser = ClaudeSessionParser(),
        calendar: Calendar = .current
    ) {
        self.codexParser = codexParser
        self.claudeParser = claudeParser
        self.calendar = calendar
    }

    public func importUsage(from request: UsageImportRequest, now: Date = .now) throws -> UsageSnapshot {
        var sessions: [UsageSession] = []

        if let codexRoot = request.codexRoot {
            sessions.append(contentsOf: try codexParser.parseSessions(at: codexRoot))
        }

        if let claudeRoot = request.claudeRoot {
            sessions.append(contentsOf: try claudeParser.parseSessions(at: claudeRoot))
        }

        sessions.sort { $0.updatedAt < $1.updatedAt }
        let dailyTotals = DailyUsageAggregator(calendar: calendar).aggregate(sessions)
        return UsageSnapshot(generatedAt: now, sessions: sessions, dailyTotals: dailyTotals)
    }
}
