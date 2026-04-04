import SwiftUI
import TokenUsageCore
import WidgetKit

struct TokensUsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct TokensUsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> TokensUsageEntry {
        TokensUsageEntry(date: .now, snapshot: .preview())
    }

    func getSnapshot(in context: Context, completion: @escaping (TokensUsageEntry) -> Void) {
        completion(TokensUsageEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TokensUsageEntry>) -> Void) {
        let entry = TokensUsageEntry(date: .now, snapshot: loadSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSnapshot() -> UsageSnapshot {
        (try? SharedSnapshotStore().load()) ?? .preview()
    }
}

struct TokensUsageWidgetEntryView: View {
    var entry: TokensUsageProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tokens")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(entry.snapshot.totalTokens.formatted())
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.10, green: 0.24, blue: 0.16))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Sessions")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(entry.snapshot.totalSessions.formatted())
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.10, green: 0.24, blue: 0.16))
                }
            }

            ContributionMatrixView(
                dailyTotals: entry.snapshot.dailyTotals,
                weeks: 18,
                cellSize: 9,
                cellSpacing: 3,
                showMonthLabels: false
            )

            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .containerBackground(
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.99, blue: 0.97),
                    Color(red: 0.91, green: 0.96, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .widget
        )
    }
}

@main
struct TokensUsageWidget: Widget {
    let kind: String = "TokensUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TokensUsageProvider()) { entry in
            TokensUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Token Usage Matrix")
        .description("A GitHub-style heatmap showing Codex and Claude Code token activity.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
