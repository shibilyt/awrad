import AwradDomain
import Foundation

/// One sync of one profile (contracts/sync/v1 README, "Sending and pulling"): send the queue in
/// order, in batches of up to 100, applying each batch's receipts in one transaction; then read the
/// changes feed from the stored `after`, applying each page with its `next_after` in one
/// transaction. Every request carries the profile's account.
struct SyncPass: Sendable {
    static let batchSize = 100
    static let pageSize = 200
    /// Guards against a server that never lets the queue drain or the feed end.
    static let maxRounds = 1000

    /// What a pass leaves for the phone.
    struct Result: Equatable, Sendable {
        var notices: [SyncNotice] = []
        /// Recordings to upload again after an `audio_not_found` or `audio_mismatch` rejection, with
        /// the file each is on the phone.
        var uploadsQueued: [AwradID: URL] = [:]
    }

    let server: any SyncServer
    /// Each custom dhikr's recording file on the phone, read only when a batch has a put rejected
    /// for its recording.
    var recordingFiles: @Sendable () async -> [AwradID: URL] = { [:] }

    func run(_ database: ProfileDatabase, account: AwradID) async throws(SyncFailure) -> Result {
        var result = Result()
        for _ in 0..<Self.maxRounds {
            let batch = try await storage { try await database.nextBatch(limit: Self.batchSize) }
            guard !batch.isEmpty else { break }
            let wire = try await server.send(batch, account: account)
            let types = Dictionary(
                batch.map { ($0.commandID.description, $0.key.type) }, uniquingKeysWith: { a, _ in a })
            let receipts = wire.receipts.compactMap { receipt in
                types[receipt.commandID].flatMap(receipt.receipt(type:))
            }
            let files = receipts.contains(where: \.isAudioRejection) ? await recordingFiles() : [:]
            let outcome = try await storage {
                try await database.apply(receipts, localAudioFiles: Set(files.keys))
            }
            result.notices += outcome.notices
            for dhikr in outcome.uploadsQueued { result.uploadsQueued[dhikr] = files[dhikr] }
            // A batch whose receipts the client can't read leaves its commands queued: stop here
            // instead of resending them in a loop; the next sync tries again.
            guard !receipts.isEmpty else { break }
        }
        var after = await database.summary().after
        for _ in 0..<Self.maxRounds {
            let wire = try await server.changes(after: after, limit: Self.pageSize, account: account)
            let page = wire.page
            try await storage { try await database.apply(page) }
            guard page.hasMore, page.nextAfter > after else { break }
            after = page.nextAfter
        }
        return result
    }

    /// A local write that failed: treated like an unavailable server, so the pass is retried.
    private func storage<Value>(_ write: () async throws -> Value) async throws(SyncFailure) -> Value {
        do {
            return try await write()
        } catch {
            throw .unavailable
        }
    }
}

extension SyncReceipt {
    /// A rejection about a put's recording (`audio_not_found`, `audio_mismatch`).
    var isAudioRejection: Bool {
        if case .rejected(_, let code, _, _) = outcome { return code.isAboutAudio }
        return false
    }
}
