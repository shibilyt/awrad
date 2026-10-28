import Foundation
import SwiftData

// One profile's database (a SwiftData store of its own, ADR 0002's pre-release policy): its custom
// dhikrs, tags and personal records, the outbox, the versions the server confirmed, open
// conflicts, rejection notices and the feed position. Documents are stored as their compact wire
// JSON, so what was synced round-trips exactly.

/// A custom dhikr: its `custom_dhikr_document`.
@Model
final class CustomDhikrRecord {
    @Attribute(.unique) var id: UUID
    var document: Data

    init(id: UUID, document: Data) {
        self.id = id
        self.document = document
    }
}

/// A user tag: its display and normalized names.
@Model
final class UserTagRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var normalizedName: String

    init(id: UUID, name: String, normalizedName: String) {
        self.id = id
        self.name = name
        self.normalizedName = normalizedName
    }
}

/// A personal record: the tags on one dhikr (built-in or custom), in the user's order.
@Model
final class DhikrPersonalRecord {
    /// The dhikr's ID.
    @Attribute(.unique) var id: UUID
    /// Lowercase wire UUIDs.
    var tagIDs: [String]

    init(id: UUID, tagIDs: [String]) {
        self.id = id
        self.tagIDs = tagIDs
    }
}

/// The last version the server confirmed for an entity. Kept apart from the entity, because a
/// locally deleted entity still needs it until its delete is acknowledged.
@Model
final class KnownVersionRecord {
    /// `entity_type/entity_id`.
    @Attribute(.unique) var key: String
    var version: Int

    init(key: String, version: Int) {
        self.key = key
        self.version = version
    }
}

/// A queued command. `position` orders the outbox; a replaced command keeps its position.
@Model
final class OutboxCommandRecord {
    @Attribute(.unique) var commandID: UUID
    var position: Int
    var entityType: String
    var entityID: UUID
    var op: String
    var baseVersion: Int
    /// The document's wire JSON; `nil` for a delete.
    var document: Data?
    var sent: Bool

    init(
        commandID: UUID, position: Int, entityType: String, entityID: UUID, op: String, baseVersion: Int,
        document: Data?, sent: Bool
    ) {
        self.commandID = commandID
        self.position = position
        self.entityType = entityType
        self.entityID = entityID
        self.op = op
        self.baseVersion = baseVersion
        self.document = document
        self.sent = sent
    }
}

/// An open "Changed on another device" conflict, with the server's copy.
@Model
final class SyncConflictRecord {
    /// `entity_type/entity_id`.
    @Attribute(.unique) var key: String
    var localOp: String
    var serverVersion: Int
    var serverState: String
    var serverDocument: Data?

    init(key: String, localOp: String, serverVersion: Int, serverState: String, serverDocument: Data?) {
        self.key = key
        self.localOp = localOp
        self.serverVersion = serverVersion
        self.serverState = serverState
        self.serverDocument = serverDocument
    }
}

/// A rejected change that was undone, until the user dismisses it.
@Model
final class SyncNoticeRecord {
    var position: Int
    var code: String
    var entityType: String
    var entityID: UUID

    init(position: Int, code: String, entityType: String, entityID: UUID) {
        self.position = position
        self.code = code
        self.entityType = entityType
        self.entityID = entityID
    }
}

/// The profile's changes-feed position. One row; saved with the page it comes from.
@Model
final class SyncPositionRecord {
    var after: Int

    init(after: Int) {
        self.after = after
    }
}

/// The schema of a profile's database.
enum ProfileSchema {
    static let schema = Schema([
        CustomDhikrRecord.self, UserTagRecord.self, DhikrPersonalRecord.self, KnownVersionRecord.self,
        OutboxCommandRecord.self, SyncConflictRecord.self, SyncNoticeRecord.self, SyncPositionRecord.self,
    ])
}
