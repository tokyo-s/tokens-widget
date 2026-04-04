import Foundation

enum TrackedSource: String, CaseIterable, Identifiable {
    case codex
    case claude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex:
            return "Codex"
        case .claude:
            return "Claude Code"
        }
    }

    var defaultDirectoryURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .codex:
            return home.appendingPathComponent(".codex", isDirectory: true)
        case .claude:
            return home.appendingPathComponent(".claude", isDirectory: true)
        }
    }

    var bookmarkKey: String {
        "bookmark.\(rawValue)"
    }

    var panelPrompt: String {
        switch self {
        case .codex:
            return "Grant access to your Codex data folder (.codex)"
        case .claude:
            return "Grant access to your Claude Code data folder (.claude)"
        }
    }

    var panelMessage: String {
        switch self {
        case .codex:
            return "Choose your .codex folder so the app can import local session usage."
        case .claude:
            return "Choose your .claude folder so the app can import local Claude Code usage."
        }
    }

    var sourceHint: String {
        switch self {
        case .codex:
            return "~/.codex"
        case .claude:
            return "~/.claude"
        }
    }
}

struct SourceConnectionState: Identifiable {
    let source: TrackedSource
    let resolvedURL: URL?

    var id: TrackedSource { source }

    var isConnected: Bool {
        resolvedURL != nil
    }
}
