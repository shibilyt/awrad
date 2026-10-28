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

    let server: any SyncServer

    /// Returns the notices of rejected changes.
    func run(_ database: ProfileDatabase, account: AwradID) async throws(SyncFailure) -> [SyncNotice] {
        var notices: [SyncNotice] = []
        for _ in 0..<Self.maxRounds {
            let batch = try await storage { try await database.nextBatch(limit: Self.batchSize) }
            guard !batch.isEmpty else { break }
            let wire = try await server.send(batch, account: account)
            let types = Dictionary(
                batch.map { ($0.commandID.description, $0.key.type) }, uniquingKeysWith: { a, _ in a })
            let receipts = wire.receipts.compactMap { receipt in
                types[receipt.commandID].flatMap(receipt.receipt(type:))
            }
            notices += try await storage { try await database.apply(receipts) }
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
        return notices
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
