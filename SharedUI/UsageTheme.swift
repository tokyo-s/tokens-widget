import SwiftUI
import WidgetKit

struct ContributionMatrixCellAppearance {
    let fillColor: Color
    let borderColor: Color
    let scale: CGFloat
}

struct ContributionMatrixStyle {
    let monthLabelColor: Color
    let cellBorderColor: Color
    let cellBorderWidth: CGFloat
    let futureCellColor: Color
    let futureCellBorderColor: Color
    let intensityColors: [Color]
    let intensityScales: [CGFloat]
    let tooltipTextColor: Color
    let tooltipBackgroundColor: Color
    let tooltipBorderColor: Color
    let accentBySystem: Bool

    func appearance(for normalizedIntensity: Double, isFuture: Bool) -> ContributionMatrixCellAppearance {
        if isFuture {
            return ContributionMatrixCellAppearance(
                fillColor: futureCellColor,
                borderColor: futureCellBorderColor,
                scale: 0.9
            )
        }

        let levelIndex = Self.levelIndex(for: normalizedIntensity)
        return ContributionMatrixCellAppearance(
            fillColor: intensityColors[levelIndex],
            borderColor: cellBorderColor,
            scale: intensityScales[levelIndex]
        )
    }

    func color(for normalizedIntensity: Double, isFuture: Bool) -> Color {
        appearance(for: normalizedIntensity, isFuture: isFuture).fillColor
    }

    private static func levelIndex(for normalizedIntensity: Double) -> Int {
        switch normalizedIntensity {
        case ..<0.01:
            return 0
        case ..<0.25:
            return 1
        case ..<0.5:
            return 2
        case ..<0.75:
            return 3
        default:
            return 4
        }
    }
}

struct UsageWidgetPresentation {
    let renderingMode: WidgetRenderingMode
    let showsContainerBackground: Bool

    var debugDescription: String {
        "Mode: \(renderingModeLabel) | Background: \(showsContainerBackground ? "shown" : "removed")"
    }

    private var renderingModeLabel: String {
        if renderingMode == .accented {
            return "accented"
        }

        if renderingMode == .vibrant {
            return "vibrant"
        }

        return "fullColor"
    }
}

struct UsageWidgetPalette {
    let containerBackground: LinearGradient?
    let labelColor: Color
    let valueColor: Color
    let timestampColor: Color
    let matrixStyle: ContributionMatrixStyle
    let accentPrimaryContent: Bool
}

enum UsageTheme {
    enum App {
        static let backgroundTop = Color(red: 0.96, green: 0.98, blue: 0.97)
        static let backgroundBottom = Color(red: 0.90, green: 0.95, blue: 0.91)
        static let heroTitle = Color(red: 0.09, green: 0.22, blue: 0.15)
        static let primaryText = Color(red: 0.10, green: 0.24, blue: 0.16)
        static let secondaryText = Color(red: 0.18, green: 0.33, blue: 0.24)
        static let tertiaryText = Color(red: 0.31, green: 0.42, blue: 0.35)
        static let errorText = Color(red: 0.55, green: 0.12, blue: 0.12)
        static let cardBackground = Color.white.opacity(0.86)
        static let elevatedBackground = Color.white.opacity(0.88)
        static let emptyStateBackground = Color.white.opacity(0.75)
    }

    enum Matrix {
        static let app = ContributionMatrixStyle(
            monthLabelColor: App.tertiaryText,
            cellBorderColor: Color.black.opacity(0.06),
            cellBorderWidth: 0.5,
            futureCellColor: Color.white.opacity(0.3),
            futureCellBorderColor: Color.black.opacity(0.03),
            intensityColors: [
                Color(red: 0.90, green: 0.94, blue: 0.92),
                Color(red: 0.70, green: 0.85, blue: 0.67),
                Color(red: 0.39, green: 0.73, blue: 0.47),
                Color(red: 0.18, green: 0.58, blue: 0.32),
                Color(red: 0.05, green: 0.33, blue: 0.16)
            ],
            intensityScales: [1, 1, 1, 1, 1],
            tooltipTextColor: App.primaryText,
            tooltipBackgroundColor: Color.white.opacity(0.96),
            tooltipBorderColor: Color.black.opacity(0.08),
            accentBySystem: false
        )

        static let accentedWidget = ContributionMatrixStyle(
            monthLabelColor: .secondary,
            cellBorderColor: Color.white.opacity(0.12),
            cellBorderWidth: 0.65,
            futureCellColor: Color.white.opacity(0.08),
            futureCellBorderColor: Color.white.opacity(0.10),
            intensityColors: [
                Color.white.opacity(0.16),
                Color.white.opacity(0.30),
                Color.white.opacity(0.48),
                Color.white.opacity(0.70),
                Color.white.opacity(0.96)
            ],
            intensityScales: [1, 1, 1, 1, 1],
            tooltipTextColor: Color.white.opacity(0.92),
            tooltipBackgroundColor: Color.black.opacity(0.72),
            tooltipBorderColor: Color.white.opacity(0.12),
            accentBySystem: true
        )

        static let desktopGlass = ContributionMatrixStyle(
            monthLabelColor: Color.white.opacity(0.66),
            cellBorderColor: Color.white.opacity(0.08),
            cellBorderWidth: 0.5,
            futureCellColor: Color.clear,
            futureCellBorderColor: Color.white.opacity(0.06),
            intensityColors: [
                Color.white.opacity(0.04),
                Color.white.opacity(0.18),
                Color.white.opacity(0.40),
                Color.white.opacity(0.65),
                Color.white.opacity(0.92)
            ],
            intensityScales: [0.80, 0.90, 0.96, 1.0, 1.06],
            tooltipTextColor: Color.white.opacity(0.92),
            tooltipBackgroundColor: Color.black.opacity(0.78),
            tooltipBorderColor: Color.white.opacity(0.12),
            accentBySystem: false
        )
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [App.backgroundTop, App.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func widgetPalette(for presentation: UsageWidgetPresentation) -> UsageWidgetPalette {
        if !presentation.showsContainerBackground || presentation.renderingMode == .vibrant {
            return UsageWidgetPalette(
                containerBackground: nil,
                labelColor: Color.white.opacity(0.72),
                valueColor: Color.white.opacity(0.98),
                timestampColor: Color.white.opacity(0.66),
                matrixStyle: Matrix.desktopGlass,
                accentPrimaryContent: false
            )
        }

        if presentation.renderingMode == .accented {
            return UsageWidgetPalette(
                containerBackground: backgroundGradient,
                labelColor: .secondary,
                valueColor: App.primaryText,
                timestampColor: .secondary,
                matrixStyle: Matrix.accentedWidget,
                accentPrimaryContent: true
            )
        }

        return UsageWidgetPalette(
            containerBackground: backgroundGradient,
            labelColor: .secondary,
            valueColor: App.primaryText,
            timestampColor: .secondary,
            matrixStyle: Matrix.app,
            accentPrimaryContent: false
        )
    }

    static func widgetPalette(for renderingMode: WidgetRenderingMode) -> UsageWidgetPalette {
        widgetPalette(
            for: UsageWidgetPresentation(
                renderingMode: renderingMode,
                showsContainerBackground: true
            )
        )
    }
}
