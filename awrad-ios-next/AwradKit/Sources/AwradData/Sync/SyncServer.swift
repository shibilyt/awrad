import AwradDomain
import Foundation

/// Why a sync request didn't finish.
enum SyncFailure: Error, Equatable, Sendable {
    /// No response, a server fault, or a response the client can't read: try again later.
    case unavailable
    /// `429`: try again after `Retry-After` seconds when given.
    case rateLimited(retryAfterSeconds: Int?)
    /// `409 account_mismatch`: the signed-in account isn't the profile's. Nothing was read or written.
    case accountMismatch
    /// The device session ended: no credentials any more.
    case signedOut
    /// The refresh said the account no longer exists (`401 account_deleted`).
    case accountDeleted(AwradID)
}

/// The two change-queue operations, for one account: the sync engine's seam to the API (ADR 0004).
/// Every request names the account it expects (`X-Awrad-Account`).
protocol SyncServer: Sendable {
    func send(_ commands: [OutboxCommand], account: AwradID) async throws(SyncFailure) -> SyncReceiptBatchWire
    func changes(after: Int, limit: Int, account: AwradID) async throws(SyncFailure) -> SyncChangesPageWire
}

/// `SyncServer` over the Awrad API with this device's session.
struct APISyncServer: SyncServer {
    let session: AuthSession

    func send(_ commands: [OutboxCommand], account: AwradID) async throws(SyncFailure) -> SyncReceiptBatchWire {
        do {
            return try await session.postSyncCommands(
                SyncCommandBatchWire(commands: commands.map(SyncCommandWire.init)), account: account)
        } catch {
            throw await SyncFailure(error, session: session)
        }
    }

    func changes(after: Int, limit: Int, account: AwradID) async throws(SyncFailure) -> SyncChangesPageWire {
        do {
            return try await session.listSyncChanges(after: after, limit: limit, account: account)
        } catch {
            throw await SyncFailure(error, session: session)
        }
    }
}

// The change queue's requests with this device's session: the bearer token (refreshed as
// needed, through `authorized`) and the profile's account in `X-Awrad-Account`.
extension AuthSession {
    func postSyncCommands(_ body: SyncCommandBatchWire, account: AwradID) async throws(AccountError)
        -> SyncReceiptBatchWire
    {
        let headers = ["X-Awrad-Account": account.description]
        return try await authorized { token throws(APIFailure) in
            try await client.send(
                .postSyncCommands, body: body, accessToken: token, headers: headers,
                expecting: SyncReceiptBatchWire.self)
        }
    }

    func listSyncChanges(after: Int, limit: Int, account: AwradID) async throws(AccountError) -> SyncChangesPageWire {
        let headers = ["X-Awrad-Account": account.description]
        let query = [
            URLQueryItem(name: "after", value: String(after)), URLQueryItem(name: "limit", value: String(limit)),
        ]
        return try await authorized { token throws(APIFailure) in
            try await client.send(
                .listSyncChanges, body: NoBody?.none, accessToken: token, query: query, headers: headers,
                expecting: SyncChangesPageWire.self)
        }
    }
}

extension SyncFailure {
    /// The sync failure for an account error from an authorized request, by problem code only.
    init(_ error: AccountError, session: AuthSession) async {
        switch error {
        case .signedOut:
            self = await session.takeDeletedAccount().map(SyncFailure.accountDeleted) ?? .signedOut
        case .rateLimited(let seconds):
            self = .rateLimited(retryAfterSeconds: seconds)
        case .unexpected(code: "account_mismatch"):
            self = .accountMismatch
        default:
            self = .unavailable
        }
    }
}
