# Widget Color Handoff

## Goal

Make the live macOS widget feel visually consistent with the app's green heatmap theme.

## Current State

- Shared theme tokens were already added and are compiling:
  - `SharedUI/UsageTheme.swift`
  - `SharedUI/ContributionMatrixView.swift`
  - `Widget/Sources/TokensUsageWidget.swift`
  - `App/Sources/Views/RootView.swift`
- The project builds successfully with:
  - `xcodebuild build -scheme TokensWidget -project TokensWidget.xcodeproj CODE_SIGNING_ALLOWED=NO`
- The widget gallery preview can show the green palette correctly.
- The live desktop widget still looks pale/white.

## What The Screenshot Suggests

This now looks like a WidgetKit presentation-mode issue, not a simple wrong-color bug.

Most likely:

- the live desktop widget is not rendering in the same mode as the gallery preview
- macOS is removing or replacing the widget background
- the widget content is being rendered in a more monochrome / glass / accented presentation

Relevant platform APIs:

- `widgetRenderingMode`
- `showsWidgetContainerBackground`
- `widgetAccentable()`

## Important Constraint

Do not assume the live desktop widget can always preserve the app's exact green palette.

The likely product direction is:

- use exact app greens in true full-color widget contexts
- use a deliberately designed high-contrast desktop/glass variant when macOS removes the background or tints content

## Next Implementation Plan

1. Instrument the widget to learn the actual live presentation state.
   Add temporary debug output in `TokensUsageWidgetEntryView` for:
   - `widgetRenderingMode`
   - `showsWidgetContainerBackground`

2. Make widget theming depend on both values.
   Extend `UsageTheme.widgetPalette(...)` so it selects palette/layout from:
   - rendering mode
   - whether the container background is shown

3. Add a distinct "desktop glass" palette.
   This palette should not try to force the app greens.
   It should prioritize readability on a dark/translucent background.

4. Update the matrix to communicate intensity without depending only on green.
   In the desktop glass variant, use:
   - opacity
   - stronger borders
   - optional subtle scale or brightness differences between levels

5. Add preview combinations that reflect real platform states.
   At minimum:
   - full color
   - accented
   - background removed

6. Verify on the actual desktop, not just the widget gallery.
   The gallery preview is currently misleading for this issue.

7. Remove temporary debug labels once the live desktop behavior is confirmed.

## Files To Read In Full In A Clean Session

Read these end to end before making changes:

1. `SharedUI/UsageTheme.swift`
2. `Widget/Sources/TokensUsageWidget.swift`
3. `SharedUI/ContributionMatrixView.swift`
4. `App/Sources/Views/RootView.swift`
5. `project.yml`

Optional context if needed:

- `TokensWidget.xcodeproj/project.pbxproj`
- `Config/Widget-Info.plist`

## Suggested First Task In The Next Session

Implement step 1 only:

- read `widgetRenderingMode`
- read `showsWidgetContainerBackground`
- expose them temporarily in the widget UI
- run on the desktop
- confirm the real live widget mode before redesigning the palette

## Suggested Kickoff Prompt

`Read WIDGET_COLOR_HANDOFF.md and the listed files in full, then implement the instrumentation step to show the live widget rendering mode and whether the container background is visible.`
