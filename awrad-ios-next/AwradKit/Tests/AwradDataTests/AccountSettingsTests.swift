import AwradDomain
import Foundation
import Synchronization
import Testing

@testable import AwradData

// The account settings operations (slice 2b) against a scripted server: the requests they send,
// paging, the Idempotency-Key across a token refresh, and the session ending (revoked elsewhere,
// or the account deleted) clearing the credentials.

struct AccountSettingsTests {
    /// A server that refreshes any session and answers `operation` with `reply`.
    static func harness(
        _ operation: APIOperation, _ reply: @escaping @Sendable (URLRequest) -> ScriptedTransport.Reply
    ) throws -> SessionHarness {
        let harness = SessionHarness { request in
            if request.url?.path() == APIOperation.refreshDeviceSession.path {
                return .init(status: 200, body: Wire.grant(access: "access-1", refresh: "refresh-1"))
            }
            return reply(request)
        }
        try harness.storeCredentials()
        return harness
    }

    static func page(_ items: [String], next: String?) -> ScriptedTransport.Reply {
        let cursor = next.map { "\"\($0)\"" } ?? "null"
        return .init(
            status: 200, body: Data(#"{"items":[\#(items.joined(separator: ","))],"next_cursor":\#(cursor)}"#.utf8))
    }

    static func session(_ id: String, name: String?, platform: String, current: Bool = false) -> String {
        let name = name.map { "\"\($0)\"" } ?? "null"
        return #"""
            {"id":"\#(id)","kind":"\#(platform == "web" ? "browser" : "device")","name":\#(name),"platform":"\#(platform)","created_at":"2026-10-20T18:00:00Z","last_seen_at":"2026-10-26T21:15:00Z","is_current":\#(current)}
            """#
    }

    @Test func sessionsFollowEveryPage() async throws {
        let harness = try Self.harness(.listAccountSessions) { request in
            let cursor = URLComponents(url: request.url ?? URL(filePath: "/"), resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "cursor" }?.value
            return cursor == nil
                ? Self.page(
                    [
                        Self.session(
                            "9a7d1c42-3e5b-4f60-8a19-0c2d4e6f8b13", name: "iPhone 16 Pro", platform: "ios",
                            current: true),
                        Self.session("not-a-uuid", name: "Broken", platform: "ios"),
                    ], next: "c2lnbmVk")
                : Self.page(
                    [
                        Self.session("4c2e8f10-7b3a-4d5e-9f61-2a8b0c1d3e45", name: nil, platform: "web"),
                        Self.session("5f0c3b52-8d2e-4e57-9f0a-6b1d2c3e4f50", name: "Car", platform: "carplay"),
                    ], next: nil)
        }

        let sessions = try await harness.session.sessions()

        #expect(sessions.map(\.name) == ["iPhone 16 Pro", nil, "Car"], "an unreadable session is left out")
        #expect(sessions.map(\.platform) == [.ios, .web, .other])
        #expect(sessions.map(\.kind) == [.device, .browser, .device])
        #expect(sessions.map(\.isCurrent) == [true, false, false])
        let requests = harness.transport.requests(to: .listAccountSessions)
        #expect(requests.map { $0.url?.query() } == ["limit=100", "limit=100&cursor=c2lnbmVk"])
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer access-1" })
    }

    @Test func revokeDeletesThatSession() async throws {
        let harness = try Self.harness(.revokeAccountSession) { _ in .init(status: 204, body: Data()) }
        let id = try #require(AwradID("4c2e8f10-7b3a-4d5e-9f61-2a8b0c1d3e45"))

        try await harness.session.revokeSession(id)

        let request = try #require(harness.transport.requests.last)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path() == "/api/v1/account/sessions/4c2e8f10-7b3a-4d5e-9f61-2a8b0c1d3e45")
        #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == nil)
        #expect(request.httpBody == nil)
    }

    @Test func anEndedSessionIsNotFound() async throws {
        let harness = try Self.harness(.revokeAccountSession) { _ in Wire.problem("not_found", status: 404) }

        await #expect(throws: AccountError.notFound) { try await harness.session.revokeSession(.random()) }
        #expect(harness.storedCredentials() != nil)
    }

    @Test func aRetryAfterARefreshReusesTheIdempotencyKey() async throws {
        let attempts = Counter()
        let harness = try Self.harness(.changePassword) { _ in
            attempts.next() == 0 ? Wire.problem("unauthenticated", status: 401) : .init(status: 204, body: Data())
        }

        try await harness.session.changePassword(currentPassword: "old passphrase", newPassword: "a new passphrase")

        let requests = harness.transport.requests(to: .changePassword)
        #expect(requests.count == 2)
        let keys = requests.map { $0.value(forHTTPHeaderField: "Idempotency-Key") }
        let key = try #require(keys.first ?? nil)
        #expect(keys[1] == key)
        #expect(AwradID(key)?.description == key, "a lowercase UUID")
        #expect(requests.map { $0.value(forHTTPHeaderField: "Accept-Language") } == ["ar", "ar"])
        let body = try JSONDecoder().decode(ChangePasswordBody.self, from: try #require(requests[1].httpBody))
        #expect(body == ChangePasswordBody(currentPassword: "old passphrase", newPassword: "a new passphrase"))
        #expect(harness.storedCredentials() != nil, "this device stays signed in")
    }

    @Test func aSessionRevokedElsewhereSignsOut() async throws {
        let harness = SessionHarness { request in
            request.url?.path() == APIOperation.refreshDeviceSession.path
                ? Wire.problem("refresh_token_invalid", status: 401)
                : Wire.problem("unauthenticated", status: 401)
        }
        try harness.storeCredentials()

        await #expect(throws: AccountError.signedOut) { try await harness.session.revokeOtherSessions() }
        #expect(harness.storedCredentials() == nil)
        #expect(await harness.session.signedInAccount() == nil)
    }

    @Test func aFreshTokenRejectedAgainSignsOut() async throws {
        let harness = try Self.harness(.listAccountSessions) { _ in Wire.problem("unauthenticated", status: 401) }

        await #expect(throws: AccountError.signedOut) { try await harness.session.sessions() }
        #expect(harness.transport.requests(to: .listAccountSessions).count == 2)
        #expect(harness.storedCredentials() == nil)
    }

    @Test func deletingTheAccountForgetsTheCredentials() async throws {
        let harness = try Self.harness(.deleteAccount) { _ in .init(status: 204, body: Data()) }
        harness.store.set(Data("5f0c3b52-8d2e-4e57-9f0a-6b1d2c3e4f50".utf8), for: CredentialVault.installationIDKey)

        try await harness.session.deleteAccount(currentPassword: "a long passphrase")

        let request = try #require(harness.transport.requests(to: .deleteAccount).first)
        #expect(
            try JSONDecoder().decode(CurrentPasswordBody.self, from: #require(request.httpBody)).currentPassword
                == "a long passphrase")
        #expect(harness.transport.requests(to: .signOutDeviceSession).isEmpty, "every session already ended")
        #expect(harness.store.keys == [CredentialVault.installationIDKey])
        #expect(await harness.session.signedInAccount() == nil)
    }

    @Test func aWrongPasswordKeepsTheAccount() async throws {
        let harness = try Self.harness(.deleteAccount) { _ in
            Wire.problem("validation_failed", status: 422, fields: ["current_password_incorrect"])
        }

        await #expect(throws: AccountError.validationFailed([.currentPasswordIncorrect])) {
            try await harness.session.deleteAccount(currentPassword: "wrong")
        }
        #expect(harness.storedCredentials() != nil)
    }

    @Test func confirmingTheEmailKeepsTheNewAddress() async throws {
        let harness = try Self.harness(.confirmEmailChange) { _ in
            .init(
                status: 200,
                body: Data(
                    #"{"id":"\#(Wire.accountID)","email":"amina.new@example.com","created_at":"2026-10-26T08:00:00Z"}"#
                        .utf8))
        }

        try await harness.session.requestEmailChange(
            currentPassword: "a long passphrase", newEmail: "amina.new@example.com")
        let account = try await harness.session.confirmEmailChange(code: "519274")

        #expect(account.email == "amina.new@example.com")
        #expect(harness.storedCredentials()?.account.email == "amina.new@example.com")
        #expect(await harness.session.signedInAccount()?.email == "amina.new@example.com")
        let request = try #require(harness.transport.requests(to: .confirmEmailChange).first)
        #expect(try JSONDecoder().decode(EmailChangeCodeBody.self, from: #require(request.httpBody)).code == "519274")
    }

    @Test(arguments: [
        ("email_change_code_invalid", AccountError.emailChangeCodeInvalid),
        ("email_taken", .emailTaken),
        ("not_found", .notFound),
        ("csrf_token_invalid", .unexpected(code: "csrf_token_invalid")),
    ])
    func settingsCodesMapByCode(_ code: String, _ error: AccountError) {
        #expect(AccountError(.problem(ProblemWire(code: code, status: 422), retryAfterSeconds: nil)) == error)
    }

    @Test func settingsFieldCodesMap() {
        let problem = ProblemWire(
            code: "validation_failed", status: 422,
            errors: [
                .init(field: "/current_password", code: "current_password_incorrect", detail: ""),
                .init(field: "/new_email", code: "email_unchanged", detail: ""),
            ])
        #expect(
            AccountError(.problem(problem, retryAfterSeconds: nil))
                == .validationFailed([.currentPasswordIncorrect, .emailUnchanged]))
    }
}

/// Counts calls from any thread.
final class Counter: Sendable {
    private let value = Mutex(0)

    /// The count before this call.
    func next() -> Int {
        value.withLock { count in
            defer { count += 1 }; return count
        }
    }
}
