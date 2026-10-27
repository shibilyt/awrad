import Foundation

/// The built-in dhikrs and the collections that list them (contracts/dhikr-catalog/v1), read-only and
/// in memory. The app bundles an identical copy of `catalog.json` (`bundled()`); nothing reads
/// `contracts/` at run time.
///
/// Only a consistent catalog exists: its initializers throw `DhikrCatalogError` when a key repeats or
/// a collection, tag or virtue points at nothing.
public struct DhikrCatalog: Sendable {
    /// The shape's version; this code reads version 1.
    public static let supportedVersion = 1

    public let version: Int
    /// Bumped by every content change (contracts README, "contentRevision").
    public let contentRevision: Int
    /// Every dhikr, in catalog order.
    public let dhikrs: [Dhikr]
    public let collections: [DhikrCollection]
    public let tags: [CatalogTag]

    private let dhikrIndex: [String: Int]
    private let tagIndex: [String: Int]

    public init(
        version: Int = supportedVersion, contentRevision: Int, dhikrs: [Dhikr], collections: [DhikrCollection],
        tags: [CatalogTag]
    ) throws(DhikrCatalogError) {
        guard version == Self.supportedVersion else { throw .unsupportedVersion(version) }
        var dhikrIndex: [String: Int] = [:]
        for (offset, dhikr) in dhikrs.enumerated() {
            guard dhikrIndex.updateValue(offset, forKey: dhikr.key) == nil else { throw .duplicateKey(dhikr.key) }
        }
        var tagIndex: [String: Int] = [:]
        for (offset, tag) in tags.enumerated() {
            guard tagIndex.updateValue(offset, forKey: tag.key) == nil else { throw .duplicateKey(tag.key) }
        }
        for collection in collections {
            for key in collection.dhikrKeys where dhikrIndex[key] == nil {
                throw .unknownDhikr(collection: collection.key, dhikr: key)
            }
        }
        for dhikr in dhikrs {
            for tag in dhikr.tags where tagIndex[tag] == nil {
                throw .unknownTag(dhikr: dhikr.key, tag: tag)
            }
            let ids = Set(dhikr.references.map(\.id))
            for virtue in dhikr.virtues {
                for id in virtue.references where !ids.contains(id) {
                    throw .unknownReference(dhikr: dhikr.key, reference: id)
                }
            }
        }
        self.version = version
        self.contentRevision = contentRevision
        self.dhikrs = dhikrs
        self.collections = collections
        self.tags = tags
        self.dhikrIndex = dhikrIndex
        self.tagIndex = tagIndex
    }

    /// An empty catalog, for previews.
    public static let empty: DhikrCatalog = {
        do {
            return try DhikrCatalog(contentRevision: 1, dhikrs: [], collections: [], tags: [])
        } catch {
            preconditionFailure("An empty catalog is always consistent")
        }
    }()

    /// The dhikr with this key.
    public func dhikr(_ key: String) -> Dhikr? {
        dhikrIndex[key].map { dhikrs[$0] }
    }

    /// A collection's dhikrs, in its order.
    public func dhikrs(in collection: DhikrCollection) -> [Dhikr] {
        collection.dhikrKeys.compactMap(dhikr)
    }

    /// The collection with this key.
    public func collection(_ key: String) -> DhikrCollection? {
        collections.first { $0.key == key }
    }

    /// The catalog tag with this key.
    public func tag(_ key: String) -> CatalogTag? {
        tagIndex[key].map { tags[$0] }
    }
}

/// Why a catalog can't be built. Each case names what's wrong.
public enum DhikrCatalogError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case duplicateKey(String)
    case unknownDhikr(collection: String, dhikr: String)
    case unknownTag(dhikr: String, tag: String)
    case unknownReference(dhikr: String, reference: String)
    case missingResource
}

extension DhikrCatalog {
    /// Decodes `catalog.json`, rejecting unknown keys and inconsistent content.
    public init(json: Data) throws {
        self = try JSONDecoder().decode(DhikrCatalog.self, from: json)
    }

    /// The app's copy of `contracts/dhikr-catalog/v1/catalog.json` (`Resources/dhikr-catalog.json`),
    /// kept identical by `scripts/check-dhikr-catalog.py`.
    public static func bundled() throws -> DhikrCatalog {
        guard let url = bundledURL else { throw DhikrCatalogError.missingResource }
        return try DhikrCatalog(json: Data(contentsOf: url))
    }

    /// Where the bundled copy is.
    public static var bundledURL: URL? {
        Bundle.module.url(forResource: "dhikr-catalog", withExtension: "json")
    }
}
