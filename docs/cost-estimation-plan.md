# Cost Estimation Plan

## Summary

Add an estimated USD cost layer on top of the existing token import flow so the app can:

- show one top-level `Estimated Cost` value for all imported Codex and Claude Code usage
- show a hover breakdown that separates Codex vs Claude Code totals
- show token-category subtotals for each provider where the log format supports them
- capture and use thinking/speed metadata where it is present in local logs

This is an estimate feature, not invoice-grade billing. The UI should consistently label the number as `Estimated Cost`.

## Files A New Agent Should Read In Full

Before implementing this plan, a new agent should read these files completely and in this order.

1. `README.md`
   This explains the current product scope and confirms that the app is token-first today.
2. `Package.swift`
   This shows the Swift package boundary for `TokenUsageCore`, which is where the pricing engine should live.
3. `Sources/TokenUsageCore/Models/UsageModels.swift`
   This is the core schema file and will need the biggest structural changes for cost and metadata fields.
4. `Sources/TokenUsageCore/Parsing/ParsingSupport.swift`
   This contains the shared JSONL parsing helpers that the parser changes must stay compatible with.
5. `Sources/TokenUsageCore/Parsing/CodexSessionParser.swift`
   This is the source of truth for Codex token extraction and where Codex reasoning-effort parsing must be added.
6. `Sources/TokenUsageCore/Parsing/ClaudeSessionParser.swift`
   This is the source of truth for Claude token extraction and where speed, service-tier, and cache split parsing must be added.
7. `Sources/TokenUsageCore/Import/UsageImporter.swift`
   This is where parsed sessions become the snapshot and where session pricing plus aggregate pricing should be wired in.
8. `Tests/TokenUsageCoreTests/TokenUsageCoreTests.swift`
   This shows the current test style, existing fixtures, and the safest place to extend parser and importer coverage.
9. `App/Sources/App/AppViewModel.swift`
   This controls refresh, import, and snapshot persistence for the macOS app.
10. `App/Sources/Views/RootView.swift`
    This contains the Overview cards and is the primary place where the new cost card and hover UI should be added.
11. `SharedUI/ContributionMatrixView.swift`
    This already implements the hover tooltip pattern that the cost card should visually align with.
12. `SharedUI/UsageTheme.swift`
    This defines the styling tokens that the new card and hover breakdown should reuse instead of inventing a new look.
13. `SharedUI/SharedSnapshotStore.swift`
    This is the snapshot serialization boundary, so any model changes must remain Codable-safe here.
14. `SharedUI/AppConfiguration.swift`
    This contains the snapshot storage naming and app-group configuration used by both the app and widget.
15. `Widget/Sources/TokensUsageWidget.swift`
    This reads `UsageSnapshot` too, so any snapshot schema change must be checked against the widget even if the widget UI is unchanged in v1.

## User Experience

- Add a fourth overview card in [RootView.swift](/Users/mac/Vova/Projects/tokens-widget/App/Sources/Views/RootView.swift) named `Estimated Cost`.
- The main value is the total estimated USD cost across all priced sessions in the current snapshot.
- On hover, show a compact tooltip/popover with:
  - `Codex: $X`
  - `Claude Code: $Y`
  - for each provider, a smaller breakdown line: `Input`, `Cached`, `Output`
  - a short note when any sessions were skipped because the model was missing or mixed
- Keep the contribution matrix token-based in v1. The request only needs one place to see total cost, so the matrix tooltip should not be expanded yet.
- Add a short detail line to the card: `Estimated from local tokens and published pricing tables.`

## Implementation Changes

### 1. Expand the domain model

Update [UsageModels.swift](/Users/mac/Vova/Projects/tokens-widget/Sources/TokenUsageCore/Models/UsageModels.swift) to carry the raw fields required for pricing and the computed estimates.

- Keep `TokenBreakdown` as the raw log representation, but extend it with zero-default fields needed for provider-specific pricing:
  - `cacheReadTokens`
  - `cacheCreationTokens`
  - `cacheCreation5mTokens`
  - `cacheCreation1hTokens`
- Keep `cachedInputTokens` as the legacy aggregate used by the existing token UI.
- Add typed execution metadata to `UsageSession` instead of hiding it in `metadata`:
  - `reasoningEffort: String?`
  - `speed: String?`
  - `serviceTier: String?`
  - `pricingNotes: [String]` for skipped or inferred pricing cases
- Add `CostBreakdown` and `ProviderCostSummary` models backed by `Decimal`, not `Double`.
- Add estimated cost fields to `UsageSession`, `DailyUsageAggregate`, and `UsageSnapshot`:
  - session-level total and token-category subtotals
  - day-level totals and provider totals
  - snapshot-level total and provider totals
- Keep all cost fields optional until pricing succeeds, so unpriced sessions do not force fake values.

### 2. Parse additional Codex metadata

Update [CodexSessionParser.swift](/Users/mac/Vova/Projects/tokens-widget/Sources/TokenUsageCore/Parsing/CodexSessionParser.swift).

- Continue using the final `token_count` snapshot for token totals.
- Parse `turn_context.payload.effort` when present.
- Fallback to `turn_context.payload.collaboration_mode.settings.reasoning_effort` if `effort` is absent.
- Continue parsing the session model from `session_meta` and prefer a later `turn_context.payload.model` if one is present.
- Do not infer `fast mode` unless the log contains an explicit signal in the future.
- Store a note such as `fast_mode_not_detected` only if a multiplier-capable pricing rule exists but no explicit fast flag is available.

### 3. Parse additional Claude metadata

Update [ClaudeSessionParser.swift](/Users/mac/Vova/Projects/tokens-widget/Sources/TokenUsageCore/Parsing/ClaudeSessionParser.swift).

- Preserve the current total token behavior.
- Stop collapsing cache reads and cache writes into one pricing bucket.
- Parse and store:
  - `cache_read_input_tokens`
  - `cache_creation_input_tokens`
  - `cache_creation.ephemeral_5m_input_tokens`
  - `cache_creation.ephemeral_1h_input_tokens`
  - `speed`
  - `service_tier`
- Keep `cachedInputTokens` as `cache_read_input_tokens + cache_creation_input_tokens` for compatibility with the existing token heatmap.
- If more than one Claude model appears in a single session, mark the session as `mixed_model_unpriced` in `pricingNotes` and do not assign a cost in v1.

### 4. Add a pricing engine

Create a new pricing layer under `Sources/TokenUsageCore/Pricing/`.

- Add `PricingCatalog.swift` with versioned provider/model rate tables and a `lastReviewedAt` date.
- Add `UsageCostEstimator.swift` that accepts a `UsageSession` and returns a `CostBreakdown?`.
- Keep rate tables local and typed in Swift for v1. This app is offline-first and already reads local logs, so a bundled catalog is simpler than a remote pricing fetch.

#### Codex calculation rules

Use the token-based rates derived from the published Codex/OpenAI pricing alignment.

- Billable uncached input tokens = `inputTokens - cachedInputTokens`
- Billable cached input tokens = `cachedInputTokens`
- Billable output tokens = `outputTokens + reasoningTokens`
- Reasoning tokens should be displayed as a separate line item in the breakdown, but charged at the output-token rate
- If a future explicit Codex fast-mode flag is found, apply a `2x` multiplier to the whole session estimate
- If the session model is missing or unsupported, leave the session unpriced and record a pricing note

#### Claude calculation rules

Use the Claude model pricing table with separate cache-read and cache-write rates.

- Billable base input tokens = `inputTokens`
- Cache read tokens use the cache-hit/read rate
- Cache creation tokens use:
  - the 5-minute write rate for `cacheCreation5mTokens`
  - the 1-hour write rate for `cacheCreation1hTokens`
- If `cacheCreationTokens` is present but the 5-minute and 1-hour split is missing, treat the session as `cache_write_split_missing_unpriced`
- Output tokens use the standard output rate
- Record `speed` and `serviceTier` for display and future pricing logic, but do not apply a multiplier in v1 unless a documented rate difference is confirmed for the exact mode stored in logs

### 5. Price sessions during import

Update [UsageImporter.swift](/Users/mac/Vova/Projects/tokens-widget/Sources/TokenUsageCore/Import/UsageImporter.swift).

- After parsing sessions, run each session through `UsageCostEstimator`.
- Aggregate priced session costs into:
  - snapshot total estimated cost
  - snapshot provider totals
  - day-level total estimated cost
  - day-level provider cost totals
- Track:
  - `pricedSessionCount`
  - `unpricedSessionCount`
  - `unpricedReasonSummary` for quick UI notes

### 6. Show the cost card and hover breakdown

Update [RootView.swift](/Users/mac/Vova/Projects/tokens-widget/App/Sources/Views/RootView.swift).

- Add the `Estimated Cost` metric card beside the existing overview cards.
- Extend `MetricCard` to optionally accept hover content.
- Reuse the existing hover style language from [ContributionMatrixView.swift](/Users/mac/Vova/Projects/tokens-widget/SharedUI/ContributionMatrixView.swift) so the tooltip feels consistent with the matrix.
- Hover content for the cost card should include:
  - total priced Codex cost
  - total priced Claude cost
  - per-provider `Input`, `Cached`, `Output` subtotals
  - an `Unpriced sessions: N` line only when `N > 0`
  - one short caveat line about local-estimate accuracy

## Pricing Catalog For V1

Freeze the first implementation to the pricing tables reviewed on `2026-04-05`, and store the review date in code so future updates are obvious.

- Codex/OpenAI:
  - GPT-5.4: input `$2.50 / 1M`, cached input `$0.25 / 1M`, output `$15.00 / 1M`
  - GPT-5.4 mini: input `$0.75 / 1M`, cached input `$0.075 / 1M`, output `$4.50 / 1M`
  - GPT-5.3-Codex and GPT-5.2 family: map from the published Codex token-based rate card to USD and encode explicitly in the catalog
- Claude:
  - Claude Sonnet 4.6: base input `$3 / 1M`, cache read `$0.30 / 1M`, 5-minute cache write `$3.75 / 1M`, 1-hour cache write `$6 / 1M`, output `$15 / 1M`
  - Add only the Claude models we can confidently support from published docs and observed logs; unsupported models remain unpriced

## Testing Plan

Update [TokenUsageCoreTests.swift](/Users/mac/Vova/Projects/tokens-widget/Tests/TokenUsageCoreTests/TokenUsageCoreTests.swift) and add focused pricing tests.

- Codex parser test:
  - parses `reasoningEffort`
  - preserves `cachedInputTokens`
  - keeps final token snapshot behavior unchanged
- Claude parser test:
  - parses `speed` and `serviceTier`
  - preserves cache read vs cache creation vs 5-minute/1-hour split
- Cost estimator test for Codex:
  - validates `input - cached`, `cached`, and `output + reasoning` pricing
  - validates unsupported-model behavior
- Cost estimator test for Claude:
  - validates read/write cache pricing
  - validates unpriced behavior when cache-write split is incomplete
  - validates mixed-model session behavior
- Importer aggregation test:
  - validates snapshot total estimated cost
  - validates provider split
  - validates unpriced session counters

## Scope Boundaries

- Do not show invoice-style wording such as `Amount Spent`.
- Do not fetch live pricing from the network in v1.
- Do not expand the heatmap tooltip to include cost in v1.
- Do not guess Codex fast mode when no explicit log field is present.
- Do not guess mixed-model session pricing.

## Assumptions

- The app should optimize for honest estimates over pretending to have exact billing data.
- The top-level cost card is the only new UI surface needed in v1.
- Thinking level matters only where the local logs expose it; Codex supports this now, Claude speed is available, but Claude thinking level is not clearly exposed in the current local transcript format.

## Source References

- OpenAI Codex rate card: https://help.openai.com/en/articles/20001106-codex-rate-card
- OpenAI API pricing: https://openai.com/api/pricing/
- OpenAI Codex plan/local-usage notes: https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan
- Anthropic Claude pricing: https://platform.claude.com/docs/en/about-claude/pricing
- Anthropic Claude Code costs and `/cost`: https://code.claude.com/docs/en/costs
