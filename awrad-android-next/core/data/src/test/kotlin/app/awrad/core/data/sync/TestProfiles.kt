package app.awrad.core.data.sync

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.data.profile.ProfileStorage
import app.awrad.core.database.AwradDatabase
import app.awrad.core.database.ProfileRegistryDatabase
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.UuidV7
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import java.io.File
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset

/** Profiles in memory: each profile's database stays open, so "reopening" it finds its data. */
internal class InMemoryProfileStorage(private val context: Context) : ProfileStorage {
    val databases = mutableMapOf<AwradId, AwradDatabase>()
    val deleted = mutableListOf<AwradId>()

    override fun open(profileId: AwradId): AwradDatabase = databases.getOrPut(profileId) {
        Room.inMemoryDatabaseBuilder(context, AwradDatabase::class.java)
            .allowMainThreadQueries()
            .setQueryExecutor { it.run() }
            .setTransactionExecutor { it.run() }
            .build()
    }

    override fun filesDir(profileId: AwradId): File = File(context.cacheDir, "profiles/${profileId.value}")

    override fun release(database: AwradDatabase) = Unit

    override fun delete(profileId: AwradId) {
        databases.remove(profileId)?.close()
        deleted += profileId
    }
}

/** A clock tests move by hand. */
internal class TestClock(var now: Instant = Instant.parse("2026-10-28T09:00:00Z")) : Clock() {
    override fun instant(): Instant = now

    override fun getZone() = ZoneOffset.UTC

    override fun withZone(zone: java.time.ZoneId?) = this
}

/** Sequential UUIDv7 IDs, so tests can name them. */
internal class TestIds {
    private var next = 0L

    fun next(): AwradId = AwradId(UuidV7.format(++next, ByteArray(UuidV7.RANDOM_BYTES)))
}

/** The profile machinery of `:core:data` over in-memory Room, for one test. */
internal class TestProfiles(scope: TestScope) {
    val context: Context = ApplicationProvider.getApplicationContext()
    val registryDatabase: ProfileRegistryDatabase =
        Room.inMemoryDatabaseBuilder(context, ProfileRegistryDatabase::class.java)
            .allowMainThreadQueries()
            .setQueryExecutor { it.run() }
            .setTransactionExecutor { it.run() }
            .build()
    val registry = registryDatabase.registryDao()
    val storage = InMemoryProfileStorage(context)
    val clock = TestClock()
    val ids = TestIds()
    val databases = ProfileDatabases(
        registry = registry,
        storage = storage,
        clock = clock,
        newId = ids::next,
        scope = scope.backgroundScope,
        io = StandardTestDispatcher(scope.testScheduler),
        closeDelay = Duration.ZERO,
    )
}
