import Foundation

// Rule: whose policy a phone ends up with at its first sign-in
// (contracts/practice-settings/v1/fixtures/practice_policy_first_sign_in.json).

/// A profile's policy with whether the user has chosen it: changed any setting since the profile
/// was created, even back to a default.
public struct LocalPracticePolicy: Hashable, Sendable {
    public var policy: PracticePolicy
    public var chosen: Bool

    public init(policy: PracticePolicy = .default, chosen: Bool = false) {
        self.policy = policy
        self.chosen = chosen
    }
}

/// A policy with the server version it's known at.
public struct VersionedPracticePolicy: Hashable, Sendable {
    public let version: Int
    public let policy: PracticePolicy

    public init(version: Int, policy: PracticePolicy) {
        self.version = version
        self.policy = policy
    }
}

/// How a sign-in reaches the account's profile.
public enum PracticePolicySignIn: Hashable, Sendable {
    /// The anonymous profile becomes the account's (Add, Erase, or an empty profile adopted).
    case firstSignIn
    /// The account already has a profile on the phone, with its policy at its known version.
    case existingProfile(VersionedPracticePolicy)
}

/// What the account's profile ends up with.
public struct PracticePolicySignInOutcome: Hashable, Sendable {
    public let policy: PracticePolicy
    public let knownVersion: Int
    /// The create queued (`base_version` 0), or `nil`.
    public let queued: PracticePolicy?
}

extension PracticePolicy {
    /// The policy after signing in from the anonymous profile `local`, whatever the user answered
    /// to Add to my account or Erase:
    ///
    /// - into an account profile already on the phone, that profile keeps its own;
    /// - the account has a policy in its changes feed (`account`): the phone takes it;
    /// - it has none and `local` is chosen: the phone keeps it and queues a create;
    /// - it has none and `local` is untouched: nothing is sent, and the account stays unset.
    ///
    /// Settings alone never count as data for the Add / Erase question.
    public static func afterSignIn(
        _ signIn: PracticePolicySignIn, local: LocalPracticePolicy, account: VersionedPracticePolicy?
    ) -> PracticePolicySignInOutcome {
        if case .existingProfile(let existing) = signIn {
            return PracticePolicySignInOutcome(policy: existing.policy, knownVersion: existing.version, queued: nil)
        }
        if let account {
            return PracticePolicySignInOutcome(policy: account.policy, knownVersion: account.version, queued: nil)
        }
        return PracticePolicySignInOutcome(
            policy: local.policy, knownVersion: 0, queued: local.chosen ? local.policy : nil)
    }
}
