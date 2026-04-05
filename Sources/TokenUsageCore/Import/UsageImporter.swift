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
    public var costEstimator: UsageCostEstimator
    public var calendar: Calendar

    public init(
        codexParser: CodexSessionParser = CodexSessionParser(),
        claudeParser: ClaudeSessionParser = ClaudeSessionParser(),
        costEstimator: UsageCostEstimator = UsageCostEstimator(),
        calendar: Calendar = .current
    ) {
        self.codexParser = codexParser
        self.claudeParser = claudeParser
        self.costEstimator = costEstimator
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

        sessions = sessions.map { session in
            var pricedSession = session
            let estimate = costEstimator.estimate(for: session)
            pricedSession.estimatedCost = estimate.breakdown
            pricedSession.pricingNotes = estimate.notes
            return pricedSession
        }

        sessions.sort { $0.updatedAt < $1.updatedAt }
        let dailyTotals = DailyUsageAggregator(calendar: calendar).aggregate(sessions)
        let pricedSessionCount = sessions.filter { $0.estimatedCost != nil }.count
        let unpricedSessions = sessions.filter { $0.estimatedCost == nil }
        let estimatedCost = sessions
            .compactMap(\.estimatedCost?.totalCost)
            .reduce(into: Optional<Decimal>.none) { partialResult, value in
                partialResult = (partialResult ?? .zero) + value
            }

        let providerCostTotals = Dictionary(
            uniqueKeysWithValues: UsageProvider.allCases.compactMap { provider in
                let summary = sessions
                    .filter { $0.provider == provider }
                    .compactMap(\.estimatedCost)
                    .reduce(into: ProviderCostSummary.zero) { partialResult, breakdown in
                        partialResult.add(breakdown)
                    }
                return summary.pricedSessionCount > 0 ? (provider, summary) : nil
            }
        )

        let unpricedReasonSummary = unpricedSessions
            .flatMap(\.pricingNotes)
            .filter { $0.hasSuffix("_unpriced") }
            .reduce(into: [String: Int]()) { result, note in
                result[note, default: 0] += 1
            }

        return UsageSnapshot(
            generatedAt: now,
            sessions: sessions,
            dailyTotals: dailyTotals,
            estimatedCost: estimatedCost,
            providerCostTotals: providerCostTotals,
            pricedSessionCount: pricedSessionCount,
            unpricedSessionCount: unpricedSessions.count,
            unpricedReasonSummary: unpricedReasonSummary
        )
    }
}
