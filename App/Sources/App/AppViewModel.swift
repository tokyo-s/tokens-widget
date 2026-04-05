import AppKit
import Foundation
import TokenUsageCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private let bookmarkStore: BookmarkStore
    private let snapshotStore: SharedSnapshotStore
    private let importer: UsageImporter
    private var hasBootstrapped = false

    init(
        bookmarkStore: BookmarkStore = BookmarkStore(),
        snapshotStore: SharedSnapshotStore = SharedSnapshotStore(),
        importer: UsageImporter = UsageImporter()
    ) {
        self.bookmarkStore = bookmarkStore
        self.snapshotStore = snapshotStore
        self.importer = importer
    }

    var connectionStates: [SourceConnectionState] {
        TrackedSource.allCases.map { source in
            SourceConnectionState(source: source, resolvedURL: bookmarkStore.resolvedURL(for: source))
        }
    }

    var hasConnectedSources: Bool {
        connectionStates.contains { $0.isConnected }
    }

    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        snapshot = try? snapshotStore.load()

        if snapshot == nil && hasConnectedSources {
            refresh()
        }
    }

    func connect(_ source: TrackedSource) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.prompt = "Connect"
        panel.message = source.panelMessage
        panel.directoryURL = source.defaultDirectoryURL.deletingLastPathComponent()
        panel.nameFieldStringValue = source.defaultDirectoryURL.lastPathComponent
        panel.title = source.panelPrompt

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        do {
            try bookmarkStore.saveBookmark(for: source, url: selectedURL)
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = "Could not save access for \(source.displayName): \(error.localizedDescription)"
        }
    }

    func disconnect(_ source: TrackedSource) {
        bookmarkStore.removeBookmark(for: source)
        errorMessage = nil
    }

    func refresh() {
        guard !isRefreshing else { return }

        let codexURL = bookmarkStore.resolvedURL(for: .codex)
        let claudeURL = bookmarkStore.resolvedURL(for: .claude)
        guard codexURL != nil || claudeURL != nil else {
            errorMessage = "Connect at least one source before refreshing."
            return
        }

        isRefreshing = true
        errorMessage = nil
        let importer = self.importer
        let snapshotStore = self.snapshotStore

        Task { [weak self, importer, snapshotStore, codexURL, claudeURL] in
            guard let self else { return }

            do {
                let snapshot = try await Task.detached(priority: .userInitiated) { [importer, codexURL, claudeURL] in
                    try withSecurityScopedURLs([codexURL, claudeURL].compactMap { $0 }) {
                        try importer.importUsage(
                            from: UsageImportRequest(codexRoot: codexURL, claudeRoot: claudeURL)
                        )
                    }
                }.value

                try snapshotStore.save(snapshot)
                self.snapshot = snapshot
            } catch {
                self.errorMessage = "Refresh failed: \(error.localizedDescription)"
            }

            self.isRefreshing = false
        }
    }
}

private func withSecurityScopedURLs<T>(_ urls: [URL], perform: () throws -> T) throws -> T {
    let started = urls.map { url in
        (url, url.startAccessingSecurityScopedResource())
    }

    defer {
        for (url, didStart) in started where didStart {
            url.stopAccessingSecurityScopedResource()
        }
    }

    return try perform()
}
