import SwiftUI
import TokenUsageCore

struct ContributionMatrixView: View {
    let dailyTotals: [DailyUsageAggregate]
    var weeks: Int = 26
    var cellSize: CGFloat = 12
    var cellSpacing: CGFloat = 4
    var showMonthLabels: Bool = true
    var showsHoverTooltip: Bool = false

    @State private var hoveredCellID: String?

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        return calendar
    }()

    private var latestTrackedDate: Date {
        calendar.startOfDay(for: dailyTotals.map(\.date).max() ?? Date())
    }

    private var totalsByDay: [Date: DailyUsageAggregate] {
        Dictionary(uniqueKeysWithValues: dailyTotals.map { (calendar.startOfDay(for: $0.date), $0) })
    }

    private var maxTokens: Int {
        max(dailyTotals.map(\.totalTokens).max() ?? 1, 1)
    }

    private var columns: [MatrixColumn] {
        let endOfLatestWeek = startOfWeek(for: latestTrackedDate)
        let start = calendar.date(byAdding: .day, value: -((weeks - 1) * 7), to: endOfLatestWeek) ?? latestTrackedDate
        var previousMonth: Int?

        return (0..<weeks).map { weekOffset in
            let startOfColumn = calendar.date(byAdding: .day, value: weekOffset * 7, to: start) ?? start
            let month = calendar.component(.month, from: startOfColumn)
            let monthLabel = (weekOffset == 0 || month != previousMonth)
                ? startOfColumn.formatted(.dateTime.month(.abbreviated))
                : nil
            previousMonth = month

            return MatrixColumn(
                id: weekOffset,
                monthLabel: monthLabel,
                cells: (0..<7).compactMap { dayOffset in
                    guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfColumn) else {
                        return nil
                    }

                    let normalizedDate = calendar.startOfDay(for: date)
                    let aggregate = totalsByDay[normalizedDate]
                    return MatrixCell(
                        date: normalizedDate,
                        tokens: aggregate?.totalTokens ?? 0,
                        isFuture: normalizedDate > latestTrackedDate
                    )
                }
            )
        }
    }

    private var cellsByID: [String: MatrixCell] {
        Dictionary(uniqueKeysWithValues: columns.flatMap(\.cells).map { ($0.id, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showMonthLabels {
                HStack(alignment: .bottom, spacing: cellSpacing) {
                    ForEach(columns) { column in
                        Text(column.monthLabel ?? "")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: cellSize, alignment: .leading)
                    }
                }
            }

            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(columns) { column in
                    VStack(spacing: cellSpacing) {
                        ForEach(column.cells) { cell in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(color(for: cell))
                                .frame(width: cellSize, height: cellSize)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                                }
                                .accessibilityLabel(tooltip(for: cell))
                                .contentShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                .anchorPreference(key: MatrixCellBoundsPreferenceKey.self, value: .bounds) {
                                    [cell.id: $0]
                                }
                                .onHover { isHovering in
                                    guard showsHoverTooltip else { return }

                                    if isHovering {
                                        hoveredCellID = cell.id
                                    } else if hoveredCellID == cell.id {
                                        hoveredCellID = nil
                                    }
                                }
                        }
                    }
                }
            }
        }
        .overlayPreferenceValue(MatrixCellBoundsPreferenceKey.self) { boundsByID in
            GeometryReader { proxy in
                if
                    showsHoverTooltip,
                    let hoveredCellID,
                    let hoveredCell = cellsByID[hoveredCellID],
                    let bounds = boundsByID[hoveredCellID]
                {
                    let rect = proxy[bounds]

                    MatrixTooltipView(text: tooltip(for: hoveredCell))
                        .offset(x: rect.maxX, y: rect.minY - 30)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func color(for cell: MatrixCell) -> Color {
        if cell.isFuture {
            return Color.white.opacity(0.3)
        }

        let normalized = Double(cell.tokens) / Double(maxTokens)

        switch normalized {
        case ..<0.01:
            return Color(red: 0.90, green: 0.94, blue: 0.92)
        case ..<0.25:
            return Color(red: 0.70, green: 0.85, blue: 0.67)
        case ..<0.5:
            return Color(red: 0.39, green: 0.73, blue: 0.47)
        case ..<0.75:
            return Color(red: 0.18, green: 0.58, blue: 0.32)
        default:
            return Color(red: 0.05, green: 0.33, blue: 0.16)
        }
    }

    private func tooltip(for cell: MatrixCell) -> String {
        let day = cell.date.formatted(date: .long, time: .omitted)

        if cell.isFuture {
            return "\(day): not included in this snapshot yet"
        }

        return "\(day): \(cell.tokens.formatted()) \(cell.tokens == 1 ? "token" : "tokens")"
    }

    private func startOfWeek(for date: Date) -> Date {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return date
        }

        return interval.start
    }
}

private struct MatrixColumn: Identifiable {
    let id: Int
    let monthLabel: String?
    let cells: [MatrixCell]

    var firstDate: Date? {
        cells.first?.date
    }
}

private struct MatrixCell: Identifiable {
    let date: Date
    let tokens: Int
    let isFuture: Bool

    var id: String {
        date.formatted(.iso8601.year().month().day())
    }
}

private struct MatrixTooltipView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Color(red: 0.10, green: 0.24, blue: 0.16))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 14, y: 6)
            .fixedSize()
            .padding(4)
    }
}

private struct MatrixCellBoundsPreferenceKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
