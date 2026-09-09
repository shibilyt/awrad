import Foundation
import Testing
@testable import awrad

@MainActor
struct PracticeSettingsSyncTests {
    private let defaults = PracticePolicySyncValues(
        dayReset: "midnight",
        calculationMethod: "karachi",
        madhab: "shafi"
    )

    @Test
    func anonymousNonDefaultChoicesCanInitializeAnewDefaultAccount() {
        let local = defaults.with(dayReset: "maghrib")
        let remote = PracticePolicySyncValues(
            dayReset: "midnight",
            calculationMethod: "karachi",
            madhab: "shafi"
        )

        #expect(
            PracticeSettingsSyncDecisionPlanner.decision(
                local: local,
                remote: remote,
                remoteRevision: 1,
                ownerUserID: nil,
                currentUserID: "user-a",
                lastServerRevision: 0,
                lastSynced: nil,
                defaults: defaults
            ) == .uploadLocal
        )
    }

    @Test
    func differentAccountAlwaysAppliesTheServerPolicy() {
        #expect(
            PracticeSettingsSyncDecisionPlanner.decision(
                local: defaults.with(dayReset: "maghrib"),
                remote: defaults,
                remoteRevision: 1,
                ownerUserID: "user-a",
                currentUserID: "user-b",
                lastServerRevision: 2,
                lastSynced: defaults.with(dayReset: "maghrib"),
                defaults: defaults
            ) == .applyRemote
        )
    }

    @Test
    func localChangesUploadOnlyWhenTheServerRevisionHasNotMoved() {
        let local = defaults.with(dayReset: "maghrib")

        #expect(
            PracticeSettingsSyncDecisionPlanner.decision(
                local: local,
                remote: defaults,
                remoteRevision: 3,
                ownerUserID: "user-a",
                currentUserID: "user-a",
                lastServerRevision: 3,
                lastSynced: defaults,
                defaults: defaults
            ) == .uploadLocal
        )

        #expect(
            PracticeSettingsSyncDecisionPlanner.decision(
                local: local,
                remote: defaults,
                remoteRevision: 4,
                ownerUserID: "user-a",
                currentUserID: "user-a",
                lastServerRevision: 3,
                lastSynced: defaults,
                defaults: defaults
            ) == .applyRemote
        )
    }
}

private extension PracticePolicySyncValues {
    func with(
        dayReset: String? = nil,
        calculationMethod: String? = nil,
        madhab: String? = nil
    ) -> Self {
        Self(
            dayReset: dayReset ?? self.dayReset,
            calculationMethod: calculationMethod ?? self.calculationMethod,
            madhab: madhab ?? self.madhab
        )
    }
}
