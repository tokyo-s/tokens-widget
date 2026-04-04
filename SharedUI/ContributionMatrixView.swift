import SwiftUI
import TokenUsageCore

struct ContributionMatrixView: View {
    let dailyTotals: [DailyUsageAggregate]
    var weeks: Int = 26
    var cellSize: CGFloat = 12
    var cellSpacing: CGFloat = 4
    var showMonthLabels: Bool = true

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
                        }
                    }
                }
            }
        }
    }

    private func color(for cell: MatrixCell) -> Color {
        if cell.isFuture {
            return Color.white.opacity(0.3)
        }

        let maxTokens = max(dailyTotals.map(\.totalTokens).max() ?? 1, 1)
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
