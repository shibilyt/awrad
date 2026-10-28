import Foundation

/// A document whose JSON doesn't match its entity type's schema.
public struct SyncDocumentError: Error, Hashable, Sendable {
    public let type: SyncEntityType
    public let errors: [SyncFieldError]
}

extension SyncDocument {
    /// The document of an entity of `type`, from its wire JSON.
    public init(type: SyncEntityType, json: AwradJSON) throws(SyncDocumentError) {
        switch type {
        case .customDhikr:
            do {
                self = .customDhikr(try CustomDhikrDocument(json: json))
            } catch {
                throw SyncDocumentError(type: type, errors: error.errors)
            }
        case .userTag:
            guard let members = json.objectValue, Set(members.keys) == ["name", "normalized_name"],
                let name = members["name"]?.stringValue, let normalized = members["normalized_name"]?.stringValue
            else { throw SyncDocumentError(type: type, errors: [SyncFieldError(field: "", code: "invalid")]) }
            self = .userTag(UserTagDocument(name: name, normalizedName: normalized))
        case .dhikrPersonal:
            guard let members = json.objectValue, Set(members.keys) == ["tag_ids"],
                let items = members["tag_ids"]?.arrayValue
            else { throw SyncDocumentError(type: type, errors: [SyncFieldError(field: "", code: "invalid")]) }
            let ids = items.compactMap { $0.stringValue.flatMap(AwradID.init) }
            guard ids.count == items.count else {
                throw SyncDocumentError(type: type, errors: [SyncFieldError(field: "/tag_ids", code: "invalid")])
            }
            self = .dhikrPersonal(DhikrPersonalDocument(tagIDs: ids))
        }
    }

    /// The wire JSON.
    public var json: AwradJSON {
        switch self {
        case .customDhikr(let document):
            document.json
        case .userTag(let tag):
            .object(["name": .string(tag.name), "normalized_name": .string(tag.normalizedName)])
        case .dhikrPersonal(let personal):
            .object(["tag_ids": .array(personal.tagIDs.map { .string($0.description) })])
        }
    }
}

extension AwradID: Comparable, Codable {
    /// By the wire form, as the fixtures and the feed order entity IDs.
    public static func < (lhs: AwradID, rhs: AwradID) -> Bool { lhs.description < rhs.description }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let id = AwradID(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a wire UUID: \(string)")
        }
        self = id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
