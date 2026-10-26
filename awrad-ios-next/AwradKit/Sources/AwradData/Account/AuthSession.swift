import AwradDomain
import Foundation

/// This device's account session (ADR-2026-07-12, root ADR-2026-10-26): the `AccountService`
/// adapter.
///
/// - The refresh token and account live in secure storage; the access token only in memory.
/// - At most one refresh runs at a time; concurrent callers share its result.
/// - A refresh always sends an `Idempotency-Key`, and a retry of the same refresh reuses it.
/// - Credentials are dropped only when the refresh is rejected (`refresh_token_invalid`,
///   `refresh_reuse_detected`), never on network errors or server faults.
/// - Nothing here touches local practice data.
public actor AuthSession: AccountService {
    /// How long before its stated expiry an access token is treated as expired.
    static let expiryMargin: TimeInterval = 60

    let client: APIClient
    private let vault: CredentialVault
    private let deviceName: String
    private let now: @Sendable () -> Date

    private var loaded = false
    private var credentials: StoredCredentials?
    private var access: (token: String, expiresAt: Date)?
    private var refreshTask: Task<Result<String, AccountError>, Never>?
    /// Changes whenever the session is replaced or ended, so a refresh that was in flight
    /// meanwhile can't bring back the session it started from.
    private var epoch = 0

    /// - Parameters:
    ///   - baseURL: The API origin, such as `http://localhost:4000`.
    ///   - language: The app's current language, sent as `Accept-Language`.
    ///   - deviceName: The name the session shows in the device list (`DeviceName.current()`).
    public init(
        baseURL: URL,
        transport: any HTTPTransport,
        store: any SecureStore,
        marker: any InstallationMarker,
        deviceName: String,
        language: @escaping @Sendable () -> String,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        client = APIClient(baseURL: baseURL, transport: transport, language: language)
        vault = CredentialVault(store: store, marker: marker)
        self.deviceName = deviceName
        self.now = now
    }

    // MARK: - AccountService

    public func signedInAccount() -> Account? {
        loadIfNeeded()?.account.account
    }

    public func currentAccount() async throws(AccountError) -> Account {
        let wire = try await authorized { token throws(APIFailure) in
            try await client.send(
                .getCurrentAccount, body: NoBody?.none, accessToken: token, expecting: AccountWire.self)
        }
        return try remember(wire)
    }

    public func register(email: String, password: String) async throws(AccountError) {
        try await publicCall(.registerAccount, RegisterAccountBody(email: email, password: password))
    }

    public func verifyEmail(email: String, code: String) async throws(AccountError) {
        try await publicCall(.verifyAccountEmail, VerifyEmailBody(email: email, code: code))
    }

    public func resendVerificationCode(email: String) async throws(AccountError) {
        try await publicCall(.resendVerificationCode, EmailOnlyBody(email: email))
    }

    public func requestPasswordReset(email: String) async throws(AccountError) {
        try await publicCall(.requestPasswordReset, EmailOnlyBody(email: email))
    }

    public func resetPassword(email: String, code: String, newPassword: String) async throws(AccountError) {
        try await publicCall(.resetPassword, ResetPasswordBody(email: email, code: code, newPassword: newPassword))
    }

    public func signIn(email: String, password: String) async throws(AccountError) -> Account {
        _ = await refreshTask?.value
        loadIfNeeded()
        let device = DeviceInfoWire(installationID: vault.installationID(), name: deviceName, platform: "ios")
        let body = CreateDeviceSessionBody(email: email, password: password, device: device)
        let grant: DeviceSessionGrantWire
        do {
            grant = try await client.send(.createDeviceSession, body: body, expecting: DeviceSessionGrantWire.self)
        } catch {
            throw AccountError(error)
        }
        epoch += 1
        return try adopt(grant)
    }

    public func signOut() async {
        _ = await refreshTask?.value
        let refreshToken = loadIfNeeded()?.refreshToken
        // Signed out in memory first, so nothing starts a refresh with the token being revoked.
        epoch += 1
        credentials = nil
        access = nil
        if let refreshToken {
            // Always 204 on the server, so a failure here is only the network. Best effort: the
            // device is signed out either way, and the session ends on its own after 30 idle days.
            try? await client.send(.signOutDeviceSession, body: RefreshTokenBody(refreshToken: refreshToken))
        }
        forget()
    }

    // MARK: - Requests

    private func publicCall(_ operation: APIOperation, _ body: some Encodable & Sendable) async throws(AccountError) {
        do {
            try await client.send(operation, body: body)
        } catch {
            throw AccountError(error)
        }
    }

    /// Runs an authenticated request with a valid access token: refreshes first when there's none,
    /// and once more if the server rejects the token (`unauthenticated`). If it rejects the next
    /// token too, the session has ended elsewhere: the credentials are cleared and it throws
    /// `.signedOut`. A rejected refresh (the session was revoked) clears them the same way.
    func authorized<Response: Sendable>(
        _ call: (_ accessToken: String) async throws(APIFailure) -> Response
    ) async throws(AccountError) -> Response {
        let startedIn = epoch
        let token = try await validAccessToken()
        do {
            return try await call(token)
        } catch .problem(let problem, _) where problem.code == "unauthenticated" {
            if access?.token == token { access = nil }
        } catch {
            throw AccountError(error)
        }
        let fresh = try await validAccessToken()
        do {
            return try await call(fresh)
        } catch .problem(let problem, _) where problem.code == "unauthenticated" {
            if epoch == startedIn { forget() }
            throw .signedOut
        } catch {
            throw AccountError(error)
        }
    }

    /// Keeps the account the server returned, so the stored copy shows its current email.
    func remember(_ wire: AccountWire) throws(AccountError) -> Account {
        guard let account = wire.account else { throw .unexpected(code: nil) }
        if var stored = credentials, stored.account != wire {
            stored.account = wire
            keep(stored)
        }
        return account
    }

    private func validAccessToken() async throws(AccountError) -> String {
        if let access, access.expiresAt.addingTimeInterval(-Self.expiryMargin) > now() {
            return access.token
        }
        return try await refreshed().get()
    }

    // MARK: - Refresh

    /// The single-flight refresh: joins the one in flight, or starts one.
    func refreshed() async -> Result<String, AccountError> {
        if let refreshTask { return await refreshTask.value }
        let task = Task { await self.runRefresh() }
        refreshTask = task
        return await task.value
    }

    private func runRefresh() async -> Result<String, AccountError> {
        defer { refreshTask = nil }
        guard var stored = loadIfNeeded() else { return .failure(.signedOut) }
        let startedIn = epoch
        let key = stored.pendingRefreshKey ?? AwradID.random().description
        if stored.pendingRefreshKey == nil {
            stored.pendingRefreshKey = key
            keep(stored)
        }
        let grant: DeviceSessionGrantWire
        do {
            grant = try await client.send(
                .refreshDeviceSession, body: RefreshTokenBody(refreshToken: stored.refreshToken),
                idempotencyKey: key, expecting: DeviceSessionGrantWire.self)
        } catch {
            guard epoch == startedIn else { return .failure(.signedOut) }
            return .failure(handleRefreshFailure(error))
        }
        guard epoch == startedIn else { return .failure(.signedOut) }
        return Result { () throws(AccountError) in try adopt(grant) }.map { _ in grant.accessToken }
    }

    private func handleRefreshFailure(_ failure: APIFailure) -> AccountError {
        guard case .problem(let problem, _) = failure else { return AccountError(failure) }
        switch problem.code {
        case "refresh_token_invalid", "refresh_reuse_detected":
            forget()
        case "idempotency_key_reused":
            // The key was already used with another body: the next attempt needs a new one.
            if var stored = credentials {
                stored.pendingRefreshKey = nil
                keep(stored)
            }
        default:
            break
        }
        return AccountError(failure)
    }

    // MARK: - Credentials

    @discardableResult
    private func loadIfNeeded() -> StoredCredentials? {
        if !loaded {
            loaded = true
            vault.claimIfNewInstallation()
            credentials = vault.credentials()
        }
        return credentials
    }

    /// Stores a grant's tokens and returns its account.
    private func adopt(_ grant: DeviceSessionGrantWire) throws(AccountError) -> Account {
        guard let account = grant.account.account,
            let expiresAt = WireInstant.date(grant.accessTokenExpiresAt)
        else { throw .unexpected(code: nil) }
        keep(StoredCredentials(account: grant.account, refreshToken: grant.refreshToken, pendingRefreshKey: nil))
        access = (grant.accessToken, expiresAt)
        return account
    }

    private func keep(_ stored: StoredCredentials) {
        credentials = stored
        vault.save(stored)
    }

    /// Signs this device out locally. The installation ID stays.
    func forget() {
        epoch += 1
        credentials = nil
        access = nil
        vault.clearCredentials()
    }
}
