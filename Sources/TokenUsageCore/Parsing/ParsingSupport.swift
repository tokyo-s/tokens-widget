import Foundation

enum ParsingSupport {
    static func parseObject(from line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }

        return dictionary
    }

    static func string(_ value: Any?) -> String? {
        value as? String
    }

    static func integer(_ value: Any?) -> Int {
        switch value {
        case let int as Int:
            return int
        case let double as Double:
            return Int(double)
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string) ?? 0
        default:
            return 0
        }
    }

    static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    static func value(at path: [String], in object: [String: Any]) -> Any? {
        var current: Any? = object

        for component in path {
            guard let dictionary = current as? [String: Any] else {
                return nil
            }

            current = dictionary[component]
        }

        return current
    }

    static func nestedString(in object: [String: Any], path: [String]) -> String? {
        string(value(at: path, in: object))
    }

    static func nestedInteger(in object: [String: Any], path: [String]) -> Int {
        integer(value(at: path, in: object))
    }

    static func parseTimestamp(_ rawValue: String?) -> Date? {
        guard let rawValue else { return nil }

        let preciseFormatter = ISO8601DateFormatter()
        preciseFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = preciseFormatter.date(from: rawValue) {
            return date
        }

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        return fallbackFormatter.date(from: rawValue)
    }

    static func resolveUsageRoot(root: URL, expectedLeaf: String) -> URL {
        if root.lastPathComponent == expectedLeaf {
            return root
        }

        return root.appendingPathComponent(expectedLeaf, isDirectory: true)
    }

    static func jsonlFiles(in root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants],
            errorHandler: nil
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            guard url.pathExtension == "jsonl" else { return nil }
            return url
        }
    }
}
