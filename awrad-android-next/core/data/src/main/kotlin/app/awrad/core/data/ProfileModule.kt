package app.awrad.core.data

import android.content.Context
import androidx.room.Room
import app.awrad.core.data.profile.AndroidProfileStorage
import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.data.profile.ProfileManager
import app.awrad.core.data.profile.ProfileTransfers
import app.awrad.core.data.sync.SyncLifecycle
import app.awrad.core.data.sync.SyncScheduler
import app.awrad.core.database.ProfileRegistryDatabase
import app.awrad.core.database.RegistryDao
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.AccountRepository
import app.awrad.core.domain.sync.ProfileService
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import java.time.Clock
import javax.inject.Qualifier
import javax.inject.Singleton

/** The app's own scope: work that outlives a screen, such as closing a profile's database after a switch. */
@Qualifier
@Retention(AnnotationRetention.BINARY)
internal annotation class AppScope

/**
 * Local profiles (slice 3b): the registry, the active profile's database, and the manager that moves between
 * profiles as accounts sign in and out. The adapters take plain functions and dispatchers, so their tests build
 * them without Hilt.
 */
@Module
@InstallIn(SingletonComponent::class)
internal object ProfileModule {

    @Provides
    @Singleton
    @AppScope
    fun appScope(): CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    @Provides
    @Singleton
    fun registryDatabase(@ApplicationContext context: Context): ProfileRegistryDatabase =
        Room.databaseBuilder(context, ProfileRegistryDatabase::class.java, ProfileRegistryDatabase.NAME).build()

    @Provides
    fun registryDao(database: ProfileRegistryDatabase): RegistryDao = database.registryDao()

    @Provides
    @Singleton
    fun profileDatabases(
        @ApplicationContext context: Context,
        registry: RegistryDao,
        clock: Clock,
        @AppScope scope: CoroutineScope,
    ): ProfileDatabases = ProfileDatabases(
        registry = registry,
        storage = AndroidProfileStorage(context),
        clock = clock,
        newId = { AwradId.random(clock) },
        scope = scope,
        io = Dispatchers.IO,
    )

    @Provides
    @Singleton
    fun profileManager(
        databases: ProfileDatabases,
        registry: RegistryDao,
        accounts: AccountRepository,
        scheduler: SyncScheduler,
        clock: Clock,
    ): ProfileManager = ProfileManager(
        databases = databases,
        registry = registry,
        accounts = accounts,
        transfers = ProfileTransfers(databases, clock) { AwradId.random(clock) },
        requestSync = { scheduler.request(debounced = false) },
        clock = clock,
        newId = { AwradId.random(clock) },
    )

    @Provides
    fun profileService(manager: ProfileManager): ProfileService = manager

    @Provides
    @Singleton
    fun syncLifecycle(manager: ProfileManager, scheduler: SyncScheduler): SyncLifecycle =
        SyncLifecycle(manager, scheduler)
}
