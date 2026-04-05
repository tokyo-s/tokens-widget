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
    var previewPresentation: UsageWidgetPresentation?

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground

    private var presentation: UsageWidgetPresentation {
        previewPresentation ?? UsageWidgetPresentation(
            renderingMode: widgetRenderingMode,
            showsContainerBackground: showsWidgetContainerBackground
        )
    }

    private var palette: UsageWidgetPalette {
        UsageTheme.widgetPalette(for: presentation)
    }

    @ViewBuilder
    var body: some View {
        if let containerBackground = palette.containerBackground {
            content
                .containerBackground(containerBackground, for: .widget)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                metricColumn(title: "Tokens", value: entry.snapshot.totalTokens.formatted(), alignment: .leading)

                Spacer()

                metricColumn(title: "Sessions", value: entry.snapshot.totalSessions.formatted(), alignment: .trailing)
            }

            ContributionMatrixView(
                dailyTotals: entry.snapshot.dailyTotals,
                weeks: 18,
                cellSize: 9,
                cellSpacing: 3,
                showMonthLabels: false,
                style: palette.matrixStyle
            )

            presentationDebugFooter
        }
        .padding(16)
    }

    @ViewBuilder
    private func metricColumn(title: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.labelColor)

            if palette.accentPrimaryContent {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.valueColor)
                    .widgetAccentable()
            } else {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.valueColor)
            }
        }
    }

    @ViewBuilder
    private var presentationDebugFooter: some View {
        #if DEBUG
        Text(presentation.debugDescription)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.timestampColor)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        #else
        EmptyView()
        #endif
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
        .containerBackgroundRemovable(true)
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct TokensUsageWidgetPreviewCard: View {
    let presentation: UsageWidgetPresentation

    private let entry = TokensUsageEntry(date: .now, snapshot: .preview())

    private var showsGlassSurface: Bool {
        UsageTheme.widgetPalette(for: presentation).containerBackground == nil
    }

    var body: some View {
        ZStack {
            if showsGlassSurface {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.15, blue: 0.13),
                                Color(red: 0.18, green: 0.22, blue: 0.19)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.22), radius: 16, y: 10)
            }

            TokensUsageWidgetEntryView(
                entry: entry,
                previewPresentation: presentation
            )
            .environment(\.widgetRenderingMode, presentation.renderingMode)
            .frame(width: 360, height: 170)
        }
        .padding(18)
        .background(Color(red: 0.08, green: 0.10, blue: 0.09))
    }
}

#Preview("Widget Full Color") {
    TokensUsageWidgetPreviewCard(
        presentation: UsageWidgetPresentation(
            renderingMode: .fullColor,
            showsContainerBackground: true
        )
    )
}

#Preview("Widget Accented") {
    TokensUsageWidgetPreviewCard(
        presentation: UsageWidgetPresentation(
            renderingMode: .accented,
            showsContainerBackground: true
        )
    )
}

#Preview("Widget Background Removed") {
    TokensUsageWidgetPreviewCard(
        presentation: UsageWidgetPresentation(
            renderingMode: .fullColor,
            showsContainerBackground: false
        )
    )
}

#Preview("Widget Vibrant") {
    TokensUsageWidgetPreviewCard(
        presentation: UsageWidgetPresentation(
            renderingMode: .vibrant,
            showsContainerBackground: false
        )
    )
}
