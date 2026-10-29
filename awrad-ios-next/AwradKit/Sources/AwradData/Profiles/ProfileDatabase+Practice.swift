import AwradDomain
import Foundation
import SwiftData

// The profile's practice policy (slice 3d, contracts/practice-settings/v1). One row per profile,
// the anonymous one included; in an account's profile it's the `practice_policy` entity, synced
// through the same outbox and rules as everything else.
extension ProfileDatabase {
    private var policyState: SwiftDataSyncState { SwiftDataSyncState(context: modelContext) }

    /// The policy and whether the user has chosen it; the default, untouched, when there's none.
    func localPolicy() -> LocalPracticePolicy {
        guard let record = policyState.policyRecord(), let policy = SwiftDataSyncState.policy(record.document) else {
            return LocalPracticePolicy()
        }
        return LocalPracticePolicy(policy: policy, chosen: record.chosen)
    }

    func practiceSettings() -> PracticeSettingsState {
        PracticeSettingsState(
            policy: localPolicy().policy,
            correctionsReplaced: notices().contains { $0.key.type == .practicePolicy })
    }

    /// Saves the user's policy and marks it chosen. In an account's profile (`account`), the put is
    /// queued as any edit is; the anonymous profile only saves. Either way it's one transaction.
    /// While a first sign-in waits for the account's first full read, the edit stays local and isn't
    /// queued: the account's policy, if it has one, replaces it (`finishFirstSignIn`).
    func savePolicy(_ policy: PracticePolicy, account: AwradID?) throws(PracticeSettingsError) {
        var state = policyState
        let waiting = state.policyRecord()?.signInDocument != nil
        if let account {
            SyncRules.save(.put(.practicePolicy(policy), id: account), queue: !waiting, in: &state)
        } else {
            state.setDocument(.practicePolicy(policy), for: SyncEntityKey(.practicePolicy, .random()))
        }
        if let record = state.policyRecord() {
            record.chosen = true
            // Waiting: the edit is the policy the first sign-in carries. Otherwise it's queued and
            // merges like any other edit: the first-sign-in rule is done.
            record.signInDocument = waiting ? policy.json.encoded() : nil
            record.signInChosen = waiting
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw .storage
        }
    }

    /// The first sign-in from the anonymous profile (whether this database is that profile, adopted,
    /// or a fresh one after Erase): the anonymous policy is kept, untouched by any server copy, until
    /// the account's changes feed has been read once (`finishFirstSignIn`).
    func beginFirstSignIn(with local: LocalPracticePolicy) throws {
        let data = local.policy.json.encoded()
        let record = policyState.policyRecord() ?? PracticePolicyRecord(document: data)
        if record.modelContext == nil { modelContext.insert(record) }
        record.document = data
        record.baseDocument = nil
        record.chosen = local.chosen
        record.signInDocument = data
        record.signInChosen = local.chosen
        try modelContext.save()
    }

    /// After the account's changes feed has been read in full: the account's policy if the feed had
    /// one (already stored by the page), else the anonymous one, queued as a create only if it was
    /// chosen (`PracticePolicy.afterSignIn`). Returns whether a command was queued.
    func finishFirstSignIn(account: AwradID) throws -> Bool {
        var state = policyState
        guard let record = state.policyRecord(), let data = record.signInDocument,
            let anonymous = SwiftDataSyncState.policy(data)
        else { return false }
        let key = SyncEntityKey(.practicePolicy, account)
        let known = state.knownVersion(key)
        let feed =
            known > 0
            ? state.document(key)?.practicePolicy.map { VersionedPracticePolicy(version: known, policy: $0) } : nil
        let outcome = PracticePolicy.afterSignIn(
            .firstSignIn, local: LocalPracticePolicy(policy: anonymous, chosen: record.signInChosen), account: feed)
        state.setDocument(.practicePolicy(outcome.policy), for: key)
        record.signInDocument = nil
        if let queued = outcome.queued {
            SyncRules.enqueue(.put(.practicePolicy(queued), id: account), in: &state)
        }
        try modelContext.save()
        return outcome.queued != nil
    }

    /// Dismisses the "corrections replaced" notice.
    func dismissPolicyNotices() throws {
        for notice in notices() where notice.key.type == .practicePolicy { try dismiss(notice) }
    }
}
