import AwradDomain
import Foundation

// Account settings (slice 2b): sessions, password, email and deletion. Each goes through
// `authorized`, so a session revoked elsewhere surfaces as `.signedOut` with the credentials
// already cleared. Nothing here touches local practice data.
extension AuthSession {
    /// Pages fetched at most for the session list; an account rarely has more than one.
    static let maximumSessionPages = 10
    static let sessionPageSize = 100

    public func sessions() async throws(AccountError) -> [AccountSession] {
        var sessions: [AccountSession] = []
        var cursor: String?
        for _ in 0..<Self.maximumSessionPages {
            var query = [URLQueryItem(name: "limit", value: String(Self.sessionPageSize))]
            if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
            let page = try await authorized { [query] token throws(APIFailure) in
                try await client.send(
                    .listAccountSessions, body: NoBody?.none, accessToken: token, query: query,
                    expecting: AccountSessionPageWire.self)
            }
            // A session the client can't read (a bad ID or instant) is left out, not fatal.
            sessions += page.items.compactMap(\.session)
            guard let next = page.nextCursor else { break }
            cursor = next
        }
        return sessions
    }

    public func revokeSession(_ id: AwradID) async throws(AccountError) {
        try await authorized { token throws(APIFailure) in
            try await client.send(
                .revokeAccountSession, body: NoBody?.none, accessToken: token,
                pathParameters: ["session_id": id.description])
        }
    }

    public func revokeOtherSessions() async throws(AccountError) {
        try await authorizedPost(.revokeOtherAccountSessions, NoBody?.none)
    }

    public func changePassword(currentPassword: String, newPassword: String) async throws(AccountError) {
        try await authorizedPost(
            .changePassword, ChangePasswordBody(currentPassword: currentPassword, newPassword: newPassword))
    }

    public func requestEmailChange(currentPassword: String, newEmail: String) async throws(AccountError) {
        try await authorizedPost(
            .requestEmailChange, RequestEmailChangeBody(currentPassword: currentPassword, newEmail: newEmail))
    }

    public func confirmEmailChange(code: String) async throws(AccountError) -> Account {
        let key = AwradID.random().description
        let wire = try await authorized { token throws(APIFailure) in
            try await client.send(
                .confirmEmailChange, body: EmailChangeCodeBody(code: code), accessToken: token,
                idempotencyKey: key, expecting: AccountWire.self)
        }
        return try remember(wire)
    }

    /// The server ends every session of the account, so there's nothing to sign out: the
    /// credentials are just forgotten.
    public func deleteAccount(currentPassword: String) async throws(AccountError) {
        try await authorizedPost(.deleteAccount, CurrentPasswordBody(currentPassword: currentPassword))
        forget()
    }

    /// An authenticated `POST` without a response body. A retry after a refreshed token reuses
    /// the request's `Idempotency-Key`.
    private func authorizedPost(
        _ operation: APIOperation,
        _ body: (some Encodable & Sendable)?
    ) async throws(AccountError) {
        let key = AwradID.random().description
        try await authorized { token throws(APIFailure) in
            try await client.send(operation, body: body, accessToken: token, idempotencyKey: key)
        }
    }
}
