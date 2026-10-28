package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId

/**
 * One local profile in the registry: one account's data on this phone, or the anonymous data before any
 * sign-in (CONTEXT.md, "Local profile"). Each is its own database. [after] is its changes-feed position;
 * [hasData] means it holds a custom dhikr, tag or personal record, [hasUnsent] that its queue isn't empty.
 */
public data class ProfileEntry(
    val profileId: AwradId,
    val accountId: AwradId?,
    val email: String?,
    val after: Long,
    val hasData: Boolean,
    val hasUnsent: Boolean,
) {
    val isAnonymous: Boolean get() = accountId == null
}

/** Every profile on the phone in creation order, the active one, and who is signed in. */
public data class ProfileRegistry(
    val profiles: List<ProfileEntry>,
    val activeProfileId: AwradId,
    val signedInAccountId: AwradId?,
) {
    val active: ProfileEntry get() = profiles.first { it.profileId == activeProfileId }

    public fun profile(id: AwradId): ProfileEntry? = profiles.firstOrNull { it.profileId == id }

    public fun profileOf(accountId: AwradId): ProfileEntry? = profiles.firstOrNull { it.accountId == accountId }
}

/** What happened that may change who the data belongs to. */
public sealed interface ProfileEvent {
    /** A change was saved in the active profile. */
    public data object Edit : ProfileEvent

    public data class SignIn(val accountId: AwradId, val email: String) : ProfileEvent

    public data object SignOut : ProfileEvent

    /** Settings, "Remove from this device". */
    public data class RemoveProfile(val profileId: AwradId) : ProfileEvent

    /** The phone learned that [accountId] no longer exists (`401 account_deleted` on refresh). */
    public data class AccountDeleted(val accountId: AwradId) : ProfileEvent
}

/** A question an event asks before it's applied. */
public enum class ProfilePrompt(public val wire: String) {
    /** The first sign-in found anonymous data: add it to the account, or erase it. */
    ANONYMOUS_DATA("anonymous_data"),

    /** The profile to remove has changes that were never sent: remove anyway, or cancel. */
    UNSENT_CHANGES("unsent_changes"),

    /** The profile's account no longer exists: remove the profile, or keep it. */
    ACCOUNT_DELETED("account_deleted"),
}

/** The user's answer to a [ProfilePrompt]. */
public enum class ProfileChoice(public val wire: String) {
    ADD_TO_ACCOUNT("add_to_account"),
    ERASE("erase"),
    REMOVE("remove"),
    CANCEL("cancel"),
    KEEP("keep"),
}

/**
 * What an event leads to: the [registry] afterwards, the profile whose every entity is queued as a put
 * ([queueAll]), the profile that syncs now ([sync]: send its queue, then pull), and the profiles [erased].
 * [mergeInto] is set when an anonymous profile's data goes into an account's existing profile (signing in, with
 * anonymous data, as an account this phone already has): copy it there and queue it, then erase the anonymous one.
 */
public data class ProfileOutcome(
    val prompt: ProfilePrompt?,
    val registry: ProfileRegistry,
    val queueAll: AwradId? = null,
    val sync: AwradId? = null,
    val erased: List<AwradId> = emptyList(),
    val mergeInto: AwradId? = null,
)

/**
 * Who the data on a phone belongs to (fixture `profile_switch`; contracts/sync/v1/README.md, "Local profiles").
 * [promptFor] says which question an event asks; [apply] applies it with the user's answer.
 */
public object ProfileSwitch {

    /** The question [event] asks in [registry], or null when it asks none. */
    public fun promptFor(registry: ProfileRegistry, event: ProfileEvent): ProfilePrompt? = when (event) {
        is ProfileEvent.SignIn -> {
            val active = registry.active
            ProfilePrompt.ANONYMOUS_DATA.takeIf { active.isAnonymous && active.hasData }
        }
        is ProfileEvent.RemoveProfile ->
            ProfilePrompt.UNSENT_CHANGES.takeIf { registry.profile(event.profileId)?.hasUnsent == true }
        is ProfileEvent.AccountDeleted ->
            ProfilePrompt.ACCOUNT_DELETED.takeIf { registry.profileOf(event.accountId) != null }
        ProfileEvent.Edit, ProfileEvent.SignOut -> null
    }

    /**
     * Applies [event] with the user's [choice] (null when nothing was asked). A profile created by the event gets
     * [newProfileId].
     */
    public fun apply(
        registry: ProfileRegistry,
        event: ProfileEvent,
        choice: ProfileChoice?,
        newProfileId: AwradId,
    ): ProfileOutcome {
        val prompt = promptFor(registry, event)
        return when (event) {
            ProfileEvent.Edit -> edit(registry)
            ProfileEvent.SignOut -> ProfileOutcome(null, registry.copy(signedInAccountId = null))
            is ProfileEvent.SignIn -> signIn(registry, event, choice, newProfileId).copy(prompt = prompt)
            is ProfileEvent.RemoveProfile ->
                if (prompt != null && choice != ProfileChoice.REMOVE) {
                    ProfileOutcome(prompt, registry)
                } else {
                    remove(registry, event.profileId, newProfileId).copy(prompt = prompt)
                }
            is ProfileEvent.AccountDeleted -> accountDeleted(
                registry,
                event,
                choice,
                newProfileId,
            ).copy(prompt = prompt)
        }
    }

    /** Whether edits in [profile] are queued: only a profile that belongs to an account queues. */
    public fun queuesEdits(profile: ProfileEntry): Boolean = !profile.isAnonymous

    /** Whether [profile] may sync now: the signed-in account owns it (the engine's first safety check). */
    public fun maySync(profile: ProfileEntry, signedInAccountId: AwradId?): Boolean =
        signedInAccountId != null && profile.accountId == signedInAccountId

    private fun edit(registry: ProfileRegistry): ProfileOutcome {
        val active = registry.active
        val edited = active.copy(hasData = true, hasUnsent = active.hasUnsent || queuesEdits(active))
        val updated = registry.replace(edited)
        return ProfileOutcome(
            prompt = null,
            registry = updated,
            sync = active.profileId.takeIf { queuesEdits(active) && maySync(active, registry.signedInAccountId) },
        )
    }

    private fun signIn(
        registry: ProfileRegistry,
        event: ProfileEvent.SignIn,
        choice: ProfileChoice?,
        newProfileId: AwradId,
    ): ProfileOutcome {
        val active = registry.active
        val signedIn = registry.copy(signedInAccountId = event.accountId)
        val existing = registry.profileOf(event.accountId)
        val adds = active.hasData && choice == ProfileChoice.ADD_TO_ACCOUNT
        return when {
            existing != null && active.isAnonymous -> mergeAnonymous(signedIn, existing.copy(email = event.email), adds)
            existing != null -> ProfileOutcome(
                prompt = null,
                registry = signedIn
                    .copy(activeProfileId = existing.profileId)
                    .replace(existing.copy(email = event.email)),
                sync = existing.profileId,
            )
            active.isAnonymous && active.hasData && !adds -> {
                // Erase: a fresh profile for the account takes the anonymous one's place.
                val fresh = newProfile(newProfileId, event)
                ProfileOutcome(
                    prompt = null,
                    registry = signedIn.copy(
                        profiles = signedIn.profiles.map { if (it.profileId == active.profileId) fresh else it },
                        activeProfileId = fresh.profileId,
                    ),
                    sync = fresh.profileId,
                    erased = listOf(active.profileId),
                )
            }
            active.isAnonymous -> adopt(signedIn, event)
            else -> {
                val fresh = newProfile(newProfileId, event)
                ProfileOutcome(
                    prompt = null,
                    registry = signedIn.copy(profiles = signedIn.profiles + fresh, activeProfileId = fresh.profileId),
                    sync = fresh.profileId,
                )
            }
        }
    }

    /** The account already has a profile here: the anonymous data goes into it when [adds], else it's erased. */
    private fun mergeAnonymous(signedIn: ProfileRegistry, target: ProfileEntry, adds: Boolean): ProfileOutcome {
        val anonymous = signedIn.active
        val updated = signedIn.copy(
            profiles = signedIn.profiles.filterNot { it.profileId == anonymous.profileId },
            activeProfileId = target.profileId,
        ).replace(if (adds) target.copy(hasData = true, hasUnsent = true) else target)
        return ProfileOutcome(
            prompt = null,
            registry = updated,
            sync = target.profileId,
            erased = listOf(anonymous.profileId),
            mergeInto = target.profileId.takeIf { adds },
        )
    }

    /** "Add to my account" (or an empty anonymous profile): the anonymous profile becomes the account's. */
    private fun adopt(signedIn: ProfileRegistry, event: ProfileEvent.SignIn): ProfileOutcome {
        val anonymous = signedIn.active
        val adopted = anonymous.copy(
            accountId = event.accountId,
            email = event.email,
            hasUnsent = anonymous.hasUnsent || anonymous.hasData,
        )
        return ProfileOutcome(
            prompt = null,
            registry = signedIn.replace(adopted),
            queueAll = anonymous.profileId.takeIf { anonymous.hasData },
            sync = anonymous.profileId,
        )
    }

    private fun remove(registry: ProfileRegistry, profileId: AwradId, newProfileId: AwradId): ProfileOutcome {
        registry.profile(profileId) ?: return ProfileOutcome(null, registry)
        val remaining = registry.profiles.filterNot { it.profileId == profileId }
        val updated = if (profileId == registry.activeProfileId) {
            // As on a new install: signed out, with a fresh, empty anonymous profile.
            val anonymous = ProfileEntry(newProfileId, null, null, 0, hasData = false, hasUnsent = false)
            ProfileRegistry(remaining + anonymous, anonymous.profileId, signedInAccountId = null)
        } else {
            registry.copy(profiles = remaining)
        }
        return ProfileOutcome(prompt = null, registry = updated, erased = listOf(profileId))
    }

    private fun accountDeleted(
        registry: ProfileRegistry,
        event: ProfileEvent.AccountDeleted,
        choice: ProfileChoice?,
        newProfileId: AwradId,
    ): ProfileOutcome {
        val signedOut = if (registry.signedInAccountId == event.accountId) {
            registry.copy(signedInAccountId = null)
        } else {
            registry
        }
        val profile = signedOut.profileOf(event.accountId)
        return if (profile != null && choice == ProfileChoice.REMOVE) {
            remove(signedOut, profile.profileId, newProfileId)
        } else {
            ProfileOutcome(prompt = null, registry = signedOut)
        }
    }

    private fun newProfile(id: AwradId, event: ProfileEvent.SignIn) =
        ProfileEntry(id, event.accountId, event.email, after = 0, hasData = false, hasUnsent = false)

    private fun ProfileRegistry.replace(entry: ProfileEntry): ProfileRegistry =
        copy(profiles = profiles.map { if (it.profileId == entry.profileId) entry else it })
}
