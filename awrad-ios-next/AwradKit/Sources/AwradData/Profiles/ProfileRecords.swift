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

/// A queued command. `position` orders the outbox; a replaced command keeps its position unless it
/// moves after a later put it references (`SyncRules.moveAfterLaterReferences`).
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

/// A custom dhikr's recording waiting to be uploaded (slice 3c): one per dhikr, made when the
/// profile's account is signed in, kept across restarts until the dhikr's put names the asset.
@Model
final class AudioUploadRecord {
    @Attribute(.unique) var dhikrID: UUID
    /// A UUIDv7 made for this file; a new one when a retry has to start over.
    var assetID: UUID
    /// The file, under the profile's `Audio/` directory.
    var fileName: String
    /// The file's SHA-256, 64 lowercase hex digits.
    var sha256: String
    var byteSize: Int
    var contentType: String
    var durationMilliseconds: Int?
    /// `PendingUpload.Stage`.
    var stage: String
    /// Whether the server has recorded the pending upload (it then counts in the account's usage).
    var reserved: Bool
    /// How many times a mismatching file has started over with a new asset.
    var mismatchRetries: Int
    /// Why it couldn't be uploaded, once it failed for good (`AudioUploadFailure`).
    var failure: String?
    var createdAt: Date

    init(_ upload: PendingUpload, createdAt: Date) {
        dhikrID = upload.dhikrID.value
        assetID = upload.assetID.value
        fileName = upload.fileName
        sha256 = upload.sha256
        byteSize = upload.byteSize
        contentType = upload.contentType
        durationMilliseconds = upload.durationMilliseconds
        stage = upload.stage.rawValue
        reserved = upload.reserved
        mismatchRetries = upload.mismatchRetries
        failure = upload.failure?.rawValue
        self.createdAt = createdAt
    }
}

/// A recording that couldn't be uploaded, until the user dismisses it.
@Model
final class AudioNoticeRecord {
    var position: Int
    var dhikrID: UUID
    var failure: String
    var usedBytes: Int?
    var limitBytes: Int?

    init(position: Int, dhikrID: UUID, failure: String, usedBytes: Int?, limitBytes: Int?) {
        self.position = position
        self.dhikrID = dhikrID
        self.failure = failure
        self.usedBytes = usedBytes
        self.limitBytes = limitBytes
    }
}

/// The profile's practice policy (slice 3d): one row, or none for the default policy. Every
/// profile has its own, the anonymous one included; in an account's profile it's the
/// `practice_policy` entity, whose ID is the account's.
@Model
final class PracticePolicyRecord {
    /// The local policy's wire JSON.
    var document: Data
    /// The server copy it was edited from, which a conflict merges against; `nil` for none known
    /// (the default policy).
    var baseDocument: Data?
    /// The user changed a setting since the profile was created (the first-sign-in rule).
    var chosen: Bool
    /// The anonymous policy at the first sign-in, kept until the account's first full read of the
    /// changes feed decides whose policy wins (`PracticePolicy.afterSignIn`); `nil` otherwise.
    var signInDocument: Data?
    var signInChosen: Bool

    init(document: Data, baseDocument: Data? = nil, chosen: Bool = false) {
        self.document = document
        self.baseDocument = baseDocument
        self.chosen = chosen
        signInChosen = false
    }
}

/// The schema of a profile's database.
enum ProfileSchema {
    static let schema = Schema([
        CustomDhikrRecord.self, UserTagRecord.self, DhikrPersonalRecord.self, KnownVersionRecord.self,
        OutboxCommandRecord.self, SyncConflictRecord.self, SyncNoticeRecord.self, SyncPositionRecord.self,
        AudioUploadRecord.self, AudioNoticeRecord.self, PracticePolicyRecord.self,
    ])
}
