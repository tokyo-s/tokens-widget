# TokensWidget

Native macOS app and desktop widget for visualizing Codex and Claude Code token usage as a GitHub-style contribution matrix.

## What is in the repo

- `Sources/TokenUsageCore/`: shared parsing and aggregation logic for Codex and Claude Code local transcripts
- `App/Sources/`: SwiftUI macOS app with permission onboarding and refresh flow
- `Widget/Sources/`: WidgetKit extension that renders the shared snapshot
- `SharedUI/`: app/widget shared storage and the matrix UI
- `project.yml`: XcodeGen spec for the macOS app + widget project

## Current data model

- Codex: reads the final `token_count` snapshot from each session in `~/.codex/sessions/**/*.jsonl`
- Claude Code: sums assistant `usage` blocks from `~/.claude/projects/**/*.jsonl`
- Shared snapshot: writes a JSON snapshot into the App Group container for the widget to read

## Setup

1. Install Xcode and make sure the full app is selected:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

2. Install XcodeGen if needed:

```sh
brew install xcodegen
```

3. Generate the Xcode project:

```sh
./scripts/generate-project.sh
```

4. Open `TokensWidget.xcodeproj` in Xcode, choose your signing team, and update the bundle identifiers and App Group if you want your own production identifiers.

5. Run the macOS app once, connect `~/.codex` and `~/.claude`, then add the widget from the macOS widget gallery.

## Notes

- The app intentionally asks for folder permission via `NSOpenPanel` and stores security-scoped bookmarks.
- The current widget is macOS-only.
- The shared Swift package builds from the command line with `swift build`.
- Command-line tests require the full Xcode toolchain to be installed and selected before `swift test` will work.
