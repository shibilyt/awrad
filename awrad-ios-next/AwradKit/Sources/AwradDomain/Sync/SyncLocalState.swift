import Foundation

/// A profile's sync state, as the rules read and change it: the feed position, the documents on
/// the phone with the last server version known for each, the outbox and the open conflicts.
///
/// `InMemorySyncState` implements it for the fixtures; AwradData implements it over one SwiftData
/// `ModelContext`, so a rule's whole effect is saved in one transaction. The rules
/// (`SyncRules`) touch only the entities they're about: nothing diffs the whole store.
public protocol SyncLocalState {
    /// The changes-feed position: every change up to this revision is applied.
    var after: Int { get set }
    /// The outbox, oldest first.
    var outbox: [OutboxCommand] { get }

    func document(_ key: SyncEntityKey) -> SyncDocument?
    /// Stores the document, or removes the entity for `nil`.
    mutating func setDocument(_ document: SyncDocument?, for key: SyncEntityKey)
    /// The last server version seen for the entity; 0 when the server hasn't confirmed it.
    func knownVersion(_ key: SyncEntityKey) -> Int
    /// Records the version, or forgets it for `nil`.
    mutating func setKnownVersion(_ version: Int?, for key: SyncEntityKey)

    /// A `practice_policy`'s base: the server document its local document was edited from, which
    /// a conflict merges against (slice 3d). `nil` when the phone knows none (the default policy).
    func baseDocument(_ key: SyncEntityKey) -> SyncDocument?
    mutating func setBaseDocument(_ document: SyncDocument?, for key: SyncEntityKey)

    mutating func appendCommand(_ command: OutboxCommand)
    /// Inserts a command at `index` of the outbox (at the end when `index` is past it); the
    /// commands from there on move back one.
    mutating func insertCommand(_ command: OutboxCommand, at index: Int)
    /// Replaces the command with the same `commandID`, keeping its place in the queue.
    mutating func replaceCommand(_ command: OutboxCommand)
    mutating func removeCommand(_ commandID: AwradID)
    /// Moves a command to just after `target`, a later command; the rest keep their order.
    mutating func moveCommand(_ commandID: AwradID, after target: AwradID)

    func conflict(_ key: SyncEntityKey) -> SyncConflict?
    mutating func setConflict(_ conflict: SyncConflict?, for key: SyncEntityKey)

    /// Every `dhikr_personal` on the phone whose tags include `tag`.
    func personalRecords(tagged tag: AwradID) -> [SyncEntityKey]
    /// Every entity on the phone, for adopting an anonymous profile (`SyncRules.queueAll`).
    func allKeys() -> [SyncEntityKey]
}

extension SyncLocalState {
    /// The entity's queued commands, oldest first.
    public func commands(for key: SyncEntityKey) -> [OutboxCommand] {
        outbox.filter { $0.key == key }
    }

    /// Whether the entity has a queued command or an open conflict: then the feed updates only its
    /// known version.
    public func hasPendingEdit(_ key: SyncEntityKey) -> Bool {
        outbox.contains { $0.key == key } || conflict(key) != nil
    }
}

/// `SyncLocalState` in memory: the fixtures' local state.
public struct InMemorySyncState: SyncLocalState, Hashable, Sendable {
    public var after: Int
    public var documents: [SyncEntityKey: SyncDocument]
    public var knownVersions: [SyncEntityKey: Int]
    /// `practice_policy` bases.
    public var baseDocuments: [SyncEntityKey: SyncDocument]
    public private(set) var outbox: [OutboxCommand]
    public var conflicts: [SyncEntityKey: SyncConflict]

    public init(
        after: Int = 0, documents: [SyncEntityKey: SyncDocument] = [:], knownVersions: [SyncEntityKey: Int] = [:],
        baseDocuments: [SyncEntityKey: SyncDocument] = [:], outbox: [OutboxCommand] = [],
        conflicts: [SyncEntityKey: SyncConflict] = [:]
    ) {
        self.after = after
        self.documents = documents
        self.knownVersions = knownVersions
        self.baseDocuments = baseDocuments
        self.outbox = outbox
        self.conflicts = conflicts
    }

    public func document(_ key: SyncEntityKey) -> SyncDocument? { documents[key] }
    public mutating func setDocument(_ document: SyncDocument?, for key: SyncEntityKey) { documents[key] = document }
    public func knownVersion(_ key: SyncEntityKey) -> Int { knownVersions[key] ?? 0 }
    public mutating func setKnownVersion(_ version: Int?, for key: SyncEntityKey) { knownVersions[key] = version }
    public func baseDocument(_ key: SyncEntityKey) -> SyncDocument? { baseDocuments[key] }

    public mutating func setBaseDocument(_ document: SyncDocument?, for key: SyncEntityKey) {
        baseDocuments[key] = document
    }

    public mutating func appendCommand(_ command: OutboxCommand) { outbox.append(command) }

    public mutating func insertCommand(_ command: OutboxCommand, at index: Int) {
        outbox.insert(command, at: min(max(index, 0), outbox.count))
    }

    public mutating func replaceCommand(_ command: OutboxCommand) {
        guard let index = outbox.firstIndex(where: { $0.commandID == command.commandID }) else { return }
        outbox[index] = command
    }

    public mutating func removeCommand(_ commandID: AwradID) { outbox.removeAll { $0.commandID == commandID } }

    public mutating func moveCommand(_ commandID: AwradID, after target: AwradID) {
        guard let index = outbox.firstIndex(where: { $0.commandID == commandID }) else { return }
        let command = outbox.remove(at: index)
        let destination = outbox.firstIndex { $0.commandID == target }.map { $0 + 1 } ?? index
        outbox.insert(command, at: destination)
    }

    /// Marks commands as having been in a request.
    public mutating func markSent(_ commandIDs: Set<AwradID>) {
        for index in outbox.indices where commandIDs.contains(outbox[index].commandID) {
            outbox[index].sent = true
        }
    }

    public func conflict(_ key: SyncEntityKey) -> SyncConflict? { conflicts[key] }
    public mutating func setConflict(_ conflict: SyncConflict?, for key: SyncEntityKey) { conflicts[key] = conflict }

    public func personalRecords(tagged tag: AwradID) -> [SyncEntityKey] {
        documents.compactMap { key, document in document.tagIDs?.contains(tag) == true ? key : nil }.sorted()
    }

    public func allKeys() -> [SyncEntityKey] { documents.keys.sorted() }
}
