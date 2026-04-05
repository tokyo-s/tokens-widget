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
        case "vscode", "claude-vscode", "codex-vscode":
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
    public var cacheReadTokens: Int
    public var cacheCreationTokens: Int
    public var cacheCreation5mTokens: Int
    public var cacheCreation1hTokens: Int

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cachedInputTokens: Int = 0,
        reasoningTokens: Int = 0,
        totalTokens: Int = 0,
        cacheReadTokens: Int = 0,
        cacheCreationTokens: Int = 0,
        cacheCreation5mTokens: Int = 0,
        cacheCreation1hTokens: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
        self.reasoningTokens = reasoningTokens
        self.totalTokens = totalTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheCreation5mTokens = cacheCreation5mTokens
        self.cacheCreation1hTokens = cacheCreation1hTokens
    }

    public static let zero = TokenBreakdown()

    private enum CodingKeys: String, CodingKey {
        case inputTokens
        case outputTokens
        case cachedInputTokens
        case reasoningTokens
        case totalTokens
        case cacheReadTokens
        case cacheCreationTokens
        case cacheCreation5mTokens
        case cacheCreation1hTokens
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try container.decodeIfPresent(Int.self, forKey: .inputTokens) ?? 0
        outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens) ?? 0
        cachedInputTokens = try container.decodeIfPresent(Int.self, forKey: .cachedInputTokens) ?? 0
        reasoningTokens = try container.decodeIfPresent(Int.self, forKey: .reasoningTokens) ?? 0
        totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens) ?? 0
        cacheReadTokens = try container.decodeIfPresent(Int.self, forKey: .cacheReadTokens) ?? 0
        cacheCreationTokens = try container.decodeIfPresent(Int.self, forKey: .cacheCreationTokens) ?? 0
        cacheCreation5mTokens = try container.decodeIfPresent(Int.self, forKey: .cacheCreation5mTokens) ?? 0
        cacheCreation1hTokens = try container.decodeIfPresent(Int.self, forKey: .cacheCreation1hTokens) ?? 0
    }
}

public struct CostBreakdown: Codable, Hashable, Sendable {
    public var inputCost: Decimal
    public var cachedInputCost: Decimal
    public var outputCost: Decimal
    public var reasoningCost: Decimal
    public var totalCost: Decimal

    public init(
        inputCost: Decimal = .zero,
        cachedInputCost: Decimal = .zero,
        outputCost: Decimal = .zero,
        reasoningCost: Decimal = .zero
    ) {
        self.inputCost = inputCost
        self.cachedInputCost = cachedInputCost
        self.outputCost = outputCost
        self.reasoningCost = reasoningCost
        totalCost = inputCost + cachedInputCost + outputCost + reasoningCost
    }

    public init(
        inputCost: Decimal = .zero,
        cachedInputCost: Decimal = .zero,
        outputCost: Decimal = .zero,
        reasoningCost: Decimal = .zero,
        totalCost: Decimal
    ) {
        self.inputCost = inputCost
        self.cachedInputCost = cachedInputCost
        self.outputCost = outputCost
        self.reasoningCost = reasoningCost
        self.totalCost = totalCost
    }

    public var displayedOutputCost: Decimal {
        outputCost + reasoningCost
    }
}

public struct ProviderCostSummary: Codable, Hashable, Sendable {
    public var inputCost: Decimal
    public var cachedInputCost: Decimal
    public var outputCost: Decimal
    public var reasoningCost: Decimal
    public var totalCost: Decimal
    public var pricedSessionCount: Int

    public init(
        inputCost: Decimal = .zero,
        cachedInputCost: Decimal = .zero,
        outputCost: Decimal = .zero,
        reasoningCost: Decimal = .zero,
        totalCost: Decimal? = nil,
        pricedSessionCount: Int = 0
    ) {
        self.inputCost = inputCost
        self.cachedInputCost = cachedInputCost
        self.outputCost = outputCost
        self.reasoningCost = reasoningCost
        self.totalCost = totalCost ?? (inputCost + cachedInputCost + outputCost + reasoningCost)
        self.pricedSessionCount = pricedSessionCount
    }

    public static let zero = ProviderCostSummary()

    public var displayedOutputCost: Decimal {
        outputCost + reasoningCost
    }

    public mutating func add(_ breakdown: CostBreakdown) {
        inputCost += breakdown.inputCost
        cachedInputCost += breakdown.cachedInputCost
        outputCost += breakdown.outputCost
        reasoningCost += breakdown.reasoningCost
        totalCost += breakdown.totalCost
        pricedSessionCount += 1
    }
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
    public var reasoningEffort: String?
    public var speed: String?
    public var serviceTier: String?
    public var pricingNotes: [String]
    public var estimatedCost: CostBreakdown?
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
        reasoningEffort: String? = nil,
        speed: String? = nil,
        serviceTier: String? = nil,
        pricingNotes: [String] = [],
        estimatedCost: CostBreakdown? = nil,
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
        self.reasoningEffort = reasoningEffort
        self.speed = speed
        self.serviceTier = serviceTier
        self.pricingNotes = pricingNotes
        self.estimatedCost = estimatedCost
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case provider
        case surface
        case rawSurface
        case model
        case projectPath
        case originator
        case startedAt
        case updatedAt
        case tokens
        case reasoningEffort
        case speed
        case serviceTier
        case pricingNotes
        case estimatedCost
        case metadata
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        provider = try container.decode(UsageProvider.self, forKey: .provider)
        surface = try container.decode(UsageSurface.self, forKey: .surface)
        rawSurface = try container.decodeIfPresent(String.self, forKey: .rawSurface)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        projectPath = try container.decodeIfPresent(String.self, forKey: .projectPath)
        originator = try container.decodeIfPresent(String.self, forKey: .originator)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        tokens = try container.decode(TokenBreakdown.self, forKey: .tokens)
        reasoningEffort = try container.decodeIfPresent(String.self, forKey: .reasoningEffort)
        speed = try container.decodeIfPresent(String.self, forKey: .speed)
        serviceTier = try container.decodeIfPresent(String.self, forKey: .serviceTier)
        pricingNotes = try container.decodeIfPresent([String].self, forKey: .pricingNotes) ?? []
        estimatedCost = try container.decodeIfPresent(CostBreakdown.self, forKey: .estimatedCost)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }
}

public struct DailyUsageAggregate: Codable, Identifiable, Hashable, Sendable {
    public var date: Date
    public var totalTokens: Int
    public var sessionCount: Int
    public var providerTotals: [UsageProvider: Int]
    public var estimatedCost: Decimal?
    public var providerCostTotals: [UsageProvider: ProviderCostSummary]

    public init(
        date: Date,
        totalTokens: Int,
        sessionCount: Int,
        providerTotals: [UsageProvider: Int],
        estimatedCost: Decimal? = nil,
        providerCostTotals: [UsageProvider: ProviderCostSummary] = [:]
    ) {
        self.date = date
        self.totalTokens = totalTokens
        self.sessionCount = sessionCount
        self.providerTotals = providerTotals
        self.estimatedCost = estimatedCost
        self.providerCostTotals = providerCostTotals
    }

    public var id: String {
        date.formatted(.iso8601.year().month().day())
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case totalTokens
        case sessionCount
        case providerTotals
        case estimatedCost
        case providerCostTotals
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        totalTokens = try container.decode(Int.self, forKey: .totalTokens)
        sessionCount = try container.decode(Int.self, forKey: .sessionCount)
        providerTotals = try container.decode([UsageProvider: Int].self, forKey: .providerTotals)
        estimatedCost = try container.decodeIfPresent(Decimal.self, forKey: .estimatedCost)
        providerCostTotals = try container.decodeIfPresent([UsageProvider: ProviderCostSummary].self, forKey: .providerCostTotals) ?? [:]
    }
}

public struct UsageSnapshot: Codable, Hashable, Sendable {
    public var generatedAt: Date
    public var sessions: [UsageSession]
    public var dailyTotals: [DailyUsageAggregate]
    public var estimatedCost: Decimal?
    public var providerCostTotals: [UsageProvider: ProviderCostSummary]
    public var pricedSessionCount: Int
    public var unpricedSessionCount: Int
    public var unpricedReasonSummary: [String: Int]

    public init(
        generatedAt: Date,
        sessions: [UsageSession],
        dailyTotals: [DailyUsageAggregate],
        estimatedCost: Decimal? = nil,
        providerCostTotals: [UsageProvider: ProviderCostSummary] = [:],
        pricedSessionCount: Int = 0,
        unpricedSessionCount: Int = 0,
        unpricedReasonSummary: [String: Int] = [:]
    ) {
        self.generatedAt = generatedAt
        self.sessions = sessions
        self.dailyTotals = dailyTotals
        self.estimatedCost = estimatedCost
        self.providerCostTotals = providerCostTotals
        self.pricedSessionCount = pricedSessionCount
        self.unpricedSessionCount = unpricedSessionCount
        self.unpricedReasonSummary = unpricedReasonSummary
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
                        totalTokens: total,
                        cacheReadTokens: provider == .claudeCode ? Int(Double(total) * 0.06) : Int(Double(total) * 0.1),
                        cacheCreationTokens: provider == .claudeCode ? Int(Double(total) * 0.04) : 0,
                        cacheCreation5mTokens: provider == .claudeCode ? Int(Double(total) * 0.015) : 0,
                        cacheCreation1hTokens: provider == .claudeCode ? Int(Double(total) * 0.025) : 0
                    ),
                    reasoningEffort: provider == .codex ? "high" : nil,
                    speed: provider == .claudeCode ? "standard" : nil,
                    serviceTier: provider == .claudeCode ? "standard" : nil
                )
            )
        }

        let estimator = UsageCostEstimator()
        sessions = sessions.map { session in
            var pricedSession = session
            let estimate = estimator.estimate(for: session)
            pricedSession.estimatedCost = estimate.breakdown
            pricedSession.pricingNotes = estimate.notes
            return pricedSession
        }

        let dailyTotals = DailyUsageAggregator(calendar: calendar).aggregate(sessions)
        return UsageSnapshot(
            generatedAt: now,
            sessions: sessions,
            dailyTotals: dailyTotals,
            estimatedCost: sessions.compactMap(\.estimatedCost?.totalCost).sumOrNil(),
            providerCostTotals: Dictionary(
                uniqueKeysWithValues: UsageProvider.allCases.compactMap { provider in
                    let summary = sessions
                        .filter { $0.provider == provider }
                        .compactMap(\.estimatedCost)
                        .reduce(into: ProviderCostSummary.zero) { partialResult, breakdown in
                            partialResult.add(breakdown)
                        }
                    return summary.pricedSessionCount > 0 ? (provider, summary) : nil
                }
            ),
            pricedSessionCount: sessions.filter { $0.estimatedCost != nil }.count,
            unpricedSessionCount: sessions.filter { $0.estimatedCost == nil }.count,
            unpricedReasonSummary: sessions
                .filter { $0.estimatedCost == nil }
                .flatMap(\.pricingNotes)
                .filter { $0.hasSuffix("_unpriced") }
                .reduce(into: [String: Int]()) { result, note in
                    result[note, default: 0] += 1
                }
        )
    }

    private enum CodingKeys: String, CodingKey {
        case generatedAt
        case sessions
        case dailyTotals
        case estimatedCost
        case providerCostTotals
        case pricedSessionCount
        case unpricedSessionCount
        case unpricedReasonSummary
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        sessions = try container.decode([UsageSession].self, forKey: .sessions)
        dailyTotals = try container.decode([DailyUsageAggregate].self, forKey: .dailyTotals)
        estimatedCost = try container.decodeIfPresent(Decimal.self, forKey: .estimatedCost)
        providerCostTotals = try container.decodeIfPresent([UsageProvider: ProviderCostSummary].self, forKey: .providerCostTotals) ?? [:]
        pricedSessionCount = try container.decodeIfPresent(Int.self, forKey: .pricedSessionCount) ?? sessions.filter { $0.estimatedCost != nil }.count
        unpricedSessionCount = try container.decodeIfPresent(Int.self, forKey: .unpricedSessionCount) ?? sessions.filter { $0.estimatedCost == nil }.count
        unpricedReasonSummary = try container.decodeIfPresent([String: Int].self, forKey: .unpricedReasonSummary) ?? [:]
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
            var estimatedCost: Decimal?
            var providerCostTotals: [UsageProvider: ProviderCostSummary]
        }

        var buckets: [Date: Bucket] = [:]

        for session in sessions {
            let day = calendar.startOfDay(for: session.updatedAt)
            var bucket = buckets[day] ?? Bucket(
                totalTokens: 0,
                sessionCount: 0,
                providerTotals: [:],
                estimatedCost: nil,
                providerCostTotals: [:]
            )
            bucket.totalTokens += session.tokens.totalTokens
            bucket.sessionCount += 1
            bucket.providerTotals[session.provider, default: 0] += session.tokens.totalTokens

            if let estimatedCost = session.estimatedCost {
                bucket.estimatedCost = (bucket.estimatedCost ?? .zero) + estimatedCost.totalCost
                var providerSummary = bucket.providerCostTotals[session.provider, default: .zero]
                providerSummary.add(estimatedCost)
                bucket.providerCostTotals[session.provider] = providerSummary
            }

            buckets[day] = bucket
        }

        return buckets
            .map { date, bucket in
                DailyUsageAggregate(
                    date: date,
                    totalTokens: bucket.totalTokens,
                    sessionCount: bucket.sessionCount,
                    providerTotals: bucket.providerTotals,
                    estimatedCost: bucket.estimatedCost,
                    providerCostTotals: bucket.providerCostTotals
                )
            }
            .sorted { $0.date < $1.date }
    }
}

private extension Sequence where Element == Decimal {
    func sumOrNil() -> Decimal? {
        reduce(into: Optional<Decimal>.none) { result, value in
            result = (result ?? .zero) + value
        }
    }
}
