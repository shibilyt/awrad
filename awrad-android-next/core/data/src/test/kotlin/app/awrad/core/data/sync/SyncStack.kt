package app.awrad.core.data.sync

import app.awrad.core.data.personal.AudioFiles
import app.awrad.core.data.personal.RoomCustomDhikrRepository
import app.awrad.core.data.personal.RoomTagRepository
import app.awrad.core.data.profile.ProfileManager
import app.awrad.core.data.profile.ProfileTransfers
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.Account
import app.awrad.core.domain.account.SignInState
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.OptionalTexts
import app.awrad.core.domain.sync.LocalEntity
import app.awrad.core.domain.sync.OutboxCommand
import app.awrad.core.domain.sync.SyncConflict
import app.awrad.core.testing.FakeAccountRepository
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope

/** The whole sync stack of `:core:data` over in-memory Room and a [FakeSyncServer], for one test. */
internal class SyncStack(scope: TestScope, signedIn: Account? = ACCOUNT) {
    val profiles = TestProfiles(scope)
    val databases = profiles.databases
    val accounts = FakeAccountRepository(signedIn?.let { SignInState.SignedIn(it) } ?: SignInState.SignedOut())
    val server = FakeSyncServer(ACCOUNT.id)
    val engine = SyncEngine(databases, profiles.registry, accounts, server, profiles.clock)
    val scheduler = SyncScheduler(engine::syncOnce)
    val sync = ProfileSyncService(
        databases,
        accounts,
        engine,
        scheduler,
        profiles.clock,
        profiles.ids::next,
        scope.backgroundScope,
    )
    val dhikrs = RoomCustomDhikrRepository(
        databases,
        AudioFiles(profiles.context.contentResolver),
        sync,
        profiles.clock,
        profiles.ids::next,
        StandardTestDispatcher(scope.testScheduler),
    )
    val tags = RoomTagRepository(databases, sync, profiles.clock, profiles.ids::next)
    val manager = ProfileManager(
        databases = databases,
        registry = profiles.registry,
        accounts = accounts,
        transfers = ProfileTransfers(databases, profiles.clock, profiles.ids::next),
        requestSync = { scheduler.request(debounced = false) },
        clock = profiles.clock,
        newId = profiles.ids::next,
    )

    /** Makes the active profile [account]'s, as adopting it at the first sign-in does. */
    suspend fun ownActiveProfile(account: Account = ACCOUNT) {
        val active = databases.current()
        val entry = profiles.registry.profiles().first { it.profileId == active.profileId.value }
        profiles.registry.upsertProfile(entry.copy(accountId = account.id.value, email = account.email))
        databases.refresh()
    }

    suspend fun outbox(): List<OutboxCommand> = databases.write {
        it.database.syncDao().outbox().map { row -> row.toCommand() }
    }!!

    suspend fun entities(): List<LocalEntity> = databases.write { profile ->
        val store = RoomSyncStore(profile.database.syncDao()) { 0L }
        app.awrad.core.domain.sync.EntityType.entries.flatMap { store.entities(it) }
    }!!

    suspend fun conflicts(): List<SyncConflict> =
        databases.write { profile -> profile.database.syncDao().conflicts().map { it.toConflict() } }!!

    suspend fun after(): Long = databases.write { it.database.syncDao().meta()?.after ?: 0L }!!

    companion object {
        val ACCOUNT = Account(AwradId("0192f0b0-0000-7000-8000-000000000001"), "amina@example.com")
        val OTHER = Account(AwradId("0192f0b0-0000-7000-8000-000000000002"), "bilal@example.com")

        /** A built-in dhikr's ID (the catalog's tahleel), which personal records can tag. */
        val BUILT_IN = AwradId("6f04f77e-dcb6-4a29-9dc5-fcd3649c2961")

        fun dhikr(id: AwradId, title: String = "Subhanallah") = CustomDhikr(
            id = id,
            kind = DhikrKind.DHIKR,
            arabic = "سُبْحَانَ ٱللَّهِ",
            title = OptionalTexts(en = title),
        )
    }
}
