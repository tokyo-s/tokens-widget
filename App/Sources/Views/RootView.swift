import SwiftUI
import TokenUsageCore

struct RootView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.98, blue: 0.97),
                    Color(red: 0.90, green: 0.95, blue: 0.91)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
                        .foregroundStyle(Color(red: 0.09, green: 0.22, blue: 0.15))

                    Text("A native macOS heatmap for Codex and Claude Code activity, built to feel at home next to GitHub's contribution graph.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
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
                    .foregroundStyle(Color(red: 0.55, green: 0.12, blue: 0.12))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connected Sources")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.24, blue: 0.16))

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
                .foregroundStyle(Color(red: 0.10, green: 0.24, blue: 0.16))

            HStack(spacing: 16) {
                MetricCard(title: "Total Tokens", value: snapshot.totalTokens.formatted())
                MetricCard(title: "Sessions", value: snapshot.totalSessions.formatted())
                MetricCard(
                    title: "Last Activity",
                    value: snapshot.latestActivityAt?.formatted(date: .abbreviated, time: .shortened) ?? "No data"
                )
            }
        }
    }

    private func matrixSection(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Heatmap")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.24, blue: 0.16))

            VStack(alignment: .leading, spacing: 14) {
                ContributionMatrixView(
                    dailyTotals: snapshot.dailyTotals,
                    weeks: 30,
                    cellSize: 13,
                    cellSpacing: 4,
                    showMonthLabels: true
                )

                Text("Intensity scales to the busiest day in the currently imported snapshot.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
                    .foregroundStyle(Color(red: 0.10, green: 0.24, blue: 0.16))

                Spacer()

                Circle()
                    .fill(state.isConnected ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 10, height: 10)
            }

            Text(state.resolvedURL?.path ?? state.source.sourceHint)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
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
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.24, blue: 0.16))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
