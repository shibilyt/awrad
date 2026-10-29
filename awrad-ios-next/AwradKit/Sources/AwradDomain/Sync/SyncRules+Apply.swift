import Foundation

// What a phone does with what comes back from the server (contracts/sync/v1/fixtures/apply_changes.json).

extension SyncRules {
    /// Applies one changes page, then moves `after` to its `next_after`. The caller saves both in
    /// one transaction.
    ///
    /// - A delete cleans up as a `gone` receipt does, even with queued commands or an open
    ///   conflict: the entity goes with its unsent commands and its conflict (sent commands wait for
    ///   their receipts). A delete of something the phone doesn't have changes nothing.
    /// - Any other change to an entity with a queued command or an open conflict updates only its
    ///   known version (and the conflict's server copy): the local edit stays, and its conflict
    ///   surfaces when it's sent.
    /// - Otherwise an active change is stored, unless it's older than the known version.
    public static func apply(_ page: ChangesPage, to state: inout some SyncLocalState) {
        for change in page.changes {
            let key = change.key
            let known = state.knownVersion(key)
            if change.state == .deleted {
                remove(key, in: &state)
                continue
            }
            if state.hasPendingEdit(key) {
                state.setKnownVersion(max(known, change.version), for: key)
                if var conflict = state.conflict(key), change.version >= conflict.server.version {
                    conflict.server = ServerCopy(
                        version: change.version, state: change.state, document: change.document)
                    state.setConflict(conflict, for: key)
                }
                continue
            }
            guard change.version >= known else { continue }
            state.setDocument(change.document, for: key)
            state.setKnownVersion(change.version, for: key)
        }
        state.after = page.nextAfter
    }

    /// Applies the receipts for sent commands, matched by `command_id`; each removes its command.
    /// Returns a notice for every rejected change, and the custom dhikrs whose recording must be
    /// uploaded again.
    ///
    /// | Receipt | Effect |
    /// |---|---|
    /// | `applied` | Records the version, closes any conflict, and applies its `cascaded` entries |
    /// | `duplicate` | As its original |
    /// | `conflict` | Keeps the local document, drops later unsent commands for the entity, opens a conflict |
    /// | `merged` | Moves every local use of the tag ID to the surviving tag |
    /// | `gone` | Removes the entity |
    /// | `rejected` | Restores the server's copy, or removes the entity when there is none |
    /// | `rejected` `audio_not_found`/`audio_mismatch` of a custom dhikr put | Keeps the edit (`keepAfterAudioRejection`) |
    ///
    /// - Parameters:
    ///   - localAudioFiles: the custom dhikrs whose recording file is on the phone.
    ///   - newCommandID: the ID of each command this queues, in order.
    @discardableResult
    public static func apply(
        _ receipts: [SyncReceipt], to state: inout some SyncLocalState, localAudioFiles: Set<AwradID> = [],
        newCommandID: () -> AwradID = AwradID.random
    ) -> ReceiptsOutcome {
        var notices: [SyncNotice] = []
        var uploads = Set<AwradID>()
        for receipt in receipts {
            guard let index = state.outbox.firstIndex(where: { $0.commandID == receipt.commandID }) else { continue }
            let command = state.outbox[index]
            state.removeCommand(command.commandID)
            let key = command.key
            if case .rejected(_, let code, _, let current) = receipt.outcome, code.isAboutAudio,
                command.op == .put, key.type == .customDhikr, current?.state != .deleted
            {
                let rejection = AudioRejection(
                    key: key, index: index, current: current, hasFile: localAudioFiles.contains(key.id))
                if keepAfterAudioRejection(rejection, newCommandID: newCommandID(), in: &state) {
                    uploads.insert(key.id)
                }
                notices.append(SyncNotice(code: code, key: key))
                continue
            }
            switch receipt.outcome {
            case .applied(_, let version, _, let cascaded):
                if state.document(key) == nil, state.commands(for: key).isEmpty {
                    state.setKnownVersion(nil, for: key)
                } else {
                    state.setKnownVersion(version, for: key)
                }
                state.setConflict(nil, for: key)
                for cascade in cascaded ?? [] { apply(cascade, to: &state) }
            case .conflict(_, let current):
                dropUnsentCommands(for: key, in: &state)
                state.setKnownVersion(current.version, for: key)
                let localOp: SyncOp = state.document(key) == nil ? .delete : .put
                state.setConflict(SyncConflict(key: key, localOp: localOp, server: current), for: key)
            case .merged(_, let survivor, let current):
                merge(tag: key.id, into: survivor, current: current, in: &state)
            case .gone:
                remove(key, in: &state)
            case .rejected(_, let code, _, let current):
                restore(key, to: current, in: &state)
                notices.append(SyncNotice(code: code, key: key))
            case .duplicate:
                break  // `outcome` is never a duplicate.
            }
        }
        return ReceiptsOutcome(notices: notices, uploadsQueued: uploads.sorted { $0.description < $1.description })
    }

    /// The user's answer to an open conflict. Keep mine queues the local version (or its delete)
    /// on the server's version; Use theirs takes the server's copy. `commandID` is the new
    /// command's, for Keep mine.
    public static func resolve(
        _ key: SyncEntityKey, choice: ConflictChoice, commandID: AwradID = .random(),
        in state: inout some SyncLocalState
    ) {
        guard let conflict = state.conflict(key) else { return }
        state.setConflict(nil, for: key)
        switch choice {
        case .keepMine:
            state.setKnownVersion(conflict.server.version, for: key)
            let document = state.document(key)
            let edit = SyncEdit(
                commandID: commandID, key: key, op: document == nil ? .delete : .put, document: document)
            enqueue(edit, in: &state)
        case .useTheirs:
            dropUnsentCommands(for: key, in: &state)
            restore(key, to: conflict.server, in: &state)
        }
    }

    // MARK: - Steps

    /// A delete's cascade, applied as a page change would be to an entity the phone has: an active
    /// one moves its known version (never back), a deleted one is removed. A command already queued
    /// for it keeps its `base_version` and conflicts as normal.
    private static func apply(_ cascade: SyncCascade, to state: inout some SyncLocalState) {
        let key = cascade.key
        let known = state.knownVersion(key)
        guard state.document(key) != nil || known > 0 || !state.commands(for: key).isEmpty else { return }
        switch cascade.state {
        case .active: state.setKnownVersion(max(known, cascade.version), for: key)
        case .deleted: remove(key, in: &state)
        }
    }

    /// Puts the server's copy back, or removes the entity when the server has none (or deleted it).
    /// Later unsent commands for the entity are dropped: they were made on the undone version.
    private static func restore(_ key: SyncEntityKey, to copy: ServerCopy?, in state: inout some SyncLocalState) {
        guard let copy, copy.state == .active, let document = copy.document else {
            remove(key, in: &state)
            return
        }
        dropUnsentCommands(for: key, in: &state)
        state.setDocument(document, for: key)
        state.setKnownVersion(copy.version, for: key)
        state.setConflict(nil, for: key)
    }

    /// A tag create the server merged into an existing tag: the local tag goes (with its unsent
    /// commands), the surviving tag takes its place if the phone doesn't have it yet, and every
    /// local use of the old ID moves to the survivor without repeats.
    private static func merge(
        tag old: AwradID, into survivor: AwradID, current: ServerCopy, in state: inout some SyncLocalState
    ) {
        let oldKey = SyncEntityKey(.userTag, old)
        let survivorKey = SyncEntityKey(.userTag, survivor)
        state.setDocument(nil, for: oldKey)
        state.setConflict(nil, for: oldKey)
        dropUnsentCommands(for: oldKey, in: &state)
        if state.commands(for: oldKey).isEmpty { state.setKnownVersion(nil, for: oldKey) }
        if !state.hasPendingEdit(survivorKey), current.version >= state.knownVersion(survivorKey),
            let document = current.document
        {
            state.setDocument(document, for: survivorKey)
            state.setKnownVersion(current.version, for: survivorKey)
        }
        rewriteTag(old, to: survivor, in: &state)
    }
}
