package app.awrad.core.data.profile

import app.awrad.core.database.ProfileEntity
import app.awrad.core.database.RegistryDao
import app.awrad.core.database.RegistryEntity
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.AccountRepository
import app.awrad.core.domain.account.SignInState
import app.awrad.core.domain.account.SignOutReason
import app.awrad.core.domain.sync.LocalProfile
import app.awrad.core.domain.sync.PendingProfilePrompt
import app.awrad.core.domain.sync.ProfileChoice
import app.awrad.core.domain.sync.ProfileEntry
import app.awrad.core.domain.sync.ProfileEvent
import app.awrad.core.domain.sync.ProfileOutcome
import app.awrad.core.domain.sync.ProfilePrompt
import app.awrad.core.domain.sync.ProfileRegistry
import app.awrad.core.domain.sync.ProfileService
import app.awrad.core.domain.sync.ProfileSwitch
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Clock
import java.time.Instant

/**
 * The local profiles (contracts/sync/v1, "Local profiles"; fixture `profile_switch`): it turns sign-ins,
 * sign-outs, a deleted account and "Remove from this device" into [ProfileSwitch] events, asks the questions they
 * raise, and carries out the outcome: the registry, which database is active, what's queued, erased or synced.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@Suppress("LongParameterList") // The seams it coordinates: databases, registry, session, transfers, sync, clock, IDs.
internal class ProfileManager(
    private val databases: ProfileDatabases,
    private val registry: RegistryDao,
    private val accounts: AccountRepository,
    private val transfers: ProfileTransfers,
    private val requestSync: () -> Unit,
    private val clock: Clock,
    private val newId: () -> AwradId,
) : ProfileService {

    private val mutex = Mutex()
    private val mutablePrompt = MutableStateFlow<PendingProfilePrompt?>(null)
    private var pendingEvent: ProfileEvent? = null
    private var signedIn: AwradId? = null

    override val prompt: StateFlow<PendingProfilePrompt?> = mutablePrompt.asStateFlow()

    override val profiles: Flow<List<LocalProfile>> = databases.active.flatMapLatest { active ->
        combine(registry.observeProfiles(), active.database.syncDao().observeOutboxCount()) { entries, _ ->
            entries.map { entry ->
                val id = AwradId(entry.profileId)
                LocalProfile(
                    profileId = id,
                    email = entry.email,
                    isActive = id == active.profileId,
                    hasUnsent = transfers.hasUnsent(id),
                    lastUsedAt = Instant.ofEpochMilli(entry.lastUsedAt),
                )
            }.sortedWith(compareByDescending<LocalProfile> { it.isActive }.thenByDescending { it.lastUsedAt })
        }
    }

    /** Follows the account session for as long as the app runs: each change is a profile event. */
    suspend fun run() {
        accounts.session.collect { state ->
            when (state) {
                is SignInState.SignedIn -> handle(ProfileEvent.SignIn(state.account.id, state.account.email))
                is SignInState.SignedOut -> {
                    handle(ProfileEvent.SignOut)
                    val deleted = state.accountId
                    if (state.reason == SignOutReason.ACCOUNT_DELETED && deleted != null) {
                        handle(ProfileEvent.AccountDeleted(deleted))
                    }
                }
            }
        }
    }

    override suspend fun answer(choice: ProfileChoice) {
        mutex.withLock {
            val event = pendingEvent ?: return@withLock
            pendingEvent = null
            mutablePrompt.value = null
            apply(snapshot(), event, choice)
        }
    }

    override suspend fun removalPrompt(profileId: AwradId): ProfilePrompt? =
        mutex.withLock { ProfileSwitch.promptFor(snapshot(), ProfileEvent.RemoveProfile(profileId)) }

    override suspend fun remove(profileId: AwradId) {
        val signsOut = mutex.withLock {
            val activeAndSignedIn = signedIn != null && databases.current().profileId == profileId
            apply(snapshot(), ProfileEvent.RemoveProfile(profileId), ProfileChoice.REMOVE)
            activeAndSignedIn
        }
        // Removing the active profile signs its account out, as on a new install.
        if (signsOut) accounts.signOut()
    }

    private suspend fun handle(event: ProfileEvent) = mutex.withLock {
        // Signing out before answering the first sign-in's question drops it; the next sign-in asks again.
        if (event == ProfileEvent.SignOut && pendingEvent is ProfileEvent.SignIn) {
            pendingEvent = null
            mutablePrompt.value = null
        }
        val current = snapshot()
        when (ProfileSwitch.promptFor(current, event)) {
            null -> apply(current, event, choice = null)
            ProfilePrompt.ANONYMOUS_DATA ->
                ask(event, PendingProfilePrompt.AnonymousData((event as ProfileEvent.SignIn).email))
            ProfilePrompt.ACCOUNT_DELETED -> {
                // The session has already ended; the question is only whether to keep the data.
                val profile = current.profileOf((event as ProfileEvent.AccountDeleted).accountId)
                if (profile != null) ask(event, PendingProfilePrompt.AccountDeleted(profile.profileId, profile.email))
            }
            ProfilePrompt.UNSENT_CHANGES -> apply(current, event, ProfileChoice.CANCEL)
        }
    }

    private fun ask(event: ProfileEvent, prompt: PendingProfilePrompt) {
        pendingEvent = event
        mutablePrompt.value = prompt
    }

    /** Carries out [event] with [choice]: the registry first, then the active database, then the data. */
    private suspend fun apply(current: ProfileRegistry, event: ProfileEvent, choice: ProfileChoice?) {
        val outcome = ProfileSwitch.apply(current, event, choice, newId())
        signedIn = outcome.registry.signedInAccountId
        saveRegistry(outcome)
        val anonymous = current.active.profileId
        outcome.mergeInto?.let { target -> transfers.mergeAnonymous(from = anonymous, into = target) }
        if (outcome.registry.activeProfileId != databases.current().profileId) {
            databases.activate(outcome.registry.activeProfileId)
        } else {
            databases.refresh()
        }
        outcome.queueAll?.let { transfers.queueAll(it) }
        outcome.erased.forEach { databases.erase(it) }
        if (outcome.sync != null) requestSync()
    }

    private suspend fun saveRegistry(outcome: ProfileOutcome) {
        val stored = registry.profiles().associateBy { it.profileId }
        val now = clock.millis()
        val entities = outcome.registry.profiles.map { profile ->
            stored[profile.profileId.value]?.copy(accountId = profile.accountId?.value, email = profile.email)
                ?: ProfileEntity(profile.profileId.value, profile.accountId?.value, profile.email, 0, now, now)
        }
        registry.replace(entities, RegistryEntity(activeProfileId = outcome.registry.activeProfileId.value))
    }

    /** The registry as the rules see it, with each profile's data and queue looked up in its database. */
    private suspend fun snapshot(): ProfileRegistry {
        val active = databases.current()
        val entries = registry.profiles().map { entry ->
            val id = AwradId(entry.profileId)
            ProfileEntry(
                profileId = id,
                accountId = entry.accountId?.let(::AwradId),
                email = entry.email,
                after = entry.after,
                hasData = transfers.hasData(id),
                hasUnsent = transfers.hasUnsent(id),
            )
        }
        return ProfileRegistry(entries, active.profileId, signedIn)
    }
}
