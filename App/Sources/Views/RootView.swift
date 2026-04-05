import SwiftUI
import TokenUsageCore

struct RootView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ZStack {
            UsageTheme.backgroundGradient
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    sourcesSection
                    if let snapshot = viewModel.snapshot {
                        summarySection(snapshot)
                        matrixSection(snapshot)
                    } else {
                        emptyState
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task {
            viewModel.bootstrapIfNeeded()
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Token Usage Matrix")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(UsageTheme.App.heroTitle)

                    Text("A native macOS heatmap for Codex and Claude Code activity, built to feel at home next to GitHub's contribution graph.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(UsageTheme.App.secondaryText)
                        .frame(maxWidth: 700, alignment: .leading)
                }

                Spacer(minLength: 24)

                Button {
                    viewModel.refresh()
                } label: {
                    Label(viewModel.isRefreshing ? "Refreshing..." : "Refresh Data", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.hasConnectedSources || viewModel.isRefreshing)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(UsageTheme.App.errorText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(UsageTheme.App.elevatedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connected Sources")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(UsageTheme.App.primaryText)

            HStack(spacing: 16) {
                ForEach(viewModel.connectionStates) { state in
                    SourceCard(
                        state: state,
                        onConnect: { viewModel.connect(state.source) },
                        onDisconnect: { viewModel.disconnect(state.source) }
                    )
                }
            }
        }
    }

    private func summarySection(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Overview")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(UsageTheme.App.primaryText)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)],
                alignment: .leading,
                spacing: 16
            ) {
                MetricCard(
                    title: "Total Tokens Imported",
                    value: snapshot.totalTokens.formatted(),
                    detail: "All tokens parsed from the connected Codex and Claude folders.",
                    systemImage: "number.square.fill"
                )
                MetricCard(
                    title: "Sessions Parsed",
                    value: snapshot.totalSessions.formatted(),
                    detail: "The number of individual usage sessions included in this snapshot.",
                    systemImage: "rectangle.stack.person.crop.fill"
                )
                MetricCard(
                    title: "Most Recent Activity",
                    value: snapshot.latestActivityAt?.formatted(date: .abbreviated, time: .shortened) ?? "No data",
                    detail: "The latest session timestamp found during the last import.",
                    systemImage: "clock.fill"
                )
                MetricCard(
                    title: "Estimated Cost",
                    value: formattedCurrency(snapshot.estimatedCost, unavailableText: "Unavailable"),
                    detail: "Estimated from local tokens and published pricing tables.",
                    systemImage: "dollarsign.circle.fill",
                    hoverContent: AnyView(costHoverContent(snapshot))
                )
            }
        }
    }

    private func matrixSection(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Heatmap")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(UsageTheme.App.primaryText)

            VStack(alignment: .leading, spacing: 14) {
                ContributionMatrixView(
                    dailyTotals: snapshot.dailyTotals,
                    weeks: 30,
                    cellSize: 13,
                    cellSpacing: 4,
                    showMonthLabels: true,
                    showsHoverTooltip: true
                )

                Text("Intensity scales to the busiest day in the currently imported snapshot.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(UsageTheme.App.tertiaryText)
            }
            .padding(18)
            .background(UsageTheme.App.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Usage Imported Yet", systemImage: "rectangle.grid.1x2")
        } description: {
            Text("Connect your Codex and Claude Code folders, then refresh to populate the widget data.")
        } actions: {
            HStack {
                Button("Connect Codex") {
                    viewModel.connect(.codex)
                }

                Button("Connect Claude Code") {
                    viewModel.connect(.claude)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .background(UsageTheme.App.emptyStateBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct SourceCard: View {
    let state: SourceConnectionState
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(state.source.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(UsageTheme.App.primaryText)

                Spacer()

                Circle()
                    .fill(state.isConnected ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 10, height: 10)
            }

            Text(state.resolvedURL?.path ?? state.source.sourceHint)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(UsageTheme.App.tertiaryText)
                .lineLimit(2)

            HStack {
                Button(state.isConnected ? "Reconnect" : "Connect", action: onConnect)
                    .buttonStyle(.borderedProminent)

                if state.isConnected {
                    Button("Disconnect", action: onDisconnect)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(UsageTheme.App.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let hoverContent: AnyView?

    @State private var isHovering = false

    init(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        hoverContent: AnyView? = nil
    ) {
        self.title = title
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
        self.hoverContent = hoverContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(UsageTheme.App.secondaryText)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(UsageTheme.App.primaryText)

            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(UsageTheme.App.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(UsageTheme.App.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topLeading) {
            if isHovering, let hoverContent {
                UsageTooltipSurface {
                    hoverContent
                }
                .offset(x: 12, y: -12)
                .allowsHitTesting(false)
            }
        }
        .onHover { hovering in
            guard hoverContent != nil else { return }
            isHovering = hovering
        }
        .zIndex(isHovering ? 1 : 0)
    }
}

private struct UsageTooltipSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 14, y: 6)
            .fixedSize()
    }
}

private extension RootView {
    @ViewBuilder
    func costHoverContent(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(UsageProvider.allCases, id: \.self) { provider in
                let summary = snapshot.providerCostTotals[provider] ?? .zero

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text(providerDisplayName(provider))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(UsageTheme.App.primaryText)

                        Spacer(minLength: 16)

                        Text(formattedCurrency(summary.totalCost))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(UsageTheme.App.primaryText)
                    }

                    Text(
                        "Input \(formattedCurrency(summary.inputCost))  Cached \(formattedCurrency(summary.cachedInputCost))  Output \(formattedCurrency(summary.displayedOutputCost))"
                    )
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(UsageTheme.App.tertiaryText)
                }
            }

            if snapshot.unpricedSessionCount > 0 {
                Divider()

                Text("Unpriced sessions: \(snapshot.unpricedSessionCount.formatted())")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(UsageTheme.App.primaryText)

                if let skippedSummary = skippedSummaryText(from: snapshot.unpricedReasonSummary) {
                    Text(skippedSummary)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(UsageTheme.App.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 260, alignment: .leading)
                }
            }

            Divider()

            Text("Local estimate only. Final billing can differ by plan, mode, and provider-side adjustments.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(UsageTheme.App.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 260, alignment: .leading)
        }
        .frame(width: 280, alignment: .leading)
    }

    func providerDisplayName(_ provider: UsageProvider) -> String {
        switch provider {
        case .codex:
            return "Codex"
        case .claudeCode:
            return "Claude Code"
        }
    }

    func skippedSummaryText(from reasons: [String: Int]) -> String? {
        let orderedReasons = [
            "mixed_model_unpriced",
            "model_missing_unpriced",
            "unsupported_model_unpriced",
            "cache_write_split_missing_unpriced"
        ]

        let parts = orderedReasons.compactMap { reason -> String? in
            guard let count = reasons[reason], count > 0 else {
                return nil
            }

            switch reason {
            case "mixed_model_unpriced":
                return "\(count.formatted()) mixed-model"
            case "model_missing_unpriced":
                return "\(count.formatted()) missing model"
            case "unsupported_model_unpriced":
                return "\(count.formatted()) unsupported model"
            case "cache_write_split_missing_unpriced":
                return "\(count.formatted()) missing cache split"
            default:
                return nil
            }
        }

        guard !parts.isEmpty else {
            return nil
        }

        return "Skipped: \(parts.joined(separator: ", "))."
    }
}

private func formattedCurrency(_ amount: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.currencySymbol = "$"
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
}

private func formattedCurrency(_ amount: Decimal?, unavailableText: String) -> String {
    guard let amount else {
        return unavailableText
    }

    return formattedCurrency(amount)
}
