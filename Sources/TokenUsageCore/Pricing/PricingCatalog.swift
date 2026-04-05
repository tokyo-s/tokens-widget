import Foundation

public struct PricingCatalog: Sendable {
    public struct CodexRates: Hashable, Sendable {
        public var inputUSDPerMillion: Decimal
        public var cachedInputUSDPerMillion: Decimal
        public var outputUSDPerMillion: Decimal
        public var fastModeMultiplier: Decimal?

        public init(
            inputUSDPerMillion: Decimal,
            cachedInputUSDPerMillion: Decimal,
            outputUSDPerMillion: Decimal,
            fastModeMultiplier: Decimal? = nil
        ) {
            self.inputUSDPerMillion = inputUSDPerMillion
            self.cachedInputUSDPerMillion = cachedInputUSDPerMillion
            self.outputUSDPerMillion = outputUSDPerMillion
            self.fastModeMultiplier = fastModeMultiplier
        }
    }

    public struct ClaudeRates: Hashable, Sendable {
        public var inputUSDPerMillion: Decimal
        public var cacheReadUSDPerMillion: Decimal
        public var cacheWrite5mUSDPerMillion: Decimal
        public var cacheWrite1hUSDPerMillion: Decimal
        public var outputUSDPerMillion: Decimal

        public init(
            inputUSDPerMillion: Decimal,
            cacheReadUSDPerMillion: Decimal,
            cacheWrite5mUSDPerMillion: Decimal,
            cacheWrite1hUSDPerMillion: Decimal,
            outputUSDPerMillion: Decimal
        ) {
            self.inputUSDPerMillion = inputUSDPerMillion
            self.cacheReadUSDPerMillion = cacheReadUSDPerMillion
            self.cacheWrite5mUSDPerMillion = cacheWrite5mUSDPerMillion
            self.cacheWrite1hUSDPerMillion = cacheWrite1hUSDPerMillion
            self.outputUSDPerMillion = outputUSDPerMillion
        }
    }

    public static let lastReviewedAt = "2026-04-05"

    public static let v1 = PricingCatalog(
        codexRatesByModel: [
            "gpt-5.4": CodexRates(
                inputUSDPerMillion: decimal("2.50"),
                cachedInputUSDPerMillion: decimal("0.25"),
                outputUSDPerMillion: decimal("15.00"),
                fastModeMultiplier: decimal("2")
            ),
            "gpt-5.4-mini": CodexRates(
                inputUSDPerMillion: decimal("0.75"),
                cachedInputUSDPerMillion: decimal("0.075"),
                outputUSDPerMillion: decimal("4.50"),
                fastModeMultiplier: decimal("2")
            ),
            "gpt-5.3-codex": CodexRates(
                inputUSDPerMillion: decimal("1.75"),
                cachedInputUSDPerMillion: decimal("0.175"),
                outputUSDPerMillion: decimal("14.00"),
                fastModeMultiplier: decimal("2")
            ),
            "gpt-5.2-codex": CodexRates(
                inputUSDPerMillion: decimal("1.75"),
                cachedInputUSDPerMillion: decimal("0.175"),
                outputUSDPerMillion: decimal("14.00"),
                fastModeMultiplier: decimal("2")
            ),
            "gpt-5.2": CodexRates(
                inputUSDPerMillion: decimal("1.75"),
                cachedInputUSDPerMillion: decimal("0.175"),
                outputUSDPerMillion: decimal("14.00"),
                fastModeMultiplier: decimal("2")
            ),
            "gpt-5.1-codex-max": CodexRates(
                inputUSDPerMillion: decimal("1.25"),
                cachedInputUSDPerMillion: decimal("0.125"),
                outputUSDPerMillion: decimal("10.00"),
                fastModeMultiplier: decimal("2")
            ),
            "gpt-5.1-codex-mini": CodexRates(
                inputUSDPerMillion: decimal("0.25"),
                cachedInputUSDPerMillion: decimal("0.025"),
                outputUSDPerMillion: decimal("2.00"),
                fastModeMultiplier: decimal("2")
            )
        ],
        claudeRatesByModel: [
            "claude-sonnet-4-6": ClaudeRates(
                inputUSDPerMillion: decimal("3.00"),
                cacheReadUSDPerMillion: decimal("0.30"),
                cacheWrite5mUSDPerMillion: decimal("3.75"),
                cacheWrite1hUSDPerMillion: decimal("6.00"),
                outputUSDPerMillion: decimal("15.00")
            ),
            "claude-opus-4-6": ClaudeRates(
                inputUSDPerMillion: decimal("5.00"),
                cacheReadUSDPerMillion: decimal("0.50"),
                cacheWrite5mUSDPerMillion: decimal("6.25"),
                cacheWrite1hUSDPerMillion: decimal("10.00"),
                outputUSDPerMillion: decimal("25.00")
            )
        ]
    )

    private let codexRatesByModel: [String: CodexRates]
    private let claudeRatesByModel: [String: ClaudeRates]

    public init(
        codexRatesByModel: [String: CodexRates],
        claudeRatesByModel: [String: ClaudeRates]
    ) {
        self.codexRatesByModel = codexRatesByModel
        self.claudeRatesByModel = claudeRatesByModel
    }

    public func codexRates(for model: String?) -> CodexRates? {
        guard let normalizedModel = Self.normalize(model) else {
            return nil
        }

        return codexRatesByModel[normalizedModel]
    }

    public func claudeRates(for model: String?) -> ClaudeRates? {
        guard let normalizedModel = Self.normalize(model) else {
            return nil
        }

        return claudeRatesByModel[normalizedModel]
    }

    public static func normalize(_ model: String?) -> String? {
        guard let model else {
            return nil
        }

        let normalized = model
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "--", with: "-")

        return normalized.isEmpty ? nil : normalized
    }
}

private func decimal(_ value: String) -> Decimal {
    Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
}
