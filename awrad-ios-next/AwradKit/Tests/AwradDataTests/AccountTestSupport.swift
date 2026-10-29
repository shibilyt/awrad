import AwradDomain
import Foundation
import Synchronization

@testable import AwradData

// Test doubles for the account adapter's own seams (transport, secure storage, installation
// marker). They stay here, not in AwradTesting, because those seams aren't domain ports (ADR 0004).

/// A scripted server: each request goes to `respond`, and every request is recorded.
final class ScriptedTransport: HTTPTransport {
    struct Reply: Sendable {
        let status: Int
        let body: Data
        var headers: [String: String] = [:]
    }

    typealias Responder = @Sendable (URLRequest) async throws -> Reply

    private let responder: Mutex<Responder>
    private let log = Mutex<[URLRequest]>([])

    init(_ respond: @escaping Responder) {
        responder = Mutex(respond)
    }

    var requests: [URLRequest] { log.withLock { $0 } }

    func requests(to operation: APIOperation) -> [URLRequest] {
        requests.filter { $0.url?.path() == operation.path }
    }

    func respond(with respond: @escaping Responder) {
        responder.withLock { $0 = respond }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        log.withLock { $0.append(request) }
        let respond = responder.withLock { $0 }
        let reply = try await respond(request)
        let url = request.url ?? URL(filePath: "/")
        let response = HTTPURLResponse(
            url: url, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)
        return (reply.body, response ?? HTTPURLResponse())
    }
}

/// A keychain in memory that can refuse writes (a locked or full keychain) or reads.
final class InMemorySecureStore: SecureStore {
    struct Refused: Error {}

    private struct State {
        var items: [String: Data] = [:]
        /// Keys whose writes throw; `nil` refuses every key.
        var refusedWrites: Set<String>?
        var refusingWrites = false
        var refusingReads = false
    }

    private let state = Mutex(State())

    var keys: Set<String> { Set(state.withLock { $0.items.keys }) }

    /// Makes `set` throw, for every key or only for `keys`, until `acceptWrites()`.
    func refuseWrites(only keys: Set<String>? = nil) {
        state.withLock {
            $0.refusingWrites = true
            $0.refusedWrites = keys
        }
    }

    func acceptWrites() { state.withLock { $0.refusingWrites = false } }
    func refuseReads(_ refuse: Bool) { state.withLock { $0.refusingReads = refuse } }

    func data(for key: String) throws -> Data? {
        try state.withLock {
            if $0.refusingReads { throw Refused() }
            return $0.items[key]
        }
    }

    func set(_ data: Data, for key: String) throws {
        try state.withLock {
            if $0.refusingWrites, $0.refusedWrites?.contains(key) ?? true { throw Refused() }
            $0.items[key] = data
        }
    }
    func remove(_ key: String) { _ = state.withLock { $0.items.removeValue(forKey: key) } }
}

final class InMemoryInstallationMarker: InstallationMarker {
    private let marked: Mutex<Bool>

    init(marked: Bool = true) {
        self.marked = Mutex(marked)
    }

    func isMarked() -> Bool { marked.withLock { $0 } }
    func mark() { marked.withLock { $0 = true } }
}

/// Server responses in the spec's shapes.
enum Wire {
    static let accountID = "0b6f6a1e-6c1f-4b8e-9a51-2f3d7c1e8a90"
    static let epoch = Date(timeIntervalSince1970: 1_793_000_000)

    static func grant(access: String, refresh: String, expiresAt: Date = epoch.addingTimeInterval(900)) -> Data {
        let grant = DeviceSessionGrantWire(
            account: AccountWire(id: accountID, email: "amina@example.com", createdAt: "2026-10-26T08:00:00Z"),
            session: DeviceSessionWire(
                id: "9a7d1c42-3e5b-4f60-8a19-0c2d4e6f8b13", deviceName: "iPhone 16 Pro", platform: "ios",
                createdAt: "2026-10-26T08:05:00Z", lastSeenAt: "2026-10-26T08:05:00Z",
                idleExpiresAt: "2026-11-25T08:05:00Z", absoluteExpiresAt: "2027-04-24T08:05:00Z"),
            accessToken: access,
            accessTokenExpiresAt: WireInstant.string(expiresAt),
            refreshToken: refresh)
        return (try? JSONEncoder().encode(grant)) ?? Data()
    }

    static func account() -> Data {
        Data(#"{"id":"\#(accountID)","email":"amina@example.com","created_at":"2026-10-26T08:00:00Z"}"#.utf8)
    }

    static func problem(_ code: String, status: Int, fields: [String] = []) -> ScriptedTransport.Reply {
        let errors = fields.map { ProblemWire.FieldError(field: "/password", code: $0, detail: $0) }
        let body = (try? JSONEncoder().encode(ProblemWire(code: code, status: status, errors: errors))) ?? Data()
        return .init(status: status, body: body, headers: ["Content-Type": "application/problem+json"])
    }

    static func refreshToken(in request: URLRequest) -> String? {
        request.httpBody.flatMap { try? JSONDecoder().decode(RefreshTokenBody.self, from: $0) }?.refreshToken
    }
}

/// A session wired to the doubles, with a fixed clock.
struct SessionHarness {
    let transport: ScriptedTransport
    let store = InMemorySecureStore()
    let marker = InMemoryInstallationMarker()
    let session: AuthSession

    init(_ respond: @escaping ScriptedTransport.Responder) {
        transport = ScriptedTransport(respond)
        session = AuthSession(
            baseURL: URL(string: "http://localhost:4000") ?? URL(filePath: "/"),
            transport: transport, store: store, marker: marker, deviceName: "iPhone 16 Pro",
            language: { "ar" }, now: { Wire.epoch })
    }

    /// Puts signed-in credentials in the store, as a previous launch would have left them.
    func storeCredentials(refresh: String = "refresh-token-0000") throws {
        let account = AccountWire(id: Wire.accountID, email: "amina@example.com", createdAt: "2026-10-26T08:00:00Z")
        let stored = StoredCredentials(account: account, refreshToken: refresh, pendingRefreshKey: nil)
        try store.set(JSONEncoder().encode(stored), for: CredentialVault.credentialsKey)
    }

    func storedCredentials() -> StoredCredentials? {
        ((try? store.data(for: CredentialVault.credentialsKey)) ?? nil).flatMap {
            try? JSONDecoder().decode(StoredCredentials.self, from: $0)
        }
    }
}
