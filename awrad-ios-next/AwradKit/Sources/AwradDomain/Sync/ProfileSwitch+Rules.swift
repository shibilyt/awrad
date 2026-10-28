import Foundation

/// Who the data on the phone belongs to (contracts/sync/v1/fixtures/profile_switch.json).
///
/// - Before any sign-in there's one anonymous profile; its edits are saved, never queued. There's
///   at most one anonymous profile at a time.
/// - Signing in from an anonymous profile with data asks `anonymousData`. For an account without a
///   profile here, Add to my account adopts it and queues everything, and Erase replaces it with a
///   fresh profile; for an account that has one, Add merges the anonymous data into it (`merge`)
///   and Erase discards it. An empty anonymous profile asks nothing: it's adopted by a new account,
///   and stays as it is when the account already has a profile.
/// - Signing out keeps the active profile; its later edits are queued but not sent.
/// - Signing in as an account that has a profile reactivates it; a new account gets a new
///   profile, and the others stay untouched, unsent commands included.
/// - Removing a profile with unsent changes asks `unsentChanges` first. Removing the active
///   profile signs out and activates the anonymous profile, or else starts a fresh one.
/// - `accountDeleted` asks to remove or keep. Keep marks the profile `accountDeleted` and drops its
///   unsent commands: it stays usable offline but never queues or syncs again (and the active one
///   signs out).
public enum ProfileSwitch {
    /// The question `event` asks before it can finish, if any.
    public static func prompt(for event: ProfileEvent, in registry: ProfileRegistry) -> ProfilePrompt? {
        switch event {
        case .edit, .signOut:
            return nil
        case .signIn:
            guard let active = registry.active, active.isAnonymous, active.hasData else { return nil }
            return .anonymousData
        case .removeProfile(let id):
            return registry.profile(id)?.hasUnsent == true ? .unsentChanges : nil
        case .accountDeleted(let account):
            return registry.profile(account: account) == nil ? nil : .accountDeleted
        }
    }

    /// Runs `event` with the user's answer to its prompt. A needed answer that's missing (or
    /// Cancel) leaves everything as it was. `newProfileID` is the ID a profile created here gets.
    public static func apply(
        _ event: ProfileEvent, choice: ProfileChoice?, to registry: ProfileRegistry,
        newProfileID: AwradID = .random(), now: Date = Date()
    ) -> ProfileSwitchOutcome {
        let prompt = prompt(for: event, in: registry)
        var outcome = ProfileSwitchOutcome(prompt: prompt, registry: registry, queueAll: nil, sync: nil, erased: [])
        if prompt != nil, choice == nil || choice == .cancel { return outcome }
        switch event {
        case .edit:
            outcome.registry.update(registry.activeProfileID) { profile in
                profile.hasData = true
                if profile.queuesEdits { profile.hasUnsent = true }
            }
            if registry.activeProfileMaySync { outcome.sync = registry.activeProfileID }
        case .signIn(let account, let email):
            signIn(
                account: account, email: email, choice: choice, created: LocalProfile(id: newProfileID, lastUsed: now),
                &outcome)
        case .signOut:
            outcome.registry.signedInAccountID = nil
        case .removeProfile(let id):
            remove(id, newProfileID: newProfileID, now: now, &outcome)
        case .accountDeleted(let account):
            guard let profile = registry.profile(account: account) else { return outcome }
            if choice == .remove {
                remove(profile.id, newProfileID: newProfileID, now: now, &outcome)
            } else if choice == .keep {
                outcome.registry.update(profile.id) { kept in
                    kept.accountDeleted = true
                    kept.hasUnsent = false
                }
                outcome.discardUnsent = profile.id
            }
            if outcome.registry.signedInAccountID == account { outcome.registry.signedInAccountID = nil }
        }
        return outcome
    }

    private static func signIn(
        account: AwradID, email: String, choice: ProfileChoice?, created: LocalProfile,
        _ outcome: inout ProfileSwitchOutcome
    ) {
        let now = created.lastUsed
        var registry = outcome.registry
        let previous = registry.active
        registry.signedInAccountID = account
        if let existing = registry.profile(account: account) {
            registry.activeProfileID = existing.id
            registry.update(existing.id) { profile in
                profile.email = email
                profile.lastUsed = now
                profile.accountDeleted = false
            }
            // Anonymous data (the question was asked): merged into the account's profile, or erased.
            if let previous, previous.isAnonymous, previous.hasData, previous.id != existing.id {
                if choice == .addToAccount {
                    outcome.merge = ProfileMerge(from: previous.id, into: existing.id)
                    registry.update(existing.id) { profile in
                        profile.hasData = true
                        profile.hasUnsent = true
                    }
                }
                registry.profiles.removeAll { $0.id == previous.id }
                outcome.erased.append(previous.id)
            }
            outcome.sync = existing.id
        } else if let previous, previous.isAnonymous, choice != .erase {
            registry.update(previous.id) { profile in
                profile.accountID = account
                profile.email = email
                profile.lastUsed = now
                if profile.hasData { profile.hasUnsent = true }
            }
            if previous.hasData { outcome.queueAll = previous.id }
            outcome.sync = previous.id
        } else {
            if let previous, previous.isAnonymous {
                registry.profiles.removeAll { $0.id == previous.id }
                outcome.erased.append(previous.id)
            }
            var profile = created
            profile.accountID = account
            profile.email = email
            registry.profiles.append(profile)
            registry.activeProfileID = profile.id
            outcome.sync = profile.id
        }
        outcome.registry = registry
    }

    /// Removes a profile and its database. Removing the active one signs out and activates the
    /// anonymous profile still on the phone, or else starts a fresh one.
    private static func remove(_ id: AwradID, newProfileID: AwradID, now: Date, _ outcome: inout ProfileSwitchOutcome) {
        var registry = outcome.registry
        guard registry.profile(id) != nil else { return }
        registry.profiles.removeAll { $0.id == id }
        outcome.erased.append(id)
        if registry.activeProfileID == id {
            registry.signedInAccountID = nil
            if let anonymous = registry.profiles.first(where: \.isAnonymous) {
                registry.activeProfileID = anonymous.id
            } else {
                registry.profiles.append(LocalProfile(id: newProfileID, lastUsed: now))
                registry.activeProfileID = newProfileID
            }
        }
        outcome.registry = registry
    }
}
