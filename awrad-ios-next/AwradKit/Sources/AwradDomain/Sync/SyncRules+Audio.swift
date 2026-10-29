import Foundation

// A custom dhikr put the server rejected for its recording (slice 3c, contracts/sync/v1 README
// "Audio rejections lose nothing"; apply_changes.json `receipt_audio_*`).

/// One `audio_not_found` or `audio_mismatch` rejection, as the rule needs it.
struct AudioRejection {
    let key: SyncEntityKey
    /// Where the rejected put was in the outbox, before it was removed.
    let index: Int
    /// The server's copy (`nil` when it has none).
    let current: ServerCopy?
    /// Whether the recording's file is still on the phone.
    let hasFile: Bool
}

extension SyncRules {
    /// Keeps the local edit of a custom dhikr whose put was rejected for its recording, and returns
    /// whether the recording goes back into the upload queue.
    ///
    /// - The local document stays, with `audio` `{"local_only": true}` when the file is still on the
    ///   phone (it's uploaded again under a new asset), or `null` otherwise.
    /// - Its known version becomes the server's (0 when the server has none), and its unsent
    ///   commands are replaced by one put of the kept document on that version, queued where the
    ///   rejected put was: ahead of every other unsent command, so a personal record that needs the
    ///   dhikr still follows it.
    /// - If the user has deleted the dhikr since, its unsent delete becomes a delete on the server's
    ///   version, or nothing when the server has no copy.
    static func keepAfterAudioRejection(
        _ rejection: AudioRejection, newCommandID: AwradID, in state: inout some SyncLocalState
    ) -> Bool {
        let key = rejection.key
        dropUnsentCommands(for: key, in: &state)
        state.setConflict(nil, for: key)
        guard case .customDhikr(var document)? = state.document(key) else {
            guard let current = rejection.current else {
                if state.commands(for: key).isEmpty { state.setKnownVersion(nil, for: key) }
                return false
            }
            state.setKnownVersion(current.version, for: key)
            state.insertCommand(
                OutboxCommand(
                    commandID: newCommandID, key: key, op: .delete, baseVersion: current.version, document: nil),
                at: rejection.index)
            return false
        }
        let version = rejection.current?.version ?? 0
        document.audio = rejection.hasFile ? .localOnly : nil
        state.setDocument(.customDhikr(document), for: key)
        state.setKnownVersion(version, for: key)
        state.insertCommand(
            OutboxCommand(
                commandID: newCommandID, key: key, op: .put, baseVersion: version, document: .customDhikr(document)),
            at: rejection.index)
        return rejection.hasFile
    }
}
