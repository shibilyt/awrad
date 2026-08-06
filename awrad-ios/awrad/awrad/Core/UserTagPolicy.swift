import Foundation

struct UserTag: Identifiable, Codable, Hashable {
    var id: AwradID
    var name: String
    var normalizedName: String
    var createdAt: Date
    var updatedAt: Date
}

struct DhikrTagAssignment: Identifiable, Codable, Hashable {
    var id: AwradID
    var tagID: AwradID
    var dhikrID: AwradID
    var createdAt: Date
}

struct DhikrAudioAsset: Identifiable, Codable, Hashable {
    enum Source: String, Codable, Hashable {
        case `import`
    }

    var id: AwradID
    var dhikrID: AwradID
    var relativeFileName: String
    var mimeType: String
    var byteSize: Int64
    var durationMs: Int64
    var sha256: String
    var source: Source
    var createdAt: Date
}

enum LibraryCollectionScope: String, Codable, Hashable {
    case all
    case yourDhikrs
}

struct LibraryCatalogFilters: Equatable {
    var query: String = ""
    var category: DhikrCategory?
    var collectionScope: LibraryCollectionScope = .all
    var selectedTagIDs: Set<AwradID> = []

    mutating func clear() {
        query = ""
        category = nil
        collectionScope = .all
        selectedTagIDs = []
    }
}

enum UserTagPolicy {
    static let maxGraphemeClusters = 40
    static let maxUTF8Bytes = 128
    static let maxTagsPerAccount = 100
    static let maxTagsPerDhikr = 20

    struct NormalizedTag: Equatable {
        var displayName: String
        var normalizedName: String
    }

    /// Trim, collapse Unicode whitespace, NFC display, locale-independent full case fold uniqueness.
    static func normalize(_ raw: String) -> NormalizedTag? {
        let collapsed = collapseWhitespace(raw)
        guard !collapsed.isEmpty else { return nil }
        let display = collapsed.precomposedStringWithCanonicalMapping
        guard !display.isEmpty else { return nil }
        guard display.count <= maxGraphemeClusters else { return nil }
        guard display.utf8.count <= maxUTF8Bytes else { return nil }
        let folded = display
            .folding(options: .caseInsensitive, locale: nil)
            .precomposedStringWithCanonicalMapping
        return NormalizedTag(
            displayName: display,
            normalizedName: folded
        )
    }

    private static func collapseWhitespace(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        var result = ""
        var previousWasSpace = false
        for character in trimmed {
            if character.unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) }) {
                if !previousWasSpace {
                    result.append(" ")
                    previousWasSpace = true
                }
            } else {
                result.append(character)
                previousWasSpace = false
            }
        }
        return result
    }
}
