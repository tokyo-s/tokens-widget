import SwiftUI
import TokenUsageCore

struct ContributionMatrixView: View {
    let dailyTotals: [DailyUsageAggregate]
    var weeks: Int = 26
    var cellSize: CGFloat = 12
    var cellSpacing: CGFloat = 4
    var showMonthLabels: Bool = true
    var showsHoverTooltip: Bool = false
    var style: ContributionMatrixStyle = UsageTheme.Matrix.app

    @State private var hoveredCellID: String?
    @State private var hoveredMonthKey: String?

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

    private var monthAggregates: [String: (tokens: Int, cost: Decimal?)] {
        var result: [String: (tokens: Int, cost: Decimal?)] = [:]
        for column in columns {
            for cell in column.cells {
                let key = monthKey(for: cell.date)
                guard !cell.isFuture else { continue }
                let aggregate = totalsByDay[cell.date]
                var existing = result[key, default: (tokens: 0, cost: Decimal(0))]
                existing.tokens += cell.tokens
                if let dayCost = aggregate?.estimatedCost {
                    existing.cost = (existing.cost ?? 0) + dayCost
                }
                result[key] = existing
            }
        }
        return result
    }

    private func monthKey(for date: Date) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return "\(year)-\(month)"
    }

    private func monthTooltip(for key: String) -> String {
        guard let agg = monthAggregates[key] else { return "" }
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else { return "" }

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let label = calendar.date(from: comps)?
            .formatted(.dateTime.month(.wide).year()) ?? key

        let tokensLine = "\(label): \(agg.tokens.formatted()) \(agg.tokens == 1 ? "token" : "tokens")"
        let costLine: String
        if let cost = agg.cost {
            costLine = "Estimated Cost: \(matrixFormattedCurrency(cost))"
        } else {
            costLine = "Estimated Cost: \(matrixFormattedCurrency(.zero))"
        }
        return "\(tokensLine)\n\(costLine)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showMonthLabels {
                HStack(alignment: .bottom, spacing: cellSpacing) {
                    ForEach(columns) { column in
                        ZStack(alignment: .leading) {
                            if let monthLabel = column.monthLabel,
                               let firstDate = column.firstDate {
                                let key = monthKey(for: firstDate)
                                Text(monthLabel)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(style.monthLabelColor)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .contentShape(Rectangle())
                                    .anchorPreference(key: MatrixCellBoundsPreferenceKey.self, value: .bounds) {
                                        [key: $0]
                                    }
                                    .onHover { isHovering in
                                        guard showsHoverTooltip else { return }
                                        if isHovering {
                                            hoveredMonthKey = key
                                        } else if hoveredMonthKey == key {
                                            hoveredMonthKey = nil
                                        }
                                    }
                            }
                        }
                        .frame(width: cellSize, alignment: .leading)
                    }
                }
            }

            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(columns) { column in
                    VStack(spacing: cellSpacing) {
                        ForEach(column.cells) { cell in
                            cellView(for: cell)
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

                    MatrixTooltipView(text: tooltip(for: hoveredCell), style: style)
                        .offset(x: rect.maxX, y: rect.minY - 30)
                        .allowsHitTesting(false)
                }

                if
                    showsHoverTooltip,
                    let hoveredMonthKey,
                    let bounds = boundsByID[hoveredMonthKey]
                {
                    let rect = proxy[bounds]

                    MatrixTooltipView(text: monthTooltip(for: hoveredMonthKey), style: style)
                        .offset(x: rect.maxX, y: rect.minY - 30)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func appearance(for cell: MatrixCell) -> ContributionMatrixCellAppearance {
        let normalized = Double(cell.tokens) / Double(maxTokens)
        return style.appearance(for: normalized, isFuture: cell.isFuture)
    }

    @ViewBuilder
    private func cellView(for cell: MatrixCell) -> some View {
        let appearance = appearance(for: cell)
        let cellBody = RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(appearance.fillColor)
            .frame(width: cellSize, height: cellSize)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(appearance.borderColor, lineWidth: style.cellBorderWidth)
            }
            .scaleEffect(appearance.scale)
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

        if style.accentBySystem {
            cellBody.widgetAccentable()
        } else {
            cellBody
        }
    }

    private func tooltip(for cell: MatrixCell) -> String {
        let day = cell.date.formatted(date: .long, time: .omitted)
        let aggregate = totalsByDay[cell.date]

        if cell.isFuture {
            return "\(day): not included in this snapshot yet"
        }

        let tokensLine = "\(day): \(cell.tokens.formatted()) \(cell.tokens == 1 ? "token" : "tokens")"
        let costLine: String

        if let estimatedCost = aggregate?.estimatedCost {
            costLine = "Estimated Cost: \(matrixFormattedCurrency(estimatedCost))"
        } else if aggregate == nil {
            costLine = "Estimated Cost: \(matrixFormattedCurrency(.zero))"
        } else {
            costLine = "Estimated Cost: Unavailable"
        }

        return "\(tokensLine)\n\(costLine)"
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
    let style: ContributionMatrixStyle

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(style.tooltipTextColor)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(style.tooltipBackgroundColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(style.tooltipBorderColor, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 14, y: 6)
            .fixedSize()
            .padding(4)
    }
}

private func matrixFormattedCurrency(_ amount: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.currencySymbol = "$"
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
}

private struct MatrixCellBoundsPreferenceKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
