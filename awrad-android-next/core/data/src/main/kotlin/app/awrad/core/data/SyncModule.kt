package app.awrad.core.data

import android.content.Context
import app.awrad.core.data.audio.AudioRemote
import app.awrad.core.data.audio.AudioUploader
import app.awrad.core.data.audio.MediaDurationProbe
import app.awrad.core.data.audio.NetworkAudioRemote
import app.awrad.core.data.audio.ProfileCustomAudioService
import app.awrad.core.data.personal.AudioFiles
import app.awrad.core.data.personal.RoomCustomDhikrRepository
import app.awrad.core.data.personal.RoomTagRepository
import app.awrad.core.data.practice.RoomPracticeSettingsRepository
import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.data.sync.NetworkSyncRemote
import app.awrad.core.data.sync.ProfileSyncService
import app.awrad.core.data.sync.SyncEngine
import app.awrad.core.data.sync.SyncRemote
import app.awrad.core.data.sync.SyncScheduler
import app.awrad.core.database.RegistryDao
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.AccountRepository
import app.awrad.core.domain.personal.CustomAudioService
import app.awrad.core.domain.personal.CustomDhikrRepository
import app.awrad.core.domain.personal.TagRepository
import app.awrad.core.domain.practice.PracticeSettingsRepository
import app.awrad.core.domain.sync.SyncService
import app.awrad.core.network.http.SignedLinkTransport
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
 * the screens use, and the repositories; and their recordings' uploads, downloads and storage (slice 3c).
 */
@Module
@InstallIn(SingletonComponent::class)
internal object SyncModule {

    @Provides
    fun syncRemote(adapter: NetworkSyncRemote): SyncRemote = adapter

    @Provides
    fun audioRemote(adapter: NetworkAudioRemote): AudioRemote = adapter

    @Provides
    @Singleton
    fun audioUploader(
        profiles: ProfileDatabases,
        remote: AudioRemote,
        links: SignedLinkTransport,
        clock: Clock,
    ): AudioUploader = AudioUploader(
        profiles = profiles,
        remote = remote,
        links = links,
        probe = MediaDurationProbe(),
        clock = clock,
        newId = { AwradId.random(clock) },
        io = Dispatchers.IO,
    )

    @Provides
    @Singleton
    @Suppress("LongParameterList") // Each is a seam the engine crosses.
    fun syncEngine(
        profiles: ProfileDatabases,
        registry: RegistryDao,
        accounts: AccountRepository,
        remote: SyncRemote,
        uploader: AudioUploader,
        clock: Clock,
    ): SyncEngine = SyncEngine(profiles, registry, accounts, remote, clock, uploader)

    @Provides
    @Singleton
    fun customAudioService(
        profiles: ProfileDatabases,
        accounts: AccountRepository,
        remote: AudioRemote,
        links: SignedLinkTransport,
    ): CustomAudioService = ProfileCustomAudioService(profiles, accounts, remote, links, Dispatchers.IO)

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

    /** The practice policy (slice 3d) is a change-queue entity like the tags. */
    @Provides
    @Singleton
    fun practiceSettingsRepository(
        profiles: ProfileDatabases,
        sync: SyncService,
        clock: Clock,
    ): PracticeSettingsRepository = RoomPracticeSettingsRepository(profiles, sync, clock) { AwradId.random(clock) }
}
