import AwradDomain
import Foundation
import SwiftData

/// `SyncLocalState` over one profile's `ModelContext`. The sync rules change records through it, and
/// the caller saves the context once, so a rule's whole effect (an edit and its command, a page and
/// its `after`) is one transaction. Each call reads or writes only the records of the entity it
/// names; nothing compares the whole store.
struct SwiftDataSyncState: SyncLocalState {
    let context: ModelContext

    // MARK: - Feed position

    var after: Int {
        get { position()?.after ?? 0 }
        nonmutating set {
            if let record = position() {
                record.after = newValue
            } else {
                context.insert(SyncPositionRecord(after: newValue))
            }
        }
    }

    private func position() -> SyncPositionRecord? {
        try? context.fetch(FetchDescriptor<SyncPositionRecord>()).first
    }

    // MARK: - Documents

    func document(_ key: SyncEntityKey) -> SyncDocument? {
        let id = key.id.value
        switch key.type {
        case .customDhikr:
            guard let record = fetchOne(#Predicate<CustomDhikrRecord> { $0.id == id }),
                let json = try? AwradJSON.decode(record.document)
            else { return nil }
            return try? SyncDocument(type: .customDhikr, json: json)
        case .userTag:
            return fetchOne(#Predicate<UserTagRecord> { $0.id == id }).map {
                .userTag(UserTagDocument(name: $0.name, normalizedName: $0.normalizedName))
            }
        case .dhikrPersonal:
            return fetchOne(#Predicate<DhikrPersonalRecord> { $0.id == id }).map {
                .dhikrPersonal(DhikrPersonalDocument(tagIDs: $0.tagIDs.compactMap(AwradID.init)))
            }
        }
    }

    func setDocument(_ document: SyncDocument?, for key: SyncEntityKey) {
        let id = key.id.value
        switch (key.type, document) {
        case (.customDhikr, .customDhikr(let custom)):
            let data = custom.json.encoded()
            if let record = fetchOne(#Predicate<CustomDhikrRecord> { $0.id == id }) {
                record.document = data
            } else {
                context.insert(CustomDhikrRecord(id: id, document: data))
            }
        case (.userTag, .userTag(let tag)):
            if let record = fetchOne(#Predicate<UserTagRecord> { $0.id == id }) {
                record.name = tag.name
                record.normalizedName = tag.normalizedName
            } else {
                context.insert(UserTagRecord(id: id, name: tag.name, normalizedName: tag.normalizedName))
            }
        case (.dhikrPersonal, .dhikrPersonal(let personal)):
            let ids = personal.tagIDs.map(\.description)
            if let record = fetchOne(#Predicate<DhikrPersonalRecord> { $0.id == id }) {
                record.tagIDs = ids
            } else {
                context.insert(DhikrPersonalRecord(id: id, tagIDs: ids))
            }
        case (.customDhikr, _):
            fetchOne(#Predicate<CustomDhikrRecord> { $0.id == id }).map(context.delete)
        case (.userTag, _):
            fetchOne(#Predicate<UserTagRecord> { $0.id == id }).map(context.delete)
        case (.dhikrPersonal, _):
            fetchOne(#Predicate<DhikrPersonalRecord> { $0.id == id }).map(context.delete)
        }
    }

    func personalRecords(tagged tag: AwradID) -> [SyncEntityKey] {
        let wire = tag.description
        let records = (try? context.fetch(FetchDescriptor<DhikrPersonalRecord>())) ?? []
        return records.filter { $0.tagIDs.contains(wire) }.map { SyncEntityKey(.dhikrPersonal, AwradID($0.id)) }
            .sorted()
    }

    func allKeys() -> [SyncEntityKey] {
        let dhikrs = (try? context.fetch(FetchDescriptor<CustomDhikrRecord>())) ?? []
        let tags = (try? context.fetch(FetchDescriptor<UserTagRecord>())) ?? []
        let personal = (try? context.fetch(FetchDescriptor<DhikrPersonalRecord>())) ?? []
        return
            (dhikrs.map { SyncEntityKey(.customDhikr, AwradID($0.id)) }
            + tags.map { SyncEntityKey(.userTag, AwradID($0.id)) }
            + personal.map { SyncEntityKey(.dhikrPersonal, AwradID($0.id)) }).sorted()
    }

    // MARK: - Known versions

    func knownVersion(_ key: SyncEntityKey) -> Int {
        let wire = key.description
        return fetchOne(#Predicate<KnownVersionRecord> { $0.key == wire })?.version ?? 0
    }

    func setKnownVersion(_ version: Int?, for key: SyncEntityKey) {
        let wire = key.description
        let record = fetchOne(#Predicate<KnownVersionRecord> { $0.key == wire })
        switch (record, version) {
        case (let record?, let version?): record.version = version
        case (nil, let version?): context.insert(KnownVersionRecord(key: wire, version: version))
        case (let record?, nil): context.delete(record)
        case (nil, nil): break
        }
    }

    // MARK: - Outbox

    var outbox: [OutboxCommand] {
        commandRecords().compactMap(\.command)
    }

    func commandRecords() -> [OutboxCommandRecord] {
        (try? context.fetch(FetchDescriptor<OutboxCommandRecord>(sortBy: [SortDescriptor(\.position)]))) ?? []
    }

    func appendCommand(_ command: OutboxCommand) {
        var last = FetchDescriptor<OutboxCommandRecord>(sortBy: [SortDescriptor(\.position, order: .reverse)])
        last.fetchLimit = 1
        let position = ((try? context.fetch(last).first?.position) ?? 0) + 1
        context.insert(
            OutboxCommandRecord(
                commandID: command.commandID.value, position: position, entityType: command.key.type.rawValue,
                entityID: command.key.id.value, op: command.op.rawValue, baseVersion: command.baseVersion,
                document: command.document?.json.encoded(), sent: command.sent))
    }

    func replaceCommand(_ command: OutboxCommand) {
        let id = command.commandID.value
        guard let record = fetchOne(#Predicate<OutboxCommandRecord> { $0.commandID == id }) else { return }
        record.op = command.op.rawValue
        record.baseVersion = command.baseVersion
        record.document = command.document?.json.encoded()
        record.sent = command.sent
    }

    func removeCommand(_ commandID: AwradID) {
        let id = commandID.value
        fetchOne(#Predicate<OutboxCommandRecord> { $0.commandID == id }).map(context.delete)
    }

    // MARK: - Conflicts

    func conflict(_ key: SyncEntityKey) -> SyncConflict? {
        let wire = key.description
        return fetchOne(#Predicate<SyncConflictRecord> { $0.key == wire })?.conflict(key: key)
    }

    func setConflict(_ conflict: SyncConflict?, for key: SyncEntityKey) {
        let wire = key.description
        let record = fetchOne(#Predicate<SyncConflictRecord> { $0.key == wire })
        guard let conflict else {
            record.map(context.delete)
            return
        }
        let document = conflict.server.document?.json.encoded()
        if let record {
            record.localOp = conflict.localOp.rawValue
            record.serverVersion = conflict.server.version
            record.serverState = conflict.server.state.rawValue
            record.serverDocument = document
        } else {
            context.insert(
                SyncConflictRecord(
                    key: wire, localOp: conflict.localOp.rawValue, serverVersion: conflict.server.version,
                    serverState: conflict.server.state.rawValue, serverDocument: document))
        }
    }

    func allConflicts() -> [SyncConflict] {
        let records = (try? context.fetch(FetchDescriptor<SyncConflictRecord>())) ?? []
        return records.compactMap { record in SyncEntityKey(wire: record.key).flatMap(record.conflict) }.sorted {
            $0.key < $1.key
        }
    }

    // MARK: - Helpers

    private func fetchOne<Model: PersistentModel>(_ predicate: Predicate<Model>) -> Model? {
        var descriptor = FetchDescriptor<Model>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

extension SyncEntityKey {
    /// From `entity_type/entity_id`.
    init?(wire: String) {
        let parts = wire.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2, let type = SyncEntityType(rawValue: parts[0]), let id = AwradID(parts[1]) else {
            return nil
        }
        self.init(type, id)
    }
}

extension OutboxCommandRecord {
    var command: OutboxCommand? {
        guard let type = SyncEntityType(rawValue: entityType), let op = SyncOp(rawValue: op) else { return nil }
        let document = self.document.flatMap { try? AwradJSON.decode($0) }.flatMap {
            try? SyncDocument(type: type, json: $0)
        }
        return OutboxCommand(
            commandID: AwradID(commandID), key: SyncEntityKey(type, AwradID(entityID)), op: op,
            baseVersion: baseVersion, document: document, sent: sent)
    }
}

extension SyncConflictRecord {
    func conflict(key: SyncEntityKey) -> SyncConflict? {
        guard let localOp = SyncOp(rawValue: localOp), let state = SyncEntityState(rawValue: serverState) else {
            return nil
        }
        let document = serverDocument.flatMap { try? AwradJSON.decode($0) }.flatMap {
            try? SyncDocument(type: key.type, json: $0)
        }
        return SyncConflict(
            key: key, localOp: localOp, server: ServerCopy(version: serverVersion, state: state, document: document))
    }
}
