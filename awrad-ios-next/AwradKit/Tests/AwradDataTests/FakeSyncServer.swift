import AwradDomain
import Foundation

@testable import AwradData

/// A change-queue server in memory, following contracts/sync/v1 README's rules closely enough for
/// the engine tests: receipts (applied, duplicate, conflict, merged, gone, rejected), tag aliases and
/// reference rewriting (`tag_not_found` for a tag the account never had), cascades, and a feed
/// that pages by whole revisions. One account.
actor FakeSyncServer: SyncServer {
    struct Entity: Equatable {
        var version: Int
        var state: SyncEntityState
        var revision: Int
        var document: AwradJSON
    }

    let account: AwradID
    var entities: [SyncEntityKey: Entity] = [:]
    var head = 0
    var aliases: [AwradID: AwradID] = [:]
    /// Each command ID's payload and first receipt.
    var stored: [String: (payload: SyncCommandWire, receipt: SyncReceiptWire)] = [:]
    /// Changes per feed page (the real default is 200).
    var pageSize = 200
    /// Failures to throw from the next requests, in order.
    var failures: [SyncFailure] = []
    /// Rejection codes for the next commands that would otherwise apply, in order.
    var rejections: [String] = []
    /// Applies the next batch, then fails as if its response were lost.
    var losesNextResponse = false
    private(set) var sentBatches: [[SyncCommandWire]] = []
    private(set) var feedRequests: [Int] = []

    init(account: AwradID) {
        self.account = account
    }

    var requestCount: Int { sentBatches.count + feedRequests.count }

    func fail(_ failure: SyncFailure) { failures.append(failure) }
    func reject(_ code: String) { rejections.append(code) }
    func setPageSize(_ size: Int) { pageSize = size }
    func loseNextResponse() { losesNextResponse = true }

    /// Another device's delete, applied straight to the server with its cascade.
    func delete(_ key: SyncEntityKey) {
        guard let entity = entities[key] else { return }
        head += 1
        entities[key] = Entity(version: entity.version + 1, state: .deleted, revision: head, document: .null)
        cascade(key)
    }

    /// Another device's change, applied straight to the server.
    func put(_ key: SyncEntityKey, _ document: SyncDocument) {
        head += 1
        let version = (entities[key]?.version ?? 0) + 1
        entities[key] = Entity(version: version, state: .active, revision: head, document: document.json)
    }

    func document(_ key: SyncEntityKey) -> AwradJSON? {
        entities[key].flatMap { $0.state == .active ? $0.document : nil }
    }

    // MARK: - SyncServer

    func send(_ commands: [OutboxCommand], account: AwradID) throws(SyncFailure) -> SyncReceiptBatchWire {
        try check(account)
        let wire = commands.map(SyncCommandWire.init)
        sentBatches.append(wire)
        let receipts = wire.map(receipt)
        if losesNextResponse {
            losesNextResponse = false
            throw .unavailable
        }
        return SyncReceiptBatchWire(receipts: receipts, headRevision: head)
    }

    func changes(after: Int, limit: Int, account: AwradID) throws(SyncFailure) -> SyncChangesPageWire {
        try check(account)
        feedRequests.append(after)
        let rows = entities.filter { $0.value.revision > after && (after > 0 || $0.value.state == .active) }
            .sorted { ($0.value.revision, $0.key) < ($1.value.revision, $1.key) }
        var page: [(SyncEntityKey, Entity)] = []
        for row in rows {
            if page.count >= pageSize, let last = page.last, last.1.revision != row.value.revision { break }
            page.append((row.key, row.value))
        }
        let hasMore = page.count < rows.count
        let changes = page.map { key, entity in
            SyncChangeWire(
                entityType: key.type.rawValue, entityID: key.id.description, state: entity.state.rawValue,
                version: entity.version, revision: entity.revision, document: entity.document)
        }
        return SyncChangesPageWire(
            changes: changes, nextAfter: hasMore ? (page.last?.1.revision ?? after) : head, hasMore: hasMore,
            headRevision: head)
    }

    private func check(_ account: AwradID) throws(SyncFailure) {
        if !failures.isEmpty { throw failures.removeFirst() }
        guard account == self.account else { throw .accountMismatch }
    }

    // MARK: - Rules

    private func receipt(_ command: SyncCommandWire) -> SyncReceiptWire {
        if let seen = stored[command.commandID] {
            guard seen.payload == command else {
                return .rejected(commandID: command.commandID, code: "command_id_reused", fields: [], current: nil)
            }
            return .duplicate(commandID: command.commandID, original: seen.receipt)
        }
        let receipt = decide(command)
        stored[command.commandID] = (command, receipt)
        return receipt
    }

    private func decide(_ command: SyncCommandWire) -> SyncReceiptWire {
        let id = command.commandID
        guard let type = SyncEntityType(rawValue: command.entityType), let entityID = AwradID(command.entityID) else {
            return .rejected(commandID: id, code: "document_invalid", fields: [], current: nil)
        }
        if type == .userTag, aliases[entityID] != nil { return .gone(commandID: id) }
        let key = SyncEntityKey(type, entityID)
        if command.op == "delete", type == .dhikrPersonal {
            return .rejected(commandID: id, code: "delete_not_allowed", fields: [], current: current(key))
        }
        if let entity = entities[key], entity.state == .deleted { return .gone(commandID: id) }
        guard entities[key] != nil || command.baseVersion == 0 else {
            return .rejected(commandID: id, code: "entity_not_found", fields: [], current: nil)
        }
        if let entity = entities[key], entity.version != command.baseVersion {
            return .conflict(
                commandID: id, current: current(key) ?? SyncCurrentWire(version: 0, state: "deleted", document: .null))
        }
        if let merged = mergeTag(command, key: key) { return merged }
        if type == .dhikrPersonal, namesUnknownTag(command.document ?? .null) {
            return .rejected(commandID: id, code: "tag_not_found", fields: [], current: current(key))
        }
        let document = type == .dhikrPersonal ? rewritten(command.document ?? .null) : command.document ?? .null
        if !rejections.isEmpty {
            return .rejected(commandID: id, code: rejections.removeFirst(), fields: [], current: current(key))
        }
        head += 1
        let version = (entities[key]?.version ?? 0) + 1
        let deleted = command.op == "delete"
        entities[key] = Entity(
            version: version, state: deleted ? .deleted : .active, revision: head, document: deleted ? .null : document)
        let cascaded = deleted && type != .dhikrPersonal ? cascade(key) : nil
        return .applied(commandID: id, version: version, revision: head, cascaded: cascaded)
    }

    /// A tag create whose name an active tag has is merged (its ID becomes an alias); a rename onto
    /// one is refused.
    private func mergeTag(_ command: SyncCommandWire, key: SyncEntityKey) -> SyncReceiptWire? {
        guard key.type == .userTag, command.op == "put",
            let name = command.document?["normalized_name"]?.stringValue,
            let (survivor, _) = entities.first(where: {
                $0.key.type == .userTag && $0.key != key && $0.value.state == .active
                    && $0.value.document["normalized_name"]?.stringValue == name
            })
        else { return nil }
        if entities[key] != nil {
            return .rejected(commandID: command.commandID, code: "tag_name_taken", fields: [], current: current(key))
        }
        aliases[key.id] = survivor.id
        return .merged(
            commandID: command.commandID, mergedInto: survivor.id.description,
            current: current(survivor) ?? SyncCurrentWire(version: 0, state: "deleted", document: .null))
    }

    /// Whether a personal record names a tag the account never had (neither a tag nor an alias).
    private func namesUnknownTag(_ document: AwradJSON) -> Bool {
        (document["tag_ids"]?.arrayValue ?? []).compactMap(\.stringValue).compactMap(AwradID.init).contains {
            aliases[$0] == nil && entities[SyncEntityKey(.userTag, $0)] == nil
        }
    }

    /// A personal record's tags: aliases become their tag, deleted tags go, repeats go.
    private func rewritten(_ document: AwradJSON) -> AwradJSON {
        var seen = Set<String>()
        let ids = (document["tag_ids"]?.arrayValue ?? []).compactMap(\.stringValue).compactMap { raw -> String? in
            let tag = AwradID(raw).map { aliases[$0] ?? $0 }
            guard let tag, entities[SyncEntityKey(.userTag, tag)]?.state == .active else { return nil }
            return tag.description
        }.filter { seen.insert($0).inserted }
        return .object(["tag_ids": .array(ids.map(AwradJSON.string))])
    }

    /// Applies a delete's cascade at the current revision and lists what it changed, as an `applied`
    /// receipt's `cascaded` does.
    @discardableResult
    private func cascade(_ key: SyncEntityKey) -> [SyncCascadeWire] {
        var changed: [SyncEntityKey] = []
        switch key.type {
        case .customDhikr:
            let personal = SyncEntityKey(.dhikrPersonal, key.id)
            if let entity = entities[personal], entity.state == .active {
                entities[personal] = Entity(
                    version: entity.version + 1, state: .deleted, revision: head, document: .null)
                changed.append(personal)
            }
        case .userTag:
            for (other, entity) in entities where other.type == .dhikrPersonal && entity.state == .active {
                let ids = entity.document["tag_ids"]?.arrayValue ?? []
                guard ids.contains(.string(key.id.description)) else { continue }
                let kept = ids.filter { $0 != .string(key.id.description) }
                entities[other] = Entity(
                    version: entity.version + 1, state: .active, revision: head,
                    document: .object(["tag_ids": .array(kept)]))
                changed.append(other)
            }
        case .dhikrPersonal:
            break
        }
        return changed.sorted().compactMap { changedKey in
            entities[changedKey].map {
                SyncCascadeWire(
                    entityType: changedKey.type.rawValue, entityID: changedKey.id.description,
                    state: $0.state.rawValue, version: $0.version, revision: $0.revision)
            }
        }
    }

    private func current(_ key: SyncEntityKey) -> SyncCurrentWire? {
        entities[key].map { SyncCurrentWire(version: $0.version, state: $0.state.rawValue, document: $0.document) }
    }
}
