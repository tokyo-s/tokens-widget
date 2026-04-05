import Foundation

struct UsageCostEstimate: Hashable, Sendable {
    var breakdown: CostBreakdown?
    var notes: [String]
}

public struct UsageCostEstimator: Sendable {
    public var pricingCatalog: PricingCatalog

    public init(pricingCatalog: PricingCatalog = .v1) {
        self.pricingCatalog = pricingCatalog
    }

    public func estimateCost(for session: UsageSession) -> CostBreakdown? {
        estimate(for: session).breakdown
    }

    func estimate(for session: UsageSession) -> UsageCostEstimate {
        switch session.provider {
        case .codex:
            return estimateCodexCost(for: session)
        case .claudeCode:
            return estimateClaudeCost(for: session)
        }
    }

    private func estimateCodexCost(for session: UsageSession) -> UsageCostEstimate {
        var notes = session.pricingNotes

        guard let model = session.model else {
            notes.append("model_missing_unpriced")
            return UsageCostEstimate(breakdown: nil, notes: deduplicated(notes))
        }

        guard let rates = pricingCatalog.codexRates(for: model) else {
            notes.append("unsupported_model_unpriced")
            return UsageCostEstimate(breakdown: nil, notes: deduplicated(notes))
        }

        let uncachedInputTokens = max(session.tokens.inputTokens - session.tokens.cachedInputTokens, 0)
        let cachedInputTokens = max(session.tokens.cachedInputTokens, 0)
        let outputTokens = max(session.tokens.outputTokens, 0)
        let reasoningTokens = max(session.tokens.reasoningTokens, 0)

        let breakdown = CostBreakdown(
            inputCost: cost(for: uncachedInputTokens, ratePerMillion: rates.inputUSDPerMillion),
            cachedInputCost: cost(for: cachedInputTokens, ratePerMillion: rates.cachedInputUSDPerMillion),
            outputCost: cost(for: outputTokens, ratePerMillion: rates.outputUSDPerMillion),
            reasoningCost: cost(for: reasoningTokens, ratePerMillion: rates.outputUSDPerMillion)
        )

        if rates.fastModeMultiplier != nil {
            notes.append("fast_mode_not_detected")
        }

        return UsageCostEstimate(breakdown: breakdown, notes: deduplicated(notes))
    }

    private func estimateClaudeCost(for session: UsageSession) -> UsageCostEstimate {
        var notes = session.pricingNotes

        if notes.contains("mixed_model_unpriced") {
            return UsageCostEstimate(breakdown: nil, notes: deduplicated(notes))
        }

        guard let model = session.model else {
            notes.append("model_missing_unpriced")
            return UsageCostEstimate(breakdown: nil, notes: deduplicated(notes))
        }

        guard let rates = pricingCatalog.claudeRates(for: model) else {
            notes.append("unsupported_model_unpriced")
            return UsageCostEstimate(breakdown: nil, notes: deduplicated(notes))
        }

        if session.tokens.cacheCreationTokens > 0 {
            let splitTokens = session.tokens.cacheCreation5mTokens + session.tokens.cacheCreation1hTokens
            if splitTokens != session.tokens.cacheCreationTokens {
                notes.append("cache_write_split_missing_unpriced")
                return UsageCostEstimate(breakdown: nil, notes: deduplicated(notes))
            }
        }

        let cachedInputCost =
            cost(for: session.tokens.cacheReadTokens, ratePerMillion: rates.cacheReadUSDPerMillion) +
            cost(for: session.tokens.cacheCreation5mTokens, ratePerMillion: rates.cacheWrite5mUSDPerMillion) +
            cost(for: session.tokens.cacheCreation1hTokens, ratePerMillion: rates.cacheWrite1hUSDPerMillion)

        let breakdown = CostBreakdown(
            inputCost: cost(for: session.tokens.inputTokens, ratePerMillion: rates.inputUSDPerMillion),
            cachedInputCost: cachedInputCost,
            outputCost: cost(for: session.tokens.outputTokens, ratePerMillion: rates.outputUSDPerMillion),
            reasoningCost: .zero
        )

        return UsageCostEstimate(breakdown: breakdown, notes: deduplicated(notes))
    }

    private func cost(for tokens: Int, ratePerMillion: Decimal) -> Decimal {
        guard tokens > 0 else {
            return .zero
        }

        return (Decimal(tokens) * ratePerMillion) / 1_000_000
    }

    private func deduplicated(_ notes: [String]) -> [String] {
        var seen: Set<String> = []
        return notes.filter { seen.insert($0).inserted }
    }
}
