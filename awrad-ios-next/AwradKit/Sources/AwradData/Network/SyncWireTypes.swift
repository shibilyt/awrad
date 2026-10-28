import AwradDomain
import Foundation

// Hand-written wire types of the change queue (contracts/api/paths/sync.yaml, contracts/sync/v1,
// root ADR-2026-10-16). Documents stay JSON (`AwradJSON`) on the wire; they become typed
// documents with the entity type of the command or change they belong to.

/// The body of `post_sync_commands`.
struct SyncCommandBatchWire: Codable, Equatable, Sendable {
    let commands: [SyncCommandWire]
}

struct SyncCommandWire: Codable, Equatable, Sendable {
    let commandID: String
    let entityType: String
    let entityID: String
    let op: String
    let baseVersion: Int
    /// Present on a put, absent (never `null`) on a delete.
    let document: AwradJSON?

    enum CodingKeys: String, CodingKey {
        case op, document
        case commandID = "command_id"
        case entityType = "entity_type"
        case entityID = "entity_id"
        case baseVersion = "base_version"
    }

    init(_ command: OutboxCommand) {
        commandID = command.commandID.description
        entityType = command.key.type.rawValue
        entityID = command.key.id.description
        op = command.op.rawValue
        baseVersion = command.baseVersion
        document = command.op == .put ? command.document?.json : nil
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commandID = try container.decode(String.self, forKey: .commandID)
        entityType = try container.decode(String.self, forKey: .entityType)
        entityID = try container.decode(String.self, forKey: .entityID)
        op = try container.decode(String.self, forKey: .op)
        baseVersion = try container.decode(Int.self, forKey: .baseVersion)
        document = try container.decodeIfPresent(AwradJSON.self, forKey: .document)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commandID, forKey: .commandID)
        try container.encode(entityType, forKey: .entityType)
        try container.encode(entityID, forKey: .entityID)
        try container.encode(op, forKey: .op)
        try container.encode(baseVersion, forKey: .baseVersion)
        try container.encodeIfPresent(document, forKey: .document)
    }
}

/// The response of `post_sync_commands`.
struct SyncReceiptBatchWire: Codable, Equatable, Sendable {
    let receipts: [SyncReceiptWire]
    let headRevision: Int

    enum CodingKeys: String, CodingKey {
        case receipts
        case headRevision = "head_revision"
    }
}

/// The server's copy of an entity (`$defs/current`).
struct SyncCurrentWire: Codable, Equatable, Sendable {
    let version: Int
    let state: String
    /// `null` when deleted; the key is always there.
    let document: AwradJSON

    func copy(type: SyncEntityType) -> ServerCopy? {
        guard let state = SyncEntityState(rawValue: state) else { return nil }
        let typed = document == .null ? nil : try? SyncDocument(type: type, json: document)
        if state == .active, typed == nil { return nil }
        return ServerCopy(version: version, state: state, document: typed)
    }
}

struct SyncFieldErrorWire: Codable, Equatable, Sendable {
    let field: String
    let code: String
}

/// One entity a delete cascaded to (`$defs/cascaded_change`).
struct SyncCascadeWire: Codable, Equatable, Sendable {
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

    /// `nil` for an entity type or state this client doesn't know: it's skipped.
    var cascade: SyncCascade? {
        guard let type = SyncEntityType(rawValue: entityType), let id = AwradID(entityID),
            let state = SyncEntityState(rawValue: state)
        else { return nil }
        return SyncCascade(key: SyncEntityKey(type, id), state: state, version: version, revision: revision)
    }
}

/// One receipt. Each status carries exactly its own members, so it encodes back to the same JSON.
indirect enum SyncReceiptWire: Codable, Equatable, Sendable {
    /// `cascaded` is a list for a tag or custom dhikr delete, `null` otherwise (always present).
    case applied(commandID: String, version: Int, revision: Int, cascaded: [SyncCascadeWire]?)
    case duplicate(commandID: String, original: SyncReceiptWire)
    case conflict(commandID: String, current: SyncCurrentWire)
    case merged(commandID: String, mergedInto: String, current: SyncCurrentWire)
    case gone(commandID: String)
    case rejected(commandID: String, code: String, fields: [SyncFieldErrorWire], current: SyncCurrentWire?)
    /// A status this client doesn't know: the command stays queued and is sent again.
    case unknown(commandID: String, status: String)

    enum CodingKeys: String, CodingKey {
        case status, version, revision, original, current, code, fields, cascaded
        case commandID = "command_id"
        case mergedInto = "merged_into"
    }

    var commandID: String {
        switch self {
        case .applied(let id, _, _, _), .duplicate(let id, _), .conflict(let id, _), .merged(let id, _, _),
            .gone(let id), .rejected(let id, _, _, _), .unknown(let id, _):
            id
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .commandID)
        switch try container.decode(String.self, forKey: .status) {
        case "applied":
            self = .applied(
                commandID: id, version: try container.decode(Int.self, forKey: .version),
                revision: try container.decode(Int.self, forKey: .revision),
                cascaded: try container.decodeIfPresent([SyncCascadeWire].self, forKey: .cascaded))
        case "duplicate":
            self = .duplicate(commandID: id, original: try container.decode(SyncReceiptWire.self, forKey: .original))
        case "conflict":
            self = .conflict(commandID: id, current: try container.decode(SyncCurrentWire.self, forKey: .current))
        case "merged":
            self = .merged(
                commandID: id, mergedInto: try container.decode(String.self, forKey: .mergedInto),
                current: try container.decode(SyncCurrentWire.self, forKey: .current))
        case "gone":
            self = .gone(commandID: id)
        case "rejected":
            self = .rejected(
                commandID: id, code: try container.decode(String.self, forKey: .code),
                fields: try container.decode([SyncFieldErrorWire].self, forKey: .fields),
                current: try container.decode(SyncCurrentWire?.self, forKey: .current))
        case let status:
            self = .unknown(commandID: id, status: status)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commandID, forKey: .commandID)
        switch self {
        case .applied(_, let version, let revision, let cascaded):
            try container.encode("applied", forKey: .status)
            try container.encode(version, forKey: .version)
            try container.encode(revision, forKey: .revision)
            // Required, and `null` for a command that can't cascade.
            try container.encode(cascaded, forKey: .cascaded)
        case .duplicate(_, let original):
            try container.encode("duplicate", forKey: .status)
            try container.encode(original, forKey: .original)
        case .conflict(_, let current):
            try container.encode("conflict", forKey: .status)
            try container.encode(current, forKey: .current)
        case .merged(_, let mergedInto, let current):
            try container.encode("merged", forKey: .status)
            try container.encode(mergedInto, forKey: .mergedInto)
            try container.encode(current, forKey: .current)
        case .gone:
            try container.encode("gone", forKey: .status)
        case .rejected(_, let code, let fields, let current):
            try container.encode("rejected", forKey: .status)
            try container.encode(code, forKey: .code)
            try container.encode(fields, forKey: .fields)
            // Required, and `null` when the server has no such entity.
            try container.encode(current, forKey: .current)
        case .unknown(_, let status):
            try container.encode(status, forKey: .status)
        }
    }

    /// The domain receipt, its documents typed by the command's entity type. `nil` for a receipt the
    /// client can't read: its command stays queued.
    func receipt(type: SyncEntityType) -> SyncReceipt? {
        guard let id = AwradID(commandID) else { return nil }
        switch self {
        case .applied(_, let version, let revision, let cascaded):
            return .applied(
                commandID: id, version: version, revision: revision, cascaded: cascaded?.compactMap(\.cascade))
        case .duplicate(_, let original):
            return original.receipt(type: type).map { .duplicate(commandID: id, original: $0) }
        case .conflict(_, let current):
            return current.copy(type: type).map { .conflict(commandID: id, current: $0) }
        case .merged(_, let mergedInto, let current):
            guard let survivor = AwradID(mergedInto), let copy = current.copy(type: type) else { return nil }
            return .merged(commandID: id, mergedInto: survivor, current: copy)
        case .gone:
            return .gone(commandID: id)
        case .rejected(_, let code, let fields, let current):
            return .rejected(
                commandID: id, code: RejectionCode(code: code),
                fields: fields.map { SyncFieldError(field: $0.field, code: $0.code) },
                current: current?.copy(type: type))
        case .unknown:
            return nil
        }
    }
}

/// The response of `list_sync_changes`.
struct SyncChangesPageWire: Codable, Equatable, Sendable {
    let changes: [SyncChangeWire]
    let nextAfter: Int
    let hasMore: Bool
    let headRevision: Int

    enum CodingKeys: String, CodingKey {
        case changes
        case nextAfter = "next_after"
        case hasMore = "has_more"
        case headRevision = "head_revision"
    }

    /// The domain page. A change the client can't read (an entity type from a later version, a
    /// document that doesn't parse) is skipped.
    var page: ChangesPage {
        ChangesPage(
            changes: changes.compactMap(\.change), nextAfter: nextAfter, hasMore: hasMore, headRevision: headRevision)
    }
}

struct SyncChangeWire: Codable, Equatable, Sendable {
    let entityType: String
    let entityID: String
    let state: String
    let version: Int
    let revision: Int
    /// `null` for a delete; the key is always there.
    let document: AwradJSON

    enum CodingKeys: String, CodingKey {
        case state, version, revision, document
        case entityType = "entity_type"
        case entityID = "entity_id"
    }

    var change: SyncChange? {
        guard let type = SyncEntityType(rawValue: entityType), let id = AwradID(entityID),
            let state = SyncEntityState(rawValue: state)
        else { return nil }
        let document = self.document == .null ? nil : try? SyncDocument(type: type, json: self.document)
        if state == .active, document == nil { return nil }
        return SyncChange(
            key: SyncEntityKey(type, id), state: state, version: version, revision: revision, document: document)
    }
}
