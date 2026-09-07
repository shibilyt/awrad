import Foundation
import Testing
@testable import awrad

@MainActor
@Suite(.serialized)
struct AuthServiceTests {
    @Test func publicCommunityStatsGETPreservesLargeCountsWithoutCredentials() async throws {
        let recorder = AuthRequestRecorder()
        MockAuthURLProtocol.install { request in
            recorder.record(request)
            return .json(status: 200, body: #"""
            {
              "as_of":"2026-07-19T16:08:25.123Z",
              "count_semantics":"accepted_progress",
              "total_tracked_goals":42,
              "approximate_total_counts":"1234567890123456789012345678901234567890",
              "approximate_dhikr_hours":12.5,
              "seconds_per_count":1,
              "daily_counts":[{"date":"2026-07-19","approximate_count":"999999999999999999999999"}]
            }
            """#)
        }
        defer { MockAuthURLProtocol.reset() }
        let defaults = isolatedDefaults()
        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: defaults,
            credentialStore: authenticatedCredentials(in: defaults, access: "secret", refresh: "refresh")
        )

        let response: CommunityStatsResponse = try await service.publicRequest("api/community/stats")

        #expect(response.approximateTotalCounts.rawValue == "1234567890123456789012345678901234567890")
        #expect(response.dailyCounts.first?.approximateCount.rawValue == "999999999999999999999999")
        #expect(recorder.method(path: "/api/community/stats") == "GET")
        #expect(recorder.authorization(path: "/api/community/stats") == nil)
        #expect(recorder.count(path: "/api/auth/refresh") == 0)
    }

    @Test func publicCommunityStatsSurfacesHTTPErrorWithoutRefreshing() async throws {
        let recorder = AuthRequestRecorder()
        MockAuthURLProtocol.install { request in
            recorder.record(request)
            return .json(status: 503, body: #"{"error":"temporarily_unavailable","message":"Try later"}"#)
        }
        defer { MockAuthURLProtocol.reset() }
        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: isolatedDefaults(),
            credentialStore: InMemoryAuthCredentialStore()
        )

        do {
            let _: CommunityStatsResponse = try await service.publicRequest("api/community/stats")
            Issue.record("Expected the public request to fail")
        } catch let AuthServiceError.http(statusCode, _, errorCode) {
            #expect(statusCode == 503)
            #expect(errorCode == "temporarily_unavailable")
        }
        #expect(recorder.count(path: "/api/community/stats") == 1)
        #expect(recorder.count(path: "/api/auth/refresh") == 0)
    }

    @Test func forcedCommunityStatsRefreshBypassesCachedResponse() async throws {
        let recorder = AuthRequestRecorder()
        MockAuthURLProtocol.install { request in
            recorder.record(request)
            return .json(status: 200, body: #"""
            {
              "as_of":"2026-07-19T16:08:25Z","count_semantics":"current_canonical_net",
              "total_tracked_goals":1,"approximate_total_counts":"2",
              "approximate_dhikr_hours":0.0,"seconds_per_count":1,"daily_counts":[]
            }
            """#)
        }
        defer { MockAuthURLProtocol.reset() }
        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: isolatedDefaults(),
            credentialStore: InMemoryAuthCredentialStore()
        )

        let _: CommunityStatsResponse = try await service.publicRequest(
            "api/community/stats",
            forceRefresh: true
        )

        #expect(recorder.header("Cache-Control", path: "/api/community/stats") == "no-cache")
        #expect(recorder.authorization(path: "/api/community/stats") == nil)
        #expect(recorder.count(path: "/api/auth/refresh") == 0)
    }

    @Test func communityStatsRejectsNonDecimalCountStringsAndInvalidDates() {
        let data = Data(#"""
        {
          "as_of":"not-a-date","count_semantics":"accepted_progress","total_tracked_goals":1,
          "approximate_total_counts":"12.5","approximate_dhikr_hours":1,"seconds_per_count":1,
          "daily_counts":[]
        }
        """#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CommunityStatsResponse.self, from: data)
        }
    }

    @Test func actorAckForkRotatesAndRetriesAtNextDurableSequence() async throws {
        let recorder = AuthRequestRecorder()
        MockAuthURLProtocol.install { request in
            recorder.record(request)
            guard request.url?.path == "/api/sync/v1/progress/actors/ack" else {
                return .json(status: 404, body: #"{"error":"missing"}"#)
            }
            if recorder.count(path: "/api/sync/v1/progress/actors/ack") == 1 {
                return .json(status: 409, body: #"{"error":"actor_fork"}"#)
            }
            let body = recorder.jsonBody(path: "/api/sync/v1/progress/actors/ack") ?? [:]
            let actorID = body["actor_id"] as? String ?? ""
            return .json(status: 200, body: """
            {
              "header":{"protocol_version":1,"progress_model_version":1,"capabilities":["materialized_transfers"]},
              "actor_id":"\(actorID)",
              "applied_revision":"12",
              "safe_compaction_revision":"10"
            }
            """)
        }
        defer { MockAuthURLProtocol.reset() }

        let container = try AwradPersistenceContainerFactory.makeInMemoryContainer()
        let repository = SwiftDataAwradRepository(container: container)
        let installationID = UUID().uuidString.lowercased()
        var originalActorID = ""
        try repository.performProgressSyncTransaction { context in
            let state = try ProgressSyncLocalStore.bind(
                userID: UUID().uuidString.lowercased(),
                installationID: installationID, in: context
            )
            originalActorID = state.actorID
            state.nextActorSequence = 8
            state.appliedRevision = 12
            state.safeCompactionRevision = 10
        }
        let authDefaults = isolatedDefaults()
        authDefaults.set(installationID, forKey: AwradInstallationIdentity.storageKey)
        authDefaults.set(installationID, forKey: AwradInstallationIdentity.installMarkerKey)
        let auth = AuthService(
            baseURL: testBaseURL, session: mockSession(), defaults: authDefaults,
            credentialStore: authenticatedCredentials(
                in: authDefaults, access: "access", refresh: "refresh"
            )
        )
        let engine = ProgressSyncEngine(auth: auth, repository: repository)
        try await engine.acknowledgeActor(repository: repository)

        let state = try #require(try SharedProgressSyncPersistence.state(in: repository.modelContext))
        #expect(state.actorID != originalActorID)
        #expect(state.installationID == installationID)
        #expect(state.nextActorSequence == 8)
        #expect(recorder.count(path: "/api/sync/v1/progress/actors/ack") == 2)
        let finalBody = recorder.jsonBody(path: "/api/sync/v1/progress/actors/ack")
        #expect(finalBody?["actor_id"] as? String == state.actorID)
        #expect(finalBody?["installation_id"] as? String == installationID)
        #expect(finalBody?["starting_sequence"] as? String == "8")
    }

    @Test func authAndProgressSyncShareAndMigrateOneInstallationIdentity() async throws {
        let legacyInstallationID = UUID().uuidString.lowercased()
        let defaults = isolatedDefaults()
        defaults.set(
            legacyInstallationID,
            forKey: AwradInstallationIdentity.legacyProgressSyncStorageKey
        )
        let recorder = AuthRequestRecorder()
        MockAuthURLProtocol.install { request in
            recorder.record(request)
            if request.url?.path == "/api/auth/login" {
                return .json(status: 200, body: authResponse(access: "access", refresh: "refresh"))
            }
            return .json(status: 404, body: #"{"error":"missing"}"#)
        }
        defer { MockAuthURLProtocol.reset() }

        let service = AuthService(
            baseURL: testBaseURL, session: mockSession(), defaults: defaults,
            credentialStore: InMemoryAuthCredentialStore()
        )
        try await service.login(email: "person@example.com", password: "Strong-password1")

        let device = recorder.jsonBody(path: "/api/auth/login")?["device"] as? [String: Any]
        #expect(device?["installation_id"] as? String == legacyInstallationID)
        #expect(defaults.string(forKey: AwradInstallationIdentity.storageKey) == legacyInstallationID)
        #expect(defaults.string(forKey: AwradInstallationIdentity.legacyProgressSyncStorageKey) == nil)

        let sessionInstallationID = UUID().uuidString.lowercased()
        let staleSyncInstallationID = UUID().uuidString.lowercased()
        defaults.set(sessionInstallationID, forKey: AwradInstallationIdentity.storageKey)
        defaults.set(staleSyncInstallationID, forKey: AwradInstallationIdentity.legacyProgressSyncStorageKey)
        #expect(AwradInstallationIdentity.resolve(in: defaults) == sessionInstallationID)
        #expect(defaults.string(forKey: AwradInstallationIdentity.legacyProgressSyncStorageKey) == nil)
    }

    @Test func reinstallWithPreservedCredentialsRequiresExplicitSignIn() {
        let previousInstallationID = UUID().uuidString.lowercased()
        let credentials = InMemoryAuthCredentialStore(credentials: StoredAuthCredentials(
            accessToken: "access",
            refreshToken: "refresh",
            installationID: previousInstallationID,
            userID: "user-1",
            userEmail: "person@example.com"
        ))
        let freshDefaults = isolatedDefaults()

        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: freshDefaults,
            credentialStore: credentials
        )

        #expect(service.reauthenticationRequired)
        #expect(!service.isLoggedIn)
        #expect(service.accessToken == nil)
        #expect(service.recoveryUserEmail == "person@example.com")
        #expect(service.recoveryUserID == "user-1")
        #expect(service.progressSyncRebindRequired)
        #expect(credentials.credentials == nil)
        #expect(freshDefaults.string(forKey: AwradInstallationIdentity.storageKey) != previousInstallationID)
    }

    @Test func reinstallDetectsLegacySecureCredentialsWithoutInstallationMetadata() {
        let credentials = InMemoryAuthCredentialStore(credentials: StoredAuthCredentials(
            accessToken: "legacy-access",
            refreshToken: "legacy-refresh"
        ))
        let freshDefaults = isolatedDefaults()

        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: freshDefaults,
            credentialStore: credentials
        )

        #expect(service.reauthenticationRequired)
        #expect(!service.isLoggedIn)
        #expect(service.progressSyncRebindRequired)
        #expect(credentials.credentials == nil)
    }

    @Test func installationMismatchSignsOutAndPersistsRecoveryPrompt() {
        let defaults = isolatedDefaults()
        let installationID = AwradInstallationIdentity.markCurrentInstall(in: defaults)
        defaults.set("user-1", forKey: "auth_user_id")
        defaults.set("person@example.com", forKey: "auth_user_email")
        defaults.set(true, forKey: "auth_user_email_verified")
        defaults.set("session-1", forKey: "auth_session_id")
        let credentials = InMemoryAuthCredentialStore(credentials: StoredAuthCredentials(
            accessToken: "access", refreshToken: "refresh",
            installationID: installationID, userID: "user-1", userEmail: "person@example.com"
        ))
        let service = AuthService(
            baseURL: testBaseURL, session: mockSession(), defaults: defaults,
            credentialStore: credentials
        )

        #expect(service.isLoggedIn)
        service.requireReauthentication()

        #expect(!service.isLoggedIn)
        #expect(service.reauthenticationRequired)
        #expect(service.recoveryUserEmail == "person@example.com")
        #expect(service.progressSyncRebindRequired)
        #expect(credentials.credentials == nil)

        let restored = AuthService(
            baseURL: testBaseURL, session: mockSession(), defaults: defaults,
            credentialStore: credentials
        )
        #expect(restored.reauthenticationRequired)
        #expect(!restored.isLoggedIn)
        #expect(restored.recoveryUserID == "user-1")
    }

    @Test func localResetClearsRecoveryWithoutCallingTheServer() {
        let defaults = isolatedDefaults()
        let credentials = authenticatedCredentials(
            in: defaults, access: "access", refresh: "refresh"
        )
        let service = AuthService(
            baseURL: testBaseURL, session: mockSession(), defaults: defaults,
            credentialStore: credentials
        )
        service.requireReauthentication()
        let recoveryInstallationID = defaults.string(
            forKey: AwradInstallationIdentity.storageKey
        )

        service.resetLocalAuthentication()

        #expect(!service.isLoggedIn)
        #expect(!service.reauthenticationRequired)
        #expect(!service.progressSyncRebindRequired)
        #expect(service.recoveryUserID == nil)
        #expect(service.recoveryUserEmail == nil)
        #expect(credentials.credentials == nil)
        #expect(defaults.string(forKey: AwradInstallationIdentity.storageKey) != recoveryInstallationID)
    }

    @Test func recoveryRejectsSigningIntoAnotherAccount() async {
        MockAuthURLProtocol.install { request in
            guard request.url?.path == "/api/auth/login" else {
                return .json(status: 404, body: #"{"error":"missing"}"#)
            }
            return .json(
                status: 200,
                body: authResponse(
                    access: "other-access",
                    refresh: "other-refresh",
                    userID: "user-2",
                    email: "other@example.com"
                )
            )
        }
        defer { MockAuthURLProtocol.reset() }

        let defaults = isolatedDefaults()
        let installationID = AwradInstallationIdentity.markCurrentInstall(in: defaults)
        defaults.set("user-1", forKey: "auth_user_id")
        defaults.set("person@example.com", forKey: "auth_user_email")
        let credentials = InMemoryAuthCredentialStore(credentials: StoredAuthCredentials(
            accessToken: "access", refreshToken: "refresh",
            installationID: installationID, userID: "user-1", userEmail: "person@example.com"
        ))
        let service = AuthService(
            baseURL: testBaseURL, session: mockSession(), defaults: defaults,
            credentialStore: credentials
        )
        service.requireReauthentication()

        await #expect(throws: AuthServiceError.self) {
            try await service.login(email: "other@example.com", password: "Strong-password1")
        }
        #expect(service.reauthenticationRequired)
        #expect(!service.isLoggedIn)
        #expect(service.recoveryUserID == "user-1")
        #expect(credentials.credentials == nil)
    }

    @Test func legacyTokensMoveIntoSecureCredentialStore() {
        let defaults = isolatedDefaults()
        defaults.set("legacy-access", forKey: "auth_access_token")
        defaults.set("legacy-refresh", forKey: "auth_refresh_token")
        let credentials = InMemoryAuthCredentialStore()

        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: defaults,
            credentialStore: credentials
        )

        #expect(service.accessToken == "legacy-access")
        #expect(service.refreshToken == "legacy-refresh")
        #expect(credentials.credentials?.accessToken == "legacy-access")
        #expect(credentials.credentials?.refreshToken == "legacy-refresh")
        #expect(credentials.credentials?.installationID == defaults.string(
            forKey: AwradInstallationIdentity.storageKey
        ))
        #expect(defaults.string(forKey: "auth_access_token") == nil)
        #expect(defaults.string(forKey: "auth_refresh_token") == nil)
    }

    @Test func concurrentUnauthorizedRequestsShareOneRefresh() async throws {
        let recorder = AuthRequestRecorder()
        let defaults = isolatedDefaults()
        let credentials = authenticatedCredentials(
            in: defaults, access: "old-access", refresh: "old-refresh"
        )
        MockAuthURLProtocol.install { request in
            recorder.record(request)
            switch request.url?.path {
            case "/api/auth/refresh":
                Thread.sleep(forTimeInterval: 0.08)
                return .json(status: 200, body: authResponse(access: "new-access", refresh: "new-refresh"))
            case "/api/protected":
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer new-access" {
                    return .json(status: 200, body: #"{"value":"ok"}"#)
                }
                return .json(status: 401, body: #"{"error":"expired"}"#)
            default:
                return .json(status: 404, body: #"{"error":"missing"}"#)
            }
        }
        defer { MockAuthURLProtocol.reset() }

        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: defaults,
            credentialStore: credentials
        )

        async let first: ProtectedResponse = service.authenticatedRequest(
            "api/protected",
            method: "GET",
            body: EmptyTestRequest()
        )
        async let second: ProtectedResponse = service.authenticatedRequest(
            "api/protected",
            method: "GET",
            body: EmptyTestRequest()
        )
        let (firstResponse, secondResponse) = try await (first, second)
        let values = [firstResponse.value, secondResponse.value]

        #expect(values == ["ok", "ok"])
        #expect(recorder.count(path: "/api/auth/refresh") == 1)
        #expect(credentials.credentials?.accessToken == "new-access")
        #expect(credentials.credentials?.refreshToken == "new-refresh")
    }

    @Test func transientRefreshFailurePreservesCredentialsForOfflineRecovery() async {
        let defaults = isolatedDefaults()
        let credentials = authenticatedCredentials(
            in: defaults, access: "old-access", refresh: "old-refresh"
        )
        MockAuthURLProtocol.install { request in
            if request.url?.path == "/api/auth/refresh" {
                return .json(status: 503, body: #"{"error":"temporarily unavailable"}"#)
            }
            return .json(status: 401, body: #"{"error":"expired"}"#)
        }
        defer { MockAuthURLProtocol.reset() }

        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: defaults,
            credentialStore: credentials
        )

        do {
            let _: ProtectedResponse = try await service.authenticatedRequest(
                "api/protected",
                method: "GET",
                body: EmptyTestRequest()
            )
            Issue.record("Expected the protected request to fail")
        } catch {}

        #expect(service.isLoggedIn)
        #expect(credentials.credentials?.refreshToken == "old-refresh")
        #expect(credentials.clearCount == 0)
    }

    @Test func definitiveRefreshFailureClearsRevokedCredentials() async {
        let defaults = isolatedDefaults()
        let credentials = authenticatedCredentials(
            in: defaults, access: "old-access", refresh: "old-refresh"
        )
        MockAuthURLProtocol.install { request in
            if request.url?.path == "/api/auth/refresh" {
                return .json(
                    status: 401,
                    body: #"{"error":"Refresh token reuse detected","error_code":"refresh_reuse_detected"}"#
                )
            }
            return .json(status: 401, body: #"{"error":"expired"}"#)
        }
        defer { MockAuthURLProtocol.reset() }

        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: defaults,
            credentialStore: credentials
        )

        do {
            let _: ProtectedResponse = try await service.authenticatedRequest(
                "api/protected",
                method: "GET",
                body: EmptyTestRequest()
            )
            Issue.record("Expected the revoked refresh token to fail")
        } catch {}

        #expect(!service.isLoggedIn)
        #expect(credentials.credentials == nil)
        #expect(credentials.clearCount == 1)
    }

    @Test func verificationResetAndSessionOperationsUsePhoenixContracts() async throws {
        let recorder = AuthRequestRecorder()
        let defaults = isolatedDefaults()
        let credentials = authenticatedCredentials(
            in: defaults, access: "access", refresh: "refresh"
        )
        MockAuthURLProtocol.install { request in
            recorder.record(request)
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/auth/verify-email/resend"):
                return .json(status: 200, body: #"{"message":"sent"}"#)
            case ("POST", "/api/auth/reset-password"):
                return .json(status: 200, body: #"{"message":"reset"}"#)
            case ("GET", "/api/auth/sessions"):
                return .json(status: 200, body: #"{"sessions":[{"id":"s1","device_name":"iPhone","platform":"ios"}]}"#)
            case ("DELETE", "/api/auth/sessions/s1"):
                return .empty(status: 204)
            default:
                return .json(status: 404, body: #"{"error":"missing"}"#)
            }
        }
        defer { MockAuthURLProtocol.reset() }

        defaults.set("person@example.com", forKey: "auth_pending_verification_email")
        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: defaults,
            credentialStore: credentials
        )

        try await service.resendVerification()
        try await service.resetPassword(token: "reset-token", password: "Strong-password1")
        let sessions = try await service.sessions()
        try await service.revokeSession(id: "s1")

        #expect(sessions.map(\.id) == ["s1"])
        #expect(recorder.jsonBody(path: "/api/auth/verify-email/resend")?["email"] as? String == "person@example.com")
        #expect(recorder.jsonBody(path: "/api/auth/reset-password")?["token"] as? String == "reset-token")
        #expect(recorder.jsonBody(path: "/api/auth/reset-password")?["password"] as? String == "Strong-password1")
        #expect(recorder.authorization(path: "/api/auth/sessions") == "Bearer access")
    }

    @Test func passwordPolicyMatchesAndroidAndResendCooldownSurvivesRecreation() async throws {
        #expect(!AuthPasswordPolicy.isValid("short"))
        #expect(!AuthPasswordPolicy.isValid("alllowercase1"))
        #expect(!AuthPasswordPolicy.isValid("ALLUPPERCASE1"))
        #expect(!AuthPasswordPolicy.isValid("MixedCaseOnly"))
        #expect(AuthPasswordPolicy.isValid("MixedCase1!"))

        MockAuthURLProtocol.install { request in
            if request.url?.path == "/api/auth/verify-email/resend" {
                return .json(status: 200, body: #"{"message":"sent"}"#)
            }
            return .json(status: 404, body: #"{"error":"missing"}"#)
        }
        defer { MockAuthURLProtocol.reset() }

        let defaults = isolatedDefaults()
        defaults.set("person@example.com", forKey: "auth_pending_verification_email")
        let first = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: defaults,
            credentialStore: InMemoryAuthCredentialStore()
        )
        try await first.resendVerification()

        let restored = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: defaults,
            credentialStore: InMemoryAuthCredentialStore()
        )
        #expect(restored.verificationResendAvailableAt != nil)
        await #expect(throws: AuthServiceError.self) {
            try await restored.resendVerification()
        }
    }

    @Test func unverifiedLoginPersistsStructuredOnboardingContext() async {
        MockAuthURLProtocol.install { request in
            if request.url?.path == "/api/auth/login" {
                return .json(
                    status: 403,
                    body: #"{"error":"email verification required","error_code":"email_verification_required"}"#
                )
            }
            return .json(status: 404, body: #"{"error":"missing"}"#)
        }
        defer { MockAuthURLProtocol.reset() }

        let defaults = isolatedDefaults()
        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: defaults,
            credentialStore: InMemoryAuthCredentialStore()
        )

        do {
            try await service.login(
                email: " PERSON@Example.com ",
                password: "Strong-password1",
                origin: .onboarding
            )
            Issue.record("Expected email verification to be required")
        } catch {}

        #expect(service.pendingVerificationContext == PendingVerificationContext(
            email: "person@example.com",
            mode: .login,
            origin: .onboarding
        ))

        let restored = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: defaults,
            credentialStore: InMemoryAuthCredentialStore()
        )
        #expect(restored.pendingVerificationContext == service.pendingVerificationContext)
    }

    @Test func passwordlessLoginPreservesSetupRequiredErrorCode() async {
        MockAuthURLProtocol.install { request in
            if request.url?.path == "/api/auth/login" {
                return .json(
                    status: 403,
                    body: #"{"error":"password setup required","error_code":"password_setup_required"}"#
                )
            }
            return .json(status: 404, body: #"{"error":"missing"}"#)
        }
        defer { MockAuthURLProtocol.reset() }

        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: isolatedDefaults(),
            credentialStore: InMemoryAuthCredentialStore()
        )

        do {
            try await service.login(email: "person@example.com", password: "Strong-password1")
            Issue.record("Expected password setup to be required")
        } catch let AuthServiceError.http(statusCode, _, errorCode) {
            #expect(statusCode == 403)
            #expect(errorCode == "password_setup_required")
        } catch {
            Issue.record("Unexpected auth error: \(error)")
        }
    }

    @Test func signupWaitsForVerificationAndVerificationSavesTheSession() async throws {
        let recorder = AuthRequestRecorder()
        MockAuthURLProtocol.install { request in
            recorder.record(request)
            switch request.url?.path {
            case "/api/auth/register":
                return .json(
                    status: 202,
                    body: #"{"message":"accepted","verification_required":true}"#
                )
            case "/api/auth/verify-email":
                return .json(
                    status: 200,
                    body: authResponse(access: "verified-access", refresh: "verified-refresh")
                )
            default:
                return .json(status: 404, body: #"{"error":"missing"}"#)
            }
        }
        defer { MockAuthURLProtocol.reset() }

        let defaults = isolatedDefaults()
        let credentials = InMemoryAuthCredentialStore()
        let service = AuthService(
            baseURL: testBaseURL,
            session: mockSession(),
            defaults: defaults,
            credentialStore: credentials
        )

        try await service.register(
            email: " PERSON@Example.com ",
            password: "Strong-password1",
            origin: .onboarding
        )

        #expect(!service.isLoggedIn)
        #expect(service.pendingVerificationContext == PendingVerificationContext(
            email: "person@example.com",
            mode: .signup,
            origin: .onboarding
        ))

        try await service.verifyEmail(token: "verification-token")

        #expect(service.isLoggedIn)
        #expect(service.pendingVerificationContext == nil)
        #expect(credentials.credentials?.accessToken == "verified-access")
        #expect(credentials.credentials?.refreshToken == "verified-refresh")
        #expect(recorder.jsonBody(path: "/api/auth/verify-email")?["token"] as? String == "verification-token")
    }

    @Test func authDeepLinksRoundTripTokensAndRejectMissingResetToken() throws {
        let verifyURL = try #require(URL(string: "awrad://verify-email?token=verify-123"))
        let resetURL = try #require(URL(string: "awrad://reset-password?token=reset-123"))

        #expect(AwradDeepLink(url: verifyURL) == .verifyEmail(token: "verify-123"))
        #expect(AwradDeepLink(url: resetURL) == .resetPassword(token: "reset-123"))
        #expect(AwradDeepLink.verifyEmail(token: nil).url.absoluteString == "awrad://verify-email")
        #expect(AwradDeepLink.resetPassword(token: "reset-123").url.absoluteString == "awrad://reset-password?token=reset-123")
        #expect(AwradDeepLink(url: URL(string: "awrad://reset-password")!) == nil)

        #expect(
            AwradDeepLink(
                url: URL(string: "https://api.awrad.app/auth/mobile/verify-email/mobile-token")!,
                appLinkHost: "api.awrad.app"
            ) == .verifyEmail(token: "mobile-token")
        )
        #expect(
            AwradDeepLink(
                url: URL(string: "https://api.awrad.app/auth/verify-email/legacy-token")!,
                appLinkHost: "api.awrad.app"
            ) == .verifyEmail(token: "legacy-token")
        )
        #expect(
            AwradDeepLink(
                url: URL(string: "https://attacker.example/auth/mobile/verify-email/token")!,
                appLinkHost: "api.awrad.app"
            ) == nil
        )
    }

    private var testBaseURL: URL { URL(string: "https://awrad.test/")! }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "AuthServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockAuthURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func authenticatedCredentials(
        in defaults: UserDefaults,
        access: String,
        refresh: String
    ) -> InMemoryAuthCredentialStore {
        let installationID = AwradInstallationIdentity.markCurrentInstall(in: defaults)
        defaults.set("user-1", forKey: "auth_user_id")
        defaults.set("person@example.com", forKey: "auth_user_email")
        defaults.set(true, forKey: "auth_user_email_verified")
        return InMemoryAuthCredentialStore(credentials: StoredAuthCredentials(
            accessToken: access,
            refreshToken: refresh,
            installationID: installationID,
            userID: "user-1",
            userEmail: "person@example.com"
        ))
    }
}

private struct EmptyTestRequest: Encodable {}
private struct ProtectedResponse: Decodable { let value: String }

private func authResponse(
    access: String,
    refresh: String,
    userID: String = "user-1",
    email: String = "person@example.com"
) -> String {
    """
    {
      "user": {"id":"\(userID)","email":"\(email)","email_verified":true},
      "access_token":"\(access)",
      "refresh_token":"\(refresh)",
      "session":{"id":"session-1","device_name":"iPhone","platform":"ios"}
    }
    """
}

private final class InMemoryAuthCredentialStore: AuthCredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storedCredentials: StoredAuthCredentials?
    private var storedClearCount = 0

    init(credentials: StoredAuthCredentials? = nil) {
        storedCredentials = credentials
    }

    var credentials: StoredAuthCredentials? {
        lock.lock()
        defer { lock.unlock() }
        return storedCredentials
    }

    var clearCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedClearCount
    }

    func load() -> StoredAuthCredentials? { credentials }

    func save(_ credentials: StoredAuthCredentials) throws {
        lock.lock()
        storedCredentials = credentials
        lock.unlock()
    }

    func clear() {
        lock.lock()
        storedCredentials = nil
        storedClearCount += 1
        lock.unlock()
    }
}

private final class AuthRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [CapturedAuthRequest] = []

    func record(_ request: URLRequest) {
        let captured = CapturedAuthRequest(request: request, body: Self.bodyData(from: request))
        lock.lock()
        requests.append(captured)
        lock.unlock()
    }

    func count(path: String) -> Int {
        withRequests { $0.filter { $0.request.url?.path == path }.count }
    }

    func method(path: String) -> String? {
        withRequests { $0.last(where: { $0.request.url?.path == path })?.request.httpMethod }
    }

    func authorization(path: String) -> String? {
        withRequests { requests in
            requests.last(where: { $0.request.url?.path == path })?
                .request.value(forHTTPHeaderField: "Authorization")
        }
    }

    func header(_ field: String, path: String) -> String? {
        withRequests { requests in
            requests.last(where: { $0.request.url?.path == path })?
                .request.value(forHTTPHeaderField: field)
        }
    }

    func jsonBody(path: String) -> [String: Any]? {
        withRequests { requests in
            guard let data = requests.last(where: { $0.request.url?.path == path })?.body else { return nil }
            guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
            return object as? [String: Any]
        }
    }

    private func withRequests<T>(_ operation: ([CapturedAuthRequest]) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation(requests)
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 {
                return nil
            }
            if count == 0 {
                return data
            }
            data.append(buffer, count: count)
        }
    }
}

private struct CapturedAuthRequest {
    let request: URLRequest
    let body: Data?
}

private struct MockHTTPResult {
    let status: Int
    let headers: [String: String]
    let body: Data

    static func json(status: Int, body: String) -> Self {
        Self(status: status, headers: ["Content-Type": "application/json"], body: Data(body.utf8))
    }

    static func empty(status: Int) -> Self {
        Self(status: status, headers: [:], body: Data())
    }
}

private final class MockAuthURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: (@Sendable (URLRequest) -> MockHTTPResult)?

    static func install(_ newHandler: @escaping @Sendable (URLRequest) -> MockHTTPResult) {
        lock.lock()
        handler = newHandler
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        handler = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let handler = Self.handler
        Self.lock.unlock()
        let result = handler?(request) ?? .json(status: 500, body: #"{"error":"No mock handler"}"#)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: result.status,
            httpVersion: "HTTP/1.1",
            headerFields: result.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !result.body.isEmpty {
            client?.urlProtocol(self, didLoad: result.body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
