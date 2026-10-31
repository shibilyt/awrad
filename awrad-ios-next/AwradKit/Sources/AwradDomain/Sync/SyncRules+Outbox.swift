import Foundation

/// The phone's side of the change queue (contracts/sync/v1 README, "Phones"): saving an edit with
/// its command, applying receipts and changes pages, resolving conflicts. Each rule changes only
/// the entities it's about, through `SyncLocalState`; the caller runs it in one transaction.
public enum SyncRules {}

extension SyncRules {
    /// Saves a local edit: the document changes and, when the profile belongs to an account, its
    /// command is queued (`outbox_enqueue.json`). An anonymous profile saves without queuing.
    ///
    /// - A put stores the document. A delete removes the entity; deleting a custom dhikr removes
    ///   its personal record and ends its goals that haven't ended on `today` (`dhikr_deleted`,
    ///   without commands: the server ends them itself), and deleting a tag takes it out of every
    ///   personal record and never-sent personal command (only the tag delete is queued; the
    ///   server cascades it).
    /// - Parameter today: the practice day, for ending a deleted custom dhikr's goals; `nil` leaves
    ///   them as they are (for callers that delete no custom dhikr).
    public static func save(
        _ edit: SyncEdit, queue: Bool, today: CalendarDay? = nil, in state: inout some SyncLocalState
    ) {
        switch edit.op {
        case .put:
            state.setDocument(edit.document, for: edit.key)
        case .delete:
            state.setDocument(nil, for: edit.key)
            if edit.key.type == .customDhikr {
                let personal = SyncEntityKey(.dhikrPersonal, edit.key.id)
                state.setDocument(nil, for: personal)
                if !queue { state.setKnownVersion(nil, for: personal) }
                if let today { endGoals(ofDhikr: edit.key.id, on: today, in: &state) }
            }
            if edit.key.type == .userTag { removeTagFromPersonalRecords(edit.key.id, in: &state) }
        }
        if queue {
            enqueue(edit, in: &state)
        } else if edit.op == .delete {
            state.setKnownVersion(nil, for: edit.key)
        }
    }

    /// Queues one edit's command (`outbox_enqueue.json`):
    ///
    /// - If the entity's last queued command was never sent, the edit replaces it, keeping its
    ///   `command_id`, `base_version` and position. A delete that replaces a never-sent create
    ///   (`base_version` 0) removes it instead: the server never heard of the entity.
    /// - A replacement whose new document references an entity with a never-sent put later in the
    ///   queue moves to just after the last such put, so the server meets what it names first
    ///   (`moveAfterLaterReferences`).
    /// - Otherwise a command is added at the end, chained on the entity's last queued command
    ///   (`base_version` + 1), or on the known version when nothing is queued for it.
    /// - Deleting a custom dhikr also drops never-sent commands for its personal record, and, when
    ///   its own create was never sent, its goals' never-sent commands (the goals stay, ended).
    /// - Deleting a tag queues only the tag delete, and takes the tag out of every personal record
    ///   and never-sent personal command in place; sent ones stay, since the server drops the tag
    ///   itself and lists the records it changed in the receipt's `cascaded`.
    public static func enqueue(_ edit: SyncEdit, in state: inout some SyncLocalState) {
        let queued = state.commands(for: edit.key)
        var droppedNeverSentCreate = false
        if var last = queued.last, !last.sent {
            if edit.op == .delete, last.op == .put, last.baseVersion == 0 {
                state.removeCommand(last.commandID)
                droppedNeverSentCreate = true
            } else {
                last.op = edit.op
                last.document = edit.op == .put ? edit.document : nil
                state.replaceCommand(last)
                moveAfterLaterReferences(last, in: &state)
            }
        } else {
            let base = queued.last.map { $0.baseVersion + 1 } ?? state.knownVersion(edit.key)
            state.appendCommand(
                OutboxCommand(
                    commandID: edit.commandID, key: edit.key, op: edit.op, baseVersion: base,
                    document: edit.op == .put ? edit.document : nil))
        }
        if edit.op == .delete, edit.key.type == .customDhikr {
            dropUnsentCommands(for: SyncEntityKey(.dhikrPersonal, edit.key.id), in: &state)
            // The server never had the dhikr, so its goals' commands could only be rejected.
            if droppedNeverSentCreate {
                for goal in goalKeys(ofDhikr: edit.key.id, in: state) { dropUnsentCommands(for: goal, in: &state) }
            }
        }
        if edit.op == .delete, edit.key.type == .userTag {
            removeTagFromPersonalRecords(edit.key.id, in: &state)
        }
    }

    /// Adopting an anonymous profile ("Add to my account"): every entity is queued as a put on
    /// version 0, tags first, then custom dhikrs, then personal records, then goals, so each
    /// command's references exist on the server before it arrives. The practice policy and the
    /// goal order aren't among them: each is decided after the account's first complete pull.
    public static func queueAll(in state: inout some SyncLocalState) {
        let order: [SyncEntityType] = [.userTag, .customDhikr, .dhikrPersonal, .goal]
        let keys = state.allKeys().sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs.type) ?? 0
            let right = order.firstIndex(of: rhs.type) ?? 0
            return left == right ? lhs < rhs : left < right
        }
        // The practice policy follows its own first-sign-in rule (`PracticePolicy.afterSignIn`).
        for key in keys where !key.type.mergesAgainstBase {
            guard let document = state.document(key), state.commands(for: key).isEmpty else { continue }
            state.appendCommand(
                OutboxCommand(
                    commandID: .random(), key: key, op: .put, baseVersion: state.knownVersion(key),
                    document: document))
        }
    }

    // MARK: - Shared steps

    /// Moves a replaced command to just after the last never-sent put of an entity its document
    /// references (the tags in `tag_ids`, and a personal record's own custom dhikr), when that put
    /// sits later in the queue. Every other command keeps its relative order.
    static func moveAfterLaterReferences(_ command: OutboxCommand, in state: inout some SyncLocalState) {
        let references = command.references
        guard !references.isEmpty else { return }
        let outbox = state.outbox
        guard let index = outbox.firstIndex(where: { $0.commandID == command.commandID }) else { return }
        let later = outbox[(index + 1)...].last { !$0.sent && $0.op == .put && references.contains($0.key) }
        if let later { state.moveCommand(command.commandID, after: later.commandID) }
    }

    static func dropUnsentCommands(for key: SyncEntityKey, in state: inout some SyncLocalState) {
        for command in state.commands(for: key) where !command.sent {
            state.removeCommand(command.commandID)
        }
    }

    /// Removes an entity from the phone with its unsent commands and any conflict. A custom
    /// dhikr takes its personal record with it; a tag leaves every personal record and unsent
    /// command.
    static func remove(_ key: SyncEntityKey, in state: inout some SyncLocalState) {
        state.setDocument(nil, for: key)
        state.setConflict(nil, for: key)
        dropUnsentCommands(for: key, in: &state)
        if state.commands(for: key).isEmpty { state.setKnownVersion(nil, for: key) }
        switch key.type {
        case .customDhikr: remove(SyncEntityKey(.dhikrPersonal, key.id), in: &state)
        case .userTag: removeTagFromPersonalRecords(key.id, in: &state)
        case .dhikrPersonal, .goal: break
        case .practicePolicy, .goalOrder: state.setBaseDocument(nil, for: key)
        }
    }

    /// The goals of a custom dhikr on the phone: those whose document, or a queued command's,
    /// names it.
    static func goalKeys(ofDhikr dhikr: AwradID, in state: some SyncLocalState) -> [SyncEntityKey] {
        let stored = state.allKeys().filter { $0.type == .goal && state.document($0)?.goal?.dhikrID == dhikr }
        let queued = state.outbox.filter { $0.key.type == .goal && $0.document?.goal?.dhikrID == dhikr }.map(\.key)
        return Array(Set(stored + queued)).sorted()
    }

    /// Ends every goal of a deleted custom dhikr that hasn't ended, on `today` (decision 37).
    static func endGoals(ofDhikr dhikr: AwradID, on today: CalendarDay, in state: inout some SyncLocalState) {
        for key in goalKeys(ofDhikr: dhikr, in: state) {
            guard var goal = state.document(key)?.goal, goal.timeline.ended == nil else { continue }
            goal.timeline = goal.timeline.ending(GoalEnding(on: today, reason: .dhikrDeleted))
            state.setDocument(.goal(goal), for: key)
        }
    }

    static func removeTagFromPersonalRecords(_ tag: AwradID, in state: inout some SyncLocalState) {
        rewriteTag(tag, to: nil, in: &state)
    }

    /// Replaces `tag` with `replacement` (or drops it, for `nil`) in every personal record and every
    /// unsent personal command, keeping the first occurrence of each tag.
    static func rewriteTag(_ tag: AwradID, to replacement: AwradID?, in state: inout some SyncLocalState) {
        func rewritten(_ ids: [AwradID]) -> [AwradID] {
            var seen = Set<AwradID>()
            return ids.compactMap { $0 == tag ? replacement : $0 }.filter { seen.insert($0).inserted }
        }
        for key in state.personalRecords(tagged: tag) {
            guard let ids = state.document(key)?.tagIDs else { continue }
            state.setDocument(.dhikrPersonal(DhikrPersonalDocument(tagIDs: rewritten(ids))), for: key)
        }
        for var command in state.outbox where !command.sent && command.document?.tagIDs?.contains(tag) == true {
            guard let ids = command.document?.tagIDs else { continue }
            command.document = .dhikrPersonal(DhikrPersonalDocument(tagIDs: rewritten(ids)))
            state.replaceCommand(command)
        }
    }
}
