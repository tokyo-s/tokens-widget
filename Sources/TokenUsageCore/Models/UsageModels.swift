import Foundation

public enum UsageProvider: String, Codable, CaseIterable, Hashable, Sendable {
    case codex
    case claudeCode = "claude_code"
}

public enum UsageSurface: String, Codable, CaseIterable, Hashable, Sendable {
    case cli
    case vscode
    case cursor
    case windsurf
    case desktop
    case app
    case terminal
    case unknown

    public static func from(rawValue: String?) -> UsageSurface {
        guard let rawValue else { return .unknown }

        switch rawValue.lowercased() {
        case "cli":
            return .cli
        case "vscode":
            return .vscode
        case "cursor":
            return .cursor
        case "windsurf":
            return .windsurf
        case "desktop":
            return .desktop
        case "app":
            return .app
        case "terminal":
            return .terminal
        default:
            return .unknown
        }
    }
}

public struct TokenBreakdown: Codable, Hashable, Sendable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cachedInputTokens: Int
    public var reasoningTokens: Int
    public var totalTokens: Int

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cachedInputTokens: Int = 0,
        reasoningTokens: Int = 0,
        totalTokens: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
        self.reasoningTokens = reasoningTokens
        self.totalTokens = totalTokens
    }

    public static let zero = TokenBreakdown()
}

public struct UsageSession: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var provider: UsageProvider
    public var surface: UsageSurface
    public var rawSurface: String?
    public var model: String?
    public var projectPath: String?
    public var originator: String?
    public var startedAt: Date
    public var updatedAt: Date
    public var tokens: TokenBreakdown
    public var metadata: [String: String]

    public init(
        id: String,
        provider: UsageProvider,
        surface: UsageSurface,
        rawSurface: String? = nil,
        model: String? = nil,
        projectPath: String? = nil,
        originator: String? = nil,
        startedAt: Date,
        updatedAt: Date,
        tokens: TokenBreakdown,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.provider = provider
        self.surface = surface
        self.rawSurface = rawSurface
        self.model = model
        self.projectPath = projectPath
        self.originator = originator
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.tokens = tokens
        self.metadata = metadata
    }
}

public struct DailyUsageAggregate: Codable, Identifiable, Hashable, Sendable {
    public var date: Date
    public var totalTokens: Int
    public var sessionCount: Int
    public var providerTotals: [UsageProvider: Int]

    public init(
        date: Date,
        totalTokens: Int,
        sessionCount: Int,
        providerTotals: [UsageProvider: Int]
    ) {
        self.date = date
        self.totalTokens = totalTokens
        self.sessionCount = sessionCount
        self.providerTotals = providerTotals
    }

    public var id: String {
        date.formatted(.iso8601.year().month().day())
    }
}

public struct UsageSnapshot: Codable, Hashable, Sendable {
    public var generatedAt: Date
    public var sessions: [UsageSession]
    public var dailyTotals: [DailyUsageAggregate]

    public init(generatedAt: Date, sessions: [UsageSession], dailyTotals: [DailyUsageAggregate]) {
        self.generatedAt = generatedAt
        self.sessions = sessions
        self.dailyTotals = dailyTotals
    }

    public var totalTokens: Int {
        sessions.reduce(0) { $0 + $1.tokens.totalTokens }
    }

    public var totalSessions: Int {
        sessions.count
    }

    public var latestActivityAt: Date? {
        sessions.map(\.updatedAt).max()
    }

    public static func preview(now: Date = .now) -> UsageSnapshot {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: -84, to: now) ?? now

        var sessions: [UsageSession] = []
        for offset in stride(from: 0, through: 84, by: 3) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                continue
            }

            let total = 3_500 + (offset * 420)
            let provider: UsageProvider = offset.isMultiple(of: 2) ? .codex : .claudeCode
            let surface: UsageSurface = provider == .codex ? .vscode : .cli

            sessions.append(
                UsageSession(
                    id: "preview-\(offset)",
                    provider: provider,
                    surface: surface,
                    rawSurface: surface.rawValue,
                    model: provider == .codex ? "gpt-5.4" : "claude-sonnet-4-6",
                    projectPath: "/Users/example/Projects/tokens-widget",
                    originator: provider == .codex ? "Codex Desktop" : "Claude Code",
                    startedAt: day,
                    updatedAt: day.addingTimeInterval(1_200),
                    tokens: TokenBreakdown(
                        inputTokens: Int(Double(total) * 0.68),
                        outputTokens: Int(Double(total) * 0.19),
                        cachedInputTokens: Int(Double(total) * 0.1),
                        reasoningTokens: Int(Double(total) * 0.03),
                        totalTokens: total
                    )
                )
            )
        }

        let dailyTotals = DailyUsageAggregator(calendar: calendar).aggregate(sessions)
        return UsageSnapshot(generatedAt: now, sessions: sessions, dailyTotals: dailyTotals)
    }
}

public struct DailyUsageAggregator: Sendable {
    private var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func aggregate(_ sessions: [UsageSession]) -> [DailyUsageAggregate] {
        struct Bucket {
            var totalTokens: Int
            var sessionCount: Int
            var providerTotals: [UsageProvider: Int]
        }

        var buckets: [Date: Bucket] = [:]

        for session in sessions {
            let day = calendar.startOfDay(for: session.updatedAt)
            var bucket = buckets[day] ?? Bucket(totalTokens: 0, sessionCount: 0, providerTotals: [:])
            bucket.totalTokens += session.tokens.totalTokens
            bucket.sessionCount += 1
            bucket.providerTotals[session.provider, default: 0] += session.tokens.totalTokens
            buckets[day] = bucket
        }

        return buckets
            .map { date, bucket in
                DailyUsageAggregate(
                    date: date,
                    totalTokens: bucket.totalTokens,
                    sessionCount: bucket.sessionCount,
                    providerTotals: bucket.providerTotals
                )
            }
            .sorted { $0.date < $1.date }
    }
}
