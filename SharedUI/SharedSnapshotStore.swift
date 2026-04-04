import Foundation
import TokenUsageCore

struct SharedSnapshotStore {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> UsageSnapshot? {
        let snapshotURL = try resolvedSnapshotURL()
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: snapshotURL)
        return try decoder.decode(UsageSnapshot.self, from: data)
    }

    func save(_ snapshot: UsageSnapshot) throws {
        let snapshotURL = try resolvedSnapshotURL()
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: [.atomic])
    }

    private func resolvedSnapshotURL() throws -> URL {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConfiguration.appGroupIdentifier
        ) {
            try FileManager.default.createDirectory(at: groupURL, withIntermediateDirectories: true)
            return groupURL.appendingPathComponent(AppConfiguration.snapshotFileName)
        }

        let fallbackRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(AppConfiguration.appSupportFolderName, isDirectory: true)

        guard let fallbackRoot else {
            throw NSError(
                domain: "TokensWidget",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not locate a writable snapshot directory."]
            )
        }

        try FileManager.default.createDirectory(at: fallbackRoot, withIntermediateDirectories: true)
        return fallbackRoot.appendingPathComponent(AppConfiguration.snapshotFileName)
    }
}
