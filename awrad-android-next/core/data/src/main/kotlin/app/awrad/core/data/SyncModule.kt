package app.awrad.core.data

import android.content.Context
import app.awrad.core.data.personal.AudioFiles
import app.awrad.core.data.personal.RoomCustomDhikrRepository
import app.awrad.core.data.personal.RoomTagRepository
import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.data.sync.NetworkSyncRemote
import app.awrad.core.data.sync.ProfileSyncService
import app.awrad.core.data.sync.SyncEngine
import app.awrad.core.data.sync.SyncRemote
import app.awrad.core.data.sync.SyncScheduler
import app.awrad.core.database.RegistryDao
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.AccountRepository
import app.awrad.core.domain.personal.CustomDhikrRepository
import app.awrad.core.domain.personal.TagRepository
import app.awrad.core.domain.sync.SyncService
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import java.time.Clock
import javax.inject.Singleton

/**
 * Custom dhikrs and tags, and the change queue that syncs them (slice 3b): the engine, its schedule, the service
 * the screens use, and the repositories.
 */
@Module
@InstallIn(SingletonComponent::class)
internal object SyncModule {

    @Provides
    fun syncRemote(adapter: NetworkSyncRemote): SyncRemote = adapter

    @Provides
    @Singleton
    fun syncEngine(
        profiles: ProfileDatabases,
        registry: RegistryDao,
        accounts: AccountRepository,
        remote: SyncRemote,
        clock: Clock,
    ): SyncEngine = SyncEngine(profiles, registry, accounts, remote, clock)

    @Provides
    @Singleton
    fun syncScheduler(engine: SyncEngine): SyncScheduler = SyncScheduler(engine::syncOnce)

    @Provides
    @Singleton
    fun syncService(
        profiles: ProfileDatabases,
        accounts: AccountRepository,
        engine: SyncEngine,
        scheduler: SyncScheduler,
        clock: Clock,
        @AppScope scope: CoroutineScope,
    ): SyncService = ProfileSyncService(
        profiles = profiles,
        accounts = accounts,
        engine = engine,
        scheduler = scheduler,
        clock = clock,
        newId = { AwradId.random(clock) },
        scope = scope,
    )

    @Provides
    @Singleton
    fun customDhikrRepository(
        @ApplicationContext context: Context,
        profiles: ProfileDatabases,
        sync: SyncService,
        clock: Clock,
    ): CustomDhikrRepository = RoomCustomDhikrRepository(
        profiles = profiles,
        audio = AudioFiles(context.contentResolver),
        sync = sync,
        clock = clock,
        newId = { AwradId.random(clock) },
        io = Dispatchers.IO,
    )

    @Provides
    @Singleton
    fun tagRepository(profiles: ProfileDatabases, sync: SyncService, clock: Clock): TagRepository =
        RoomTagRepository(profiles, sync, clock) { AwradId.random(clock) }
}
