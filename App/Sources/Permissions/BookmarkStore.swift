import Foundation

struct BookmarkStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveBookmark(for source: TrackedSource, url: URL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        defaults.set(data, forKey: source.bookmarkKey)
    }

    func resolvedURL(for source: TrackedSource) -> URL? {
        guard let data = defaults.data(forKey: source.bookmarkKey) else {
            return nil
        }

        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        guard let url else {
            return nil
        }

        if isStale {
            try? saveBookmark(for: source, url: url)
        }

        return url
    }

    func removeBookmark(for source: TrackedSource) {
        defaults.removeObject(forKey: source.bookmarkKey)
    }
}
