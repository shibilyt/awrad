import AwradDomain
import Foundation

// Changes pages, receipts and resolutions as apply_changes writes them.

struct ChangeShape: Decodable {
    let entityType: String
    let entityID: String
    let state: String
    let version: Int
    let revision: Int
    let document: AwradJSON

    enum CodingKeys: String, CodingKey {
        case state, version, revision, document
        case entityType = "entity_type"
        case entityID = "entity_id"
    }

    func change() throws -> SyncChange {
        let type = try wireEntityType(entityType)
        guard let state = SyncEntityState(rawValue: state) else { throw SyncShapeError("unknown state \(state)") }
        return SyncChange(
            key: SyncEntityKey(type, try wireID(entityID)), state: state, version: version, revision: revision,
            document: try wireDocument(document, type: type))
    }
}

struct PageShape: Decodable {
    let changes: [ChangeShape]
    let nextAfter: Int
    let hasMore: Bool
    let headRevision: Int

    enum CodingKeys: String, CodingKey {
        case changes
        case nextAfter = "next_after"
        case hasMore = "has_more"
        case headRevision = "head_revision"
    }

    func page() throws -> ChangesPage {
        ChangesPage(
            changes: try changes.map { try $0.change() }, nextAfter: nextAfter, hasMore: hasMore,
            headRevision: headRevision)
    }
}

/// A receipt. Its `current` document is typed by the entity it's about, which the receipt doesn't
/// name: the document's own shape tells (a custom dhikr has `kind`, a tag `name`).
final class ReceiptShape: Decodable {
    let commandID: String
    let status: String
    let version: Int?
    let revision: Int?
    let mergedInto: String?
    let current: CurrentShape?
    let code: String?
    let fields: [FieldErrorShape]?
    let original: ReceiptShape?
    let cascaded: [CascadeShape]?

    enum CodingKeys: String, CodingKey {
        case status, version, revision, current, code, fields, original, cascaded
        case commandID = "command_id"
        case mergedInto = "merged_into"
    }

    func receipt() throws -> SyncReceipt {
        let commandID = try wireID(commandID)
        switch status {
        case "applied":
            return .applied(
                commandID: commandID, version: version ?? 0, revision: revision ?? 0,
                cascaded: try cascaded?.map { try $0.cascade() })
        case "duplicate":
            guard let original else { throw SyncShapeError("duplicate without original") }
            return .duplicate(commandID: commandID, original: try original.receipt())
        case "conflict":
            guard let current else { throw SyncShapeError("conflict without current") }
            return .conflict(commandID: commandID, current: try current.copy())
        case "merged":
            guard let current, let mergedInto else { throw SyncShapeError("merged without current") }
            return .merged(commandID: commandID, mergedInto: try wireID(mergedInto), current: try current.copy())
        case "gone":
            return .gone(commandID: commandID)
        case "rejected":
            return .rejected(
                commandID: commandID, code: RejectionCode(code: code ?? ""),
                fields: (fields ?? []).map { SyncFieldError(field: $0.field, code: $0.code) },
                current: try current?.copy())
        default:
            throw SyncShapeError("unknown status \(status)")
        }
    }
}

struct CascadeShape: Decodable {
    let entityType: String
    let entityID: String
    let state: String
    let version: Int
    let revision: Int

    enum CodingKeys: String, CodingKey {
        case state, version, revision
        case entityType = "entity_type"
        case entityID = "entity_id"
    }

    func cascade() throws -> SyncCascade {
        guard let state = SyncEntityState(rawValue: state) else { throw SyncShapeError("unknown state \(state)") }
        return SyncCascade(
            key: SyncEntityKey(try wireEntityType(entityType), try wireID(entityID)), state: state, version: version,
            revision: revision)
    }
}

struct CurrentShape: Decodable {
    let version: Int
    let state: String
    let document: AwradJSON

    func copy() throws -> ServerCopy {
        guard let state = SyncEntityState(rawValue: state) else { throw SyncShapeError("unknown state \(state)") }
        let type: SyncEntityType? =
            switch document {
            case .null: nil
            case let json where json["kind"] != nil: .customDhikr
            case let json where json["name"] != nil: .userTag
            case let json where json["day_reset"] != nil: .practicePolicy
            default: .dhikrPersonal
            }
        return ServerCopy(
            version: version, state: state, document: try type.flatMap { try wireDocument(document, type: $0) })
    }
}

struct ResolveShape: Decodable {
    let entityType: String
    let entityID: String
    let choice: String
    let commandID: String?

    enum CodingKeys: String, CodingKey {
        case choice
        case entityType = "entity_type"
        case entityID = "entity_id"
        case commandID = "command_id"
    }
}
