import Foundation

// The change queue (contracts/sync/v1, root ADR-2026-10-28): entities, commands, receipts and
// changes, as Sendable value types. The wire types in AwradData map onto these.

/// What kind of entity a command or change is about.
public enum SyncEntityType: String, CaseIterable, Sendable, Hashable, Comparable {
    case customDhikr = "custom_dhikr"
    case userTag = "user_tag"
    case dhikrPersonal = "dhikr_personal"

    /// Wire order (`entity_type` as a string), as the feed and fixtures sort.
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One entity's identity: its type and ID. A `dhikr_personal`'s ID is its dhikr's.
public struct SyncEntityKey: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let type: SyncEntityType
    public let id: AwradID

    public init(_ type: SyncEntityType, _ id: AwradID) {
        self.type = type
        self.id = id
    }

    /// By `entity_type`, then `entity_id`, as the fixtures list entities.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.type.rawValue, lhs.id.description) < (rhs.type.rawValue, rhs.id.description)
    }

    public var description: String { "\(type.rawValue)/\(id)" }
}

public enum SyncOp: String, Sendable, Hashable {
    case put, delete
}

/// `active` or `deleted` (a final tombstone).
public enum SyncEntityState: String, Sendable, Hashable {
    case active, deleted
}

/// A tag's names (`$defs/user_tag_document`), made by `TagName.normalize`.
public struct UserTagDocument: Hashable, Sendable {
    public let name: String
    public let normalizedName: String

    public init(name: String, normalizedName: String) {
        self.name = name
        self.normalizedName = normalizedName
    }

    /// The document for a tag name as typed, or why it can't be one.
    public init(typed input: String) throws(TagNameError) {
        let names = try TagName.normalize(input)
        self.init(name: names.name, normalizedName: names.normalizedName)
    }
}

/// A user's own data about one dhikr (`$defs/dhikr_personal_document`): for now its tags, in the
/// user's order. Clients clear it with an empty list, never a delete.
public struct DhikrPersonalDocument: Hashable, Sendable {
    /// At most 20, no repeats.
    public static let maxTags = 20

    public let tagIDs: [AwradID]

    public init(tagIDs: [AwradID]) {
        self.tagIDs = tagIDs
    }
}

/// One of the three entity documents.
public enum SyncDocument: Hashable, Sendable {
    case customDhikr(CustomDhikrDocument)
    case userTag(UserTagDocument)
    case dhikrPersonal(DhikrPersonalDocument)

    public var entityType: SyncEntityType {
        switch self {
        case .customDhikr: .customDhikr
        case .userTag: .userTag
        case .dhikrPersonal: .dhikrPersonal
        }
    }

    public var tagIDs: [AwradID]? {
        if case .dhikrPersonal(let personal) = self { return personal.tagIDs }
        return nil
    }
}

/// A command waiting in a profile's outbox (oldest first). `sent` turns true once it has been in a
/// request, whether or not its receipt came back; only a never-sent command may be replaced.
public struct OutboxCommand: Hashable, Sendable {
    public let commandID: AwradID
    public let key: SyncEntityKey
    public var op: SyncOp
    public var baseVersion: Int
    /// `nil` for a delete (the wire command omits it).
    public var document: SyncDocument?
    public var sent: Bool

    public init(
        commandID: AwradID, key: SyncEntityKey, op: SyncOp, baseVersion: Int, document: SyncDocument?,
        sent: Bool = false
    ) {
        self.commandID = commandID
        self.key = key
        self.op = op
        self.baseVersion = baseVersion
        self.document = document
        self.sent = sent
    }

    /// The entities the command's document names, which the server must have first: a personal
    /// record's tags and its own custom dhikr. Tags, custom dhikrs and deletes name nothing.
    public var references: Set<SyncEntityKey> {
        guard let tagIDs = document?.tagIDs else { return [] }
        return Set(tagIDs.map { SyncEntityKey(.userTag, $0) }).union([SyncEntityKey(.customDhikr, key.id)])
    }
}

/// One saved local change: a put of the whole new document, or a delete.
public struct SyncEdit: Hashable, Sendable {
    /// The new command's ID, if the edit adds one.
    public let commandID: AwradID
    public let key: SyncEntityKey
    public let op: SyncOp
    public let document: SyncDocument?

    public init(commandID: AwradID = .random(), key: SyncEntityKey, op: SyncOp, document: SyncDocument?) {
        self.commandID = commandID
        self.key = key
        self.op = op
        self.document = document
    }

    public static func put(_ document: SyncDocument, id: AwradID, commandID: AwradID = .random()) -> SyncEdit {
        SyncEdit(commandID: commandID, key: SyncEntityKey(document.entityType, id), op: .put, document: document)
    }

    public static func delete(_ key: SyncEntityKey, commandID: AwradID = .random()) -> SyncEdit {
        SyncEdit(commandID: commandID, key: key, op: .delete, document: nil)
    }
}

/// The server's copy of an entity, as receipts carry it (`$defs/current`).
public struct ServerCopy: Hashable, Sendable {
    public let version: Int
    public let state: SyncEntityState
    /// `nil` when deleted.
    public let document: SyncDocument?

    public init(version: Int, state: SyncEntityState, document: SyncDocument?) {
        self.version = version
        self.state = state
        self.document = document
    }
}

/// An open conflict: "Changed on another device". The local edit stays until the user picks
/// Keep mine or Use theirs.
public struct SyncConflict: Hashable, Sendable {
    public let key: SyncEntityKey
    /// `put` if the entity exists locally, else `delete`.
    public var localOp: SyncOp
    public var server: ServerCopy

    public init(key: SyncEntityKey, localOp: SyncOp, server: ServerCopy) {
        self.key = key
        self.localOp = localOp
        self.server = server
    }
}

/// The user's answer to a conflict.
public enum ConflictChoice: String, Sendable, Hashable {
    case keepMine = "keep_mine"
    case useTheirs = "use_theirs"
}

/// An entity's latest state in the changes feed.
public struct SyncChange: Hashable, Sendable {
    public let key: SyncEntityKey
    public let state: SyncEntityState
    public let version: Int
    public let revision: Int
    public let document: SyncDocument?

    public init(key: SyncEntityKey, state: SyncEntityState, version: Int, revision: Int, document: SyncDocument?) {
        self.key = key
        self.state = state
        self.version = version
        self.revision = revision
        self.document = document
    }
}

/// One page of `list_sync_changes`.
public struct ChangesPage: Hashable, Sendable {
    public let changes: [SyncChange]
    public let nextAfter: Int
    public let hasMore: Bool
    public let headRevision: Int

    public init(changes: [SyncChange], nextAfter: Int, hasMore: Bool, headRevision: Int) {
        self.changes = changes
        self.nextAfter = nextAfter
        self.hasMore = hasMore
        self.headRevision = headRevision
    }
}

/// Why the server rejected a command (`$defs/rejection_code`). Unknown codes are kept as `other`.
public enum RejectionCode: Hashable, Sendable {
    case documentInvalid, documentTooLarge, customDhikrLimitReached, tagLimitReached, tagNameTaken
    case tagNotFound, dhikrNotFound, entityNotFound, deleteNotAllowed, commandIDReused
    /// A custom dhikr put naming an asset that isn't a ready asset of the account (slice 3c).
    case audioNotFound
    /// A custom dhikr put whose `byte_size` or `content_type` isn't its asset's (slice 3c).
    case audioMismatch
    case other(String)

    private static let byCode: [String: RejectionCode] = [
        "document_invalid": .documentInvalid, "document_too_large": .documentTooLarge,
        "custom_dhikr_limit_reached": .customDhikrLimitReached, "tag_limit_reached": .tagLimitReached,
        "tag_name_taken": .tagNameTaken, "tag_not_found": .tagNotFound, "dhikr_not_found": .dhikrNotFound,
        "entity_not_found": .entityNotFound, "delete_not_allowed": .deleteNotAllowed,
        "command_id_reused": .commandIDReused, "audio_not_found": .audioNotFound, "audio_mismatch": .audioMismatch,
    ]

    public init(code: String) {
        self = Self.byCode[code] ?? .other(code)
    }

    public var code: String {
        if case .other(let code) = self { return code }
        return Self.byCode.first { $0.value == self }?.key ?? ""
    }

    /// The two rejections of a custom dhikr put about its uploaded recording, after which the phone
    /// keeps its edit (`SyncRules.apply(_:to:localAudioFiles:newCommandID:)`).
    public var isAboutAudio: Bool { self == .audioNotFound || self == .audioMismatch }
}

/// What applying a batch's receipts leaves for the phone to do.
public struct ReceiptsOutcome: Hashable, Sendable {
    /// Rejected changes to tell the user about.
    public var notices: [SyncNotice] = []
    /// Custom dhikrs whose recording goes back into the upload queue, sorted.
    public var uploadsQueued: [AwradID] = []

    public init(notices: [SyncNotice] = [], uploadsQueued: [AwradID] = []) {
        self.notices = notices
        self.uploadsQueued = uploadsQueued
    }
}

/// One problem with a command or a document: a JSON Pointer and a code (`$defs/field_error`).
public struct SyncFieldError: Hashable, Sendable, Comparable {
    public let field: String
    public let code: String

    public init(field: String, code: String) {
        self.field = field
        self.code = code
    }

    /// By field, then code, as the fixtures list them.
    public static func < (lhs: Self, rhs: Self) -> Bool { (lhs.field, lhs.code) < (rhs.field, rhs.code) }
}

/// An entity the server changed as a cascade of a delete, at the same revision
/// (`$defs/cascaded_change`): a personal record a tag delete took the tag out of (active), or the
/// personal record of a deleted custom dhikr (deleted). The document comes in the changes feed.
public struct SyncCascade: Hashable, Sendable {
    public let key: SyncEntityKey
    public let state: SyncEntityState
    public let version: Int
    public let revision: Int

    public init(key: SyncEntityKey, state: SyncEntityState, version: Int, revision: Int) {
        self.key = key
        self.state = state
        self.version = version
        self.revision = revision
    }
}

/// What the server decided about one command.
public indirect enum SyncReceipt: Hashable, Sendable {
    /// `cascaded` is a list for a tag or custom dhikr delete (empty when nothing cascaded), `nil`
    /// for every other command.
    case applied(commandID: AwradID, version: Int, revision: Int, cascaded: [SyncCascade]?)
    case duplicate(commandID: AwradID, original: SyncReceipt)
    case conflict(commandID: AwradID, current: ServerCopy)
    case merged(commandID: AwradID, mergedInto: AwradID, current: ServerCopy)
    case gone(commandID: AwradID)
    case rejected(commandID: AwradID, code: RejectionCode, fields: [SyncFieldError], current: ServerCopy?)

    public var commandID: AwradID {
        switch self {
        case .applied(let id, _, _, _), .duplicate(let id, _), .conflict(let id, _), .merged(let id, _, _),
            .gone(let id), .rejected(let id, _, _, _):
            id
        }
    }

    /// A duplicate's original outcome; any other receipt itself.
    public var outcome: SyncReceipt {
        if case .duplicate(_, let original) = self { return original.outcome }
        return self
    }
}

/// Something the user is told after sync: a change of theirs was rejected and undone.
public struct SyncNotice: Hashable, Sendable {
    public let code: RejectionCode
    public let key: SyncEntityKey

    public init(code: RejectionCode, key: SyncEntityKey) {
        self.code = code
        self.key = key
    }
}
