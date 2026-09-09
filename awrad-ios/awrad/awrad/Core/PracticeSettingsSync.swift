import Foundation

struct PracticePolicySyncValues: Equatable {
    var dayReset: String
    var calculationMethod: String
    var madhab: String
}

enum PracticeSettingsSyncDecision: Equatable {
    case applyRemote
    case uploadLocal
}

enum PracticeSettingsSyncDecisionPlanner {
    static func decision(
        local: PracticePolicySyncValues,
        remote: PracticePolicySyncValues,
        remoteRevision: Int,
        ownerUserID: String?,
        currentUserID: String,
        lastServerRevision: Int,
        lastSynced: PracticePolicySyncValues?,
        defaults: PracticePolicySyncValues
    ) -> PracticeSettingsSyncDecision {
        if let ownerUserID, ownerUserID != currentUserID {
            return .applyRemote
        }

        let anonymousLocalSeed = ownerUserID == nil &&
            local != defaults &&
            remoteRevision == 1 &&
            remote == defaults
        if anonymousLocalSeed { return .uploadLocal }

        let localChangedSinceSync = lastSynced.map { $0 != local } ?? false
        if ownerUserID == currentUserID &&
            localChangedSinceSync &&
            lastServerRevision == remoteRevision {
            return .uploadLocal
        }

        return .applyRemote
    }
}

struct PracticeSettingsResponse: Decodable {
    var policy: PracticePolicySyncPayload
    var device_context: PracticeDeviceContextSyncPayload?
}

struct PracticePolicySyncPayload: Codable, Equatable {
    var day_reset: String
    var calculation_method: String
    var madhab: String
    var revision: Int

    var values: PracticePolicySyncValues {
        PracticePolicySyncValues(
            dayReset: day_reset,
            calculationMethod: calculation_method,
            madhab: madhab
        )
    }

    init(values: PracticePolicySyncValues, revision: Int) {
        day_reset = values.dayReset
        calculation_method = values.calculationMethod
        madhab = values.madhab
        self.revision = revision
    }
}

struct PracticeDeviceContextSyncPayload: Decodable, Equatable {
    var installation_id: String
    var timezone: String
    var latitude: Double?
    var longitude: Double?
    var accuracy_m: Double?
    var location_source: String
    var revision: Int
    var last_seen_at: String?
}

struct PracticePolicySyncRequest: Encodable {
    var installation_id: String
    var expected_revision: Int
    var policy: PracticePolicySyncWritePayload
}

struct PracticePolicySyncWritePayload: Encodable {
    var day_reset: String
    var calculation_method: String
    var madhab: String
}

struct PracticeDeviceContextSyncRequest: Encodable {
    var installation_id: String
    var device_context: PracticeDeviceContextSyncWritePayload
}

struct PracticeDeviceContextSyncWritePayload: Encodable {
    var timezone: String
    var latitude: Double?
    var longitude: Double?
    var accuracy_m: Double?
    var location_source: String
}

extension AuthService {
    func fetchPracticeSettings(installationID: String) async throws -> PracticeSettingsResponse {
        try await authenticatedRequest(
            "api/sync/v1/practice-settings?installation_id=\(installationID)",
            method: "GET"
        )
    }

    func updatePracticePolicy(
        installationID: String,
        expectedRevision: Int,
        values: PracticePolicySyncValues
    ) async throws -> PracticeSettingsResponse {
        try await authenticatedRequest(
            "api/sync/v1/practice-settings/policy",
            method: "PUT",
            body: PracticePolicySyncRequest(
                installation_id: installationID,
                expected_revision: expectedRevision,
                policy: PracticePolicySyncWritePayload(
                    day_reset: values.dayReset,
                    calculation_method: values.calculationMethod,
                    madhab: values.madhab
                )
            )
        )
    }

    func updatePracticeDeviceContext(
        installationID: String,
        timezone: String,
        latitude: Double?,
        longitude: Double?,
        accuracyM: Double? = nil
    ) async throws -> PracticeSettingsResponse {
        try await authenticatedRequest(
            "api/sync/v1/practice-settings/device-context",
            method: "PUT",
            body: PracticeDeviceContextSyncRequest(
                installation_id: installationID,
                device_context: PracticeDeviceContextSyncWritePayload(
                    timezone: timezone,
                    latitude: latitude,
                    longitude: longitude,
                    accuracy_m: accuracyM,
                    location_source: "manual"
                )
            )
        )
    }
}

@MainActor
final class PracticeSettingsSyncService {
    private let auth: AuthService
    private let defaults: UserDefaults

    init(auth: AuthService, defaults: UserDefaults = .standard) {
        self.auth = auth
        self.defaults = defaults
    }

    func synchronize(store: AwradStore) async throws {
        guard auth.isLoggedIn,
              auth.userEmailVerified,
              let userID = auth.userID else { return }

        let installationID = AwradInstallationIdentity.resolve(in: defaults)
        let remote = try await auth.fetchPracticeSettings(installationID: installationID)
        let remoteValues = remote.policy.values
        let local = PracticePolicySyncValues(
            dayReset: store.preferences.dayReset.rawValue,
            calculationMethod: store.preferences.calculationMethod.rawValue.lowercased(),
            madhab: store.preferences.madhab.rawValue.lowercased()
        )
        let defaultsPolicy = PracticePolicySyncValues(
            dayReset: DayResetOption.midnight.rawValue,
            calculationMethod: PrayerCalculationMethod.karachi.rawValue.lowercased(),
            madhab: PrayerMadhab.shafi.rawValue.lowercased()
        )
        let lastSynced = persistedValues()
        let decision = PracticeSettingsSyncDecisionPlanner.decision(
            local: local,
            remote: remoteValues,
            remoteRevision: remote.policy.revision,
            ownerUserID: defaults.string(forKey: Key.ownerUserID),
            currentUserID: userID,
            lastServerRevision: defaults.integer(forKey: Key.serverRevision),
            lastSynced: lastSynced,
            defaults: defaultsPolicy
        )

        let canonical: PracticeSettingsResponse
        switch decision {
        case .applyRemote:
            canonical = remote
        case .uploadLocal:
            do {
                canonical = try await auth.updatePracticePolicy(
                    installationID: installationID,
                    expectedRevision: remote.policy.revision,
                    values: local
                )
            } catch let error as AuthServiceError
                where isPolicyConflict(error) {
                canonical = try await auth.fetchPracticeSettings(installationID: installationID)
            }
        }

        guard let dayReset = DayResetOption(rawValue: canonical.policy.day_reset),
              let calculationMethod = PrayerCalculationMethod(
                  rawValue: canonical.policy.calculation_method.uppercased()
              ),
              let madhab = PrayerMadhab(rawValue: canonical.policy.madhab.uppercased()) else {
            throw AuthServiceError.network("Practice settings response contains an unsupported policy")
        }

        guard store.updatePreferences({ preferences in
            preferences.dayReset = dayReset
            preferences.calculationMethod = calculationMethod
            preferences.madhab = madhab
        }) else {
            throw AuthServiceError.network("Unable to save practice settings locally")
        }
        persist(canonical.policy.values, revision: canonical.policy.revision, userID: userID)

        // Context is deliberately sent separately: a user may use a different
        // location on every installation while the policy stays account-wide.
        _ = try? await auth.updatePracticeDeviceContext(
            installationID: installationID,
            timezone: TimeZone.current.identifier,
            latitude: store.preferences.latitude,
            longitude: store.preferences.longitude
        )
    }

    private func persistedValues() -> PracticePolicySyncValues? {
        guard let dayReset = defaults.string(forKey: Key.lastDayReset),
              let calculationMethod = defaults.string(forKey: Key.lastCalculationMethod),
              let madhab = defaults.string(forKey: Key.lastMadhab) else { return nil }
        return PracticePolicySyncValues(
            dayReset: dayReset,
            calculationMethod: calculationMethod,
            madhab: madhab
        )
    }

    private func persist(_ values: PracticePolicySyncValues, revision: Int, userID: String) {
        defaults.set(values.dayReset, forKey: Key.lastDayReset)
        defaults.set(values.calculationMethod, forKey: Key.lastCalculationMethod)
        defaults.set(values.madhab, forKey: Key.lastMadhab)
        defaults.set(revision, forKey: Key.serverRevision)
        defaults.set(userID, forKey: Key.ownerUserID)
    }

    private func isPolicyConflict(_ error: AuthServiceError) -> Bool {
        guard case .http(_, _, let errorCode) = error else { return false }
        return errorCode == "practice_policy_conflict"
    }

    private enum Key {
        static let ownerUserID = "practice_settings_owner_user_id_v1"
        static let serverRevision = "practice_settings_server_revision_v1"
        static let lastDayReset = "practice_settings_last_day_reset_v1"
        static let lastCalculationMethod = "practice_settings_last_calculation_method_v1"
        static let lastMadhab = "practice_settings_last_madhab_v1"
    }
}
