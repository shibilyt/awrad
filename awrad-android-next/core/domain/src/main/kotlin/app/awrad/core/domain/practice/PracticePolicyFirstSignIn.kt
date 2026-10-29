package app.awrad.core.domain.practice

/**
 * A profile's policy and whether the user has **chosen** it: changed any setting since the profile was created,
 * even back to a default.
 */
public data class LocalPolicy(val policy: PracticePolicy, val chosen: Boolean)

/** A policy the server has, at [version]. */
public data class ServerPolicy(val policy: PracticePolicy, val version: Long)

/**
 * The phone's policy after a first sign-in: [policy] at [knownVersion] (0 while the server has none), and the
 * create to queue ([queued], on `base_version` 0), if any.
 */
public data class FirstSignInPolicy(val policy: PracticePolicy, val knownVersion: Long, val queued: PracticePolicy?)

/**
 * Whose practice policy a phone ends up with when it signs in from the anonymous profile into a new account
 * profile (fixture `practice_policy_first_sign_in`; contracts/practice-settings/v1/README.md, "The first sign-in"),
 * whatever the user answered to Add to my account or Erase. Signing in to an account that already has a profile
 * on the phone keeps that profile's own policy, and the anonymous one is discarded.
 */
public object PracticePolicyFirstSignIn {

    /**
     * The account's policy, from its changes feed, when it has one ([account]); otherwise this phone's ([local]),
     * queued as a create only if the user chose it. Untouched defaults are never uploaded.
     */
    public fun decide(local: LocalPolicy, account: ServerPolicy?): FirstSignInPolicy = when {
        account != null -> FirstSignInPolicy(account.policy, account.version, queued = null)
        local.chosen -> FirstSignInPolicy(local.policy, knownVersion = 0, queued = local.policy)
        else -> FirstSignInPolicy(local.policy, knownVersion = 0, queued = null)
    }
}
