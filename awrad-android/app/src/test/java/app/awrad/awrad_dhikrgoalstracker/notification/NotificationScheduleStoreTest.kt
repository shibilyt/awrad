package app.awrad.awrad_dhikrgoalstracker.notification

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import java.io.File
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.cancel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.Rule
import org.junit.rules.TemporaryFolder

class NotificationScheduleStoreTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun replacingManifestIsIdempotentAndTriggerChangeUpdatesSameStage() = runTest {
        val store = DataStoreNotificationScheduleStore(testDataStore("replace"))
        val identity = identity()

        store.replaceManifest(listOf(NotificationScheduleRecord(identity, triggerAtMillis = 100L, expiresAtMillis = 1_100L)))
        store.replaceManifest(listOf(NotificationScheduleRecord(identity, triggerAtMillis = 200L, expiresAtMillis = 1_200L)))

        val state = store.read()
        assertEquals(1, state.manifest.size)
        assertEquals(200L, state.manifest.single().triggerAtMillis)
        assertTrue(state.delivered.isEmpty())
    }

    @Test
    fun markDeliveredIsIdempotentAtomicAndSurvivesStoreRecreation() = runTest {
        val dataStore = testDataStore("delivered")
        val identity = identity()
        val store = DataStoreNotificationScheduleStore(dataStore)
        store.replaceManifest(listOf(NotificationScheduleRecord(identity, triggerAtMillis = 100L, expiresAtMillis = 1_100L)))

        store.markDelivered(identity, deliveredAtMillis = 500L)
        store.markDelivered(identity, deliveredAtMillis = 999L)

        val recreatedStore = DataStoreNotificationScheduleStore(dataStore)
        val state = recreatedStore.read()
        assertTrue(state.manifest.isEmpty())
        assertEquals(listOf(500L), state.delivered.map { it.deliveredAtMillis })
    }

    @Test
    fun replacingManifestDoesNotRestoreAnAlreadyDeliveredStage() = runTest {
        val dataStore = testDataStore("delivered-filter")
        val identity = identity()
        val store = DataStoreNotificationScheduleStore(dataStore)
        store.markDelivered(identity, deliveredAtMillis = 500L)

        store.replaceManifest(listOf(NotificationScheduleRecord(identity, triggerAtMillis = 900L, expiresAtMillis = 1_900L)))

        val reopened = DataStoreNotificationScheduleStore(dataStore).read()
        assertTrue(reopened.manifest.isEmpty())
        assertEquals(setOf(identity.canonicalKey), reopened.delivered.mapTo(mutableSetOf()) { it.identity.canonicalKey })
    }

    @Test
    fun deliveredEvidenceWinsCrossLedgerOverlapAndPreventsResurrection() = runTest {
        val dataStore = testDataStore("cross-ledger-overlap")
        val identity = identity()
        dataStore.edit { preferences ->
            preferences[manifestKey] = setOf(manifestJson(identity, triggerAtMillis = 100L))
            preferences[deliveredKey] = setOf(deliveredJson(identity, deliveredAtMillis = 200L))
        }
        val store = DataStoreNotificationScheduleStore(dataStore)

        val cleaned = store.read()
        assertTrue(cleaned.manifest.isEmpty())
        assertEquals(listOf(200L), cleaned.delivered.map { it.deliveredAtMillis })
        assertEquals(1, cleaned.discardedEntryCount)
        assertTrue(dataStore.data.first()[manifestKey].isNullOrEmpty())

        store.replaceManifest(listOf(NotificationScheduleRecord(identity, triggerAtMillis = 300L, expiresAtMillis = 1_300L)))
        val reopened = DataStoreNotificationScheduleStore(dataStore).read()
        assertTrue(reopened.manifest.isEmpty())
        assertEquals(listOf(200L), reopened.delivered.map { it.deliveredAtMillis })
    }

    @Test
    fun duplicateDeliveredRecordsKeepEarliestTombstoneAcrossCleanupAndReplacement() = runTest {
        val dataStore = testDataStore("duplicate-delivered")
        val identity = identity()
        dataStore.edit { preferences ->
            preferences[deliveredKey] = setOf(
                deliveredJson(identity, deliveredAtMillis = 900L),
                deliveredJson(identity, deliveredAtMillis = 100L, reverseFieldOrder = true),
            )
        }
        val store = DataStoreNotificationScheduleStore(dataStore)

        val cleaned = store.read()
        assertTrue(cleaned.manifest.isEmpty())
        assertEquals(listOf(100L), cleaned.delivered.map { it.deliveredAtMillis })
        assertEquals(2, cleaned.discardedEntryCount)
        assertEquals(1, dataStore.data.first()[deliveredKey].orEmpty().size)

        store.replaceManifest(listOf(NotificationScheduleRecord(identity, triggerAtMillis = 300L, expiresAtMillis = 1_300L)))
        val recreated = DataStoreNotificationScheduleStore(dataStore).read()
        assertTrue(recreated.manifest.isEmpty())
        assertEquals(listOf(100L), recreated.delivered.map { it.deliveredAtMillis })
    }

    @Test
    fun malformedAndUnknownVersionEntriesAreExcludedSurfacedAndCleaned() = runTest {
        val dataStore = testDataStore("malformed")
        dataStore.edit { preferences ->
            preferences[manifestKey] = setOf(
                "not json",
                """{"format":3,"identity":"future"}""",
            )
            preferences[deliveredKey] = setOf("not json")
        }

        val state = DataStoreNotificationScheduleStore(dataStore).read()

        assertTrue(state.manifest.isEmpty())
        assertTrue(state.delivered.isEmpty())
        assertEquals(3, state.discardedEntryCount)
        assertTrue(dataStore.data.first()[manifestKey].isNullOrEmpty())
        assertTrue(dataStore.data.first()[deliveredKey].isNullOrEmpty())
    }

    @Test
    fun oldManifestWithoutExpiryIsDiscardedAndCleaned() = runTest {
        val dataStore = testDataStore("old-manifest")
        val identity = identity()
        dataStore.edit { preferences ->
            preferences[manifestKey] = setOf(
                """{"format":1,"identity":"${identity.canonicalKey}","triggerAtMillis":100,"kind":"${identity.kind.name}"}""",
            )
        }

        val state = DataStoreNotificationScheduleStore(dataStore).read()

        assertTrue(state.manifest.isEmpty())
        assertEquals(1, state.discardedEntryCount)
        assertTrue(dataStore.data.first()[manifestKey].isNullOrEmpty())
    }

    @Test
    fun conflictingDuplicateManifestEntriesAreAllDiscarded() = runTest {
        val dataStore = testDataStore("conflicting-duplicates")
        val identity = identity()
        dataStore.edit { preferences ->
            preferences[manifestKey] = setOf(
                manifestJson(identity, triggerAtMillis = 100L),
                manifestJson(identity, triggerAtMillis = 200L, reverseFieldOrder = true),
            )
        }

        val state = DataStoreNotificationScheduleStore(dataStore).read()

        assertTrue(state.manifest.isEmpty())
        assertEquals(2, state.discardedEntryCount)
        assertTrue(dataStore.data.first()[manifestKey].isNullOrEmpty())
    }

    @Test
    fun identicalDuplicateManifestEntriesAreAllDiscarded() = runTest {
        val dataStore = testDataStore("identical-duplicates")
        val identity = identity()
        dataStore.edit { preferences ->
            preferences[manifestKey] = setOf(
                manifestJson(identity, triggerAtMillis = 100L),
                manifestJson(identity, triggerAtMillis = 100L, reverseFieldOrder = true),
            )
        }

        val state = DataStoreNotificationScheduleStore(dataStore).read()

        assertTrue(state.manifest.isEmpty())
        assertEquals(2, state.discardedEntryCount)
        assertTrue(dataStore.data.first()[manifestKey].isNullOrEmpty())
    }

    @Test
    fun clearExactAndClearGoalRemoveManifestAndDeliveredState() = runTest {
        val store = DataStoreNotificationScheduleStore(testDataStore("clear"))
        val firstGoal = UUID.fromString("00000000-0000-0000-0000-000000000011")
        val first = identity(goalId = firstGoal, scope = "first")
        val second = identity(goalId = firstGoal, scope = "second")
        val other = identity(goalId = UUID.randomUUID())
        store.replaceManifest(
            listOf(
                NotificationScheduleRecord(first, 1L, 1_001L),
                NotificationScheduleRecord(second, 2L, 1_002L),
                NotificationScheduleRecord(other, 3L, 1_003L),
            ),
        )
        store.markDelivered(first, 4L)
        store.markDelivered(other, 5L)

        store.clearExact(first.canonicalKey)
        assertEquals(setOf(second.canonicalKey), store.read().manifest.mapTo(mutableSetOf()) { it.identity.canonicalKey })

        store.clearGoal(firstGoal)
        val state = store.read()
        assertEquals(setOf(other.canonicalKey), state.delivered.mapTo(mutableSetOf()) { it.identity.canonicalKey })
        assertTrue(state.manifest.isEmpty())
    }

    @Test
    fun retainDeliveredPrunesUnretainedStages() = runTest {
        val store = DataStoreNotificationScheduleStore(testDataStore("prune"))
        val retained = identity(scope = "retain")
        val stale = identity(scope = "stale")
        store.markDelivered(retained, 1L)
        store.markDelivered(stale, 2L)

        store.retainDelivered(setOf(retained.canonicalKey))

        assertEquals(
            setOf(retained.canonicalKey),
            store.read().delivered.mapTo(mutableSetOf()) { it.identity.canonicalKey },
        )
    }

    @Test
    fun pruneDeliveredKeepsKnownExpiryUntilBothExpiryAndRetentionPass() = runTest {
        val store = DataStoreNotificationScheduleStore(testDataStore("expiry-prune"))
        val identity = identity()
        store.markDelivered(identity, deliveredAtMillis = 0L, expiresAtMillis = 200L)

        store.pruneDelivered(nowMillis = 100L, retentionMillis = 50L)
        assertEquals(1, store.read().delivered.size)

        store.pruneDelivered(nowMillis = 200L, retentionMillis = 50L)
        assertTrue(store.read().delivered.isEmpty())
    }

    @Test
    fun pruneDeliveredDoesNotMassDeleteFutureOrUnknownExpiryTombstones() = runTest {
        val store = DataStoreNotificationScheduleStore(testDataStore("future-prune"))
        store.markDelivered(identity(scope = "future"), deliveredAtMillis = Long.MAX_VALUE)
        store.markDelivered(identity(scope = "legacy"), deliveredAtMillis = Long.MIN_VALUE)

        store.pruneDelivered(nowMillis = Long.MIN_VALUE, retentionMillis = 48L * 60L * 60L * 1_000L)

        assertEquals(2, store.read().delivered.size)
    }

    @Test
    fun concurrentDeliveryMarksDoNotLoseStages() = runTest {
        val store = DataStoreNotificationScheduleStore(testDataStore("concurrent"))
        val identities = (1..20).map { identity(scope = "scope-$it") }

        coroutineScope {
            identities.map { identity ->
                async(Dispatchers.Default) { store.markDelivered(identity, deliveredAtMillis = 1L) }
            }.awaitAll()
        }

        assertEquals(
            identities.mapTo(mutableSetOf()) { it.canonicalKey },
            store.read().delivered.mapTo(mutableSetOf()) { it.identity.canonicalKey },
        )
    }

    @Test
    fun stateSurvivesRealDataStoreRecreationAfterOriginalScopeCloses() = runTest {
        val file = temporaryFolder.newFile("recreated.preferences_pb")
        val identity = identity()
        val firstScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val firstStore = DataStoreNotificationScheduleStore(dataStoreFor(file, firstScope))
        firstStore.replaceManifest(listOf(NotificationScheduleRecord(identity, triggerAtMillis = 100L, expiresAtMillis = 1_100L)))
        firstStore.markDelivered(identity(scope = "delivered"), deliveredAtMillis = 200L)
        firstScope.cancel()

        val secondScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        try {
            val restored = DataStoreNotificationScheduleStore(dataStoreFor(file, secondScope)).read()
            assertEquals(setOf(identity.canonicalKey), restored.manifest.mapTo(mutableSetOf()) { it.identity.canonicalKey })
            assertEquals(
                setOf(identity(scope = "delivered").canonicalKey),
                restored.delivered.mapTo(mutableSetOf()) { it.identity.canonicalKey },
            )
        } finally {
            secondScope.cancel()
        }
    }

    @Test
    fun cleanupPersistsAcrossRealDataStoreRecreationAndBlocksResurrection() = runTest {
        val file = temporaryFolder.newFile("cleanup-recreation.preferences_pb")
        val identity = identity()
        val firstScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        try {
            val firstDataStore = dataStoreFor(file, firstScope)
            firstDataStore.edit { preferences ->
                preferences[manifestKey] = setOf(manifestJson(identity, triggerAtMillis = 50L))
                preferences[deliveredKey] = setOf(
                    deliveredJson(identity, deliveredAtMillis = 900L),
                    deliveredJson(identity, deliveredAtMillis = 100L, reverseFieldOrder = true),
                )
            }
            val cleaned = DataStoreNotificationScheduleStore(firstDataStore).read()
            assertTrue(cleaned.manifest.isEmpty())
            assertEquals(listOf(100L), cleaned.delivered.map { it.deliveredAtMillis })
            assertEquals(3, cleaned.discardedEntryCount)
            assertTrue(firstDataStore.data.first()[manifestKey].isNullOrEmpty())
            assertEquals(1, firstDataStore.data.first()[deliveredKey].orEmpty().size)
        } finally {
            firstScope.cancel()
        }

        val secondScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        try {
            val secondDataStore = dataStoreFor(file, secondScope)
            val secondStore = DataStoreNotificationScheduleStore(secondDataStore)
            val reread = secondStore.read()
            assertTrue(reread.manifest.isEmpty())
            assertEquals(listOf(100L), reread.delivered.map { it.deliveredAtMillis })
            assertEquals(0, reread.discardedEntryCount)
            assertTrue(secondDataStore.data.first()[manifestKey].isNullOrEmpty())
            assertEquals(1, secondDataStore.data.first()[deliveredKey].orEmpty().size)

            secondStore.replaceManifest(listOf(NotificationScheduleRecord(identity, triggerAtMillis = 300L, expiresAtMillis = 1_300L)))
            val afterReplace = secondStore.read()
            assertTrue(afterReplace.manifest.isEmpty())
            assertEquals(listOf(100L), afterReplace.delivered.map { it.deliveredAtMillis })
            assertEquals(0, afterReplace.discardedEntryCount)
        } finally {
            secondScope.cancel()
        }
    }

    @Test
    fun legacyDeliveredSurvivesRecreationWhileLegacyManifestIsCleaned() = runTest {
        val file = temporaryFolder.newFile("legacy-v1.preferences_pb")
        val identity = identity()
        val firstScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        try {
            val firstDataStore = dataStoreFor(file, firstScope)
            firstDataStore.edit { preferences ->
                preferences[manifestKey] = setOf(
                    """{"format":1,"identity":"${identity.canonicalKey}","triggerAtMillis":100,"kind":"${identity.kind.name}"}""",
                )
                preferences[deliveredKey] = setOf(legacyDeliveredJson(identity, 200L))
            }

            val cleaned = DataStoreNotificationScheduleStore(firstDataStore).read()

            assertTrue(cleaned.manifest.isEmpty())
            assertEquals(listOf(200L), cleaned.delivered.map { it.deliveredAtMillis })
            assertEquals(1, cleaned.discardedEntryCount)
            assertTrue(firstDataStore.data.first()[manifestKey].isNullOrEmpty())
            assertTrue(firstDataStore.data.first()[deliveredKey].orEmpty().single().contains("\"format\":2"))
        } finally {
            firstScope.cancel()
        }

        val secondScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        try {
            val reopened = DataStoreNotificationScheduleStore(dataStoreFor(file, secondScope))
            assertEquals(listOf(200L), reopened.read().delivered.map { it.deliveredAtMillis })

            reopened.replaceManifest(listOf(NotificationScheduleRecord(identity, 300L, 1_300L)))

            assertTrue(reopened.read().manifest.isEmpty())
            assertEquals(listOf(200L), reopened.read().delivered.map { it.deliveredAtMillis })
        } finally {
            secondScope.cancel()
        }
    }

    private fun TestScope.testDataStore(name: String): DataStore<Preferences> =
        PreferenceDataStoreFactory.create(scope = backgroundScope) {
            temporaryFolder.newFile("$name.preferences_pb")
        }

    private fun dataStoreFor(file: File, scope: CoroutineScope): DataStore<Preferences> =
        PreferenceDataStoreFactory.create(scope = scope) { file }

    private fun identity(
        goalId: UUID = UUID.fromString("00000000-0000-0000-0000-000000000010"),
        scope: String = "scope",
    ): NotificationIdentity = NotificationIdentity.create(
        goalId = goalId,
        obligationScope = scope,
        slotId = null,
        kind = NudgeKind.DEADLINE_WARNING,
    )

    private companion object {
        val manifestKey = stringSetPreferencesKey("notification_schedule_manifest_entries_v1")
        val deliveredKey = stringSetPreferencesKey("notification_delivered_stage_entries_v1")
    }

    private fun manifestJson(
        identity: NotificationIdentity,
        triggerAtMillis: Long,
        reverseFieldOrder: Boolean = false,
    ): String = if (reverseFieldOrder) {
        """{"kind":"${identity.kind.name}","expiresAtMillis":${triggerAtMillis + 1000},"triggerAtMillis":$triggerAtMillis,"identity":"${identity.canonicalKey}","format":2}"""
    } else {
        """{"format":2,"identity":"${identity.canonicalKey}","triggerAtMillis":$triggerAtMillis,"expiresAtMillis":${triggerAtMillis + 1000},"kind":"${identity.kind.name}"}"""
    }

    private fun deliveredJson(
        identity: NotificationIdentity,
        deliveredAtMillis: Long,
        reverseFieldOrder: Boolean = false,
    ): String = if (reverseFieldOrder) {
        """{"deliveredAtMillis":$deliveredAtMillis,"identity":"${identity.canonicalKey}","format":2}"""
    } else {
        """{"format":2,"identity":"${identity.canonicalKey}","deliveredAtMillis":$deliveredAtMillis}"""
    }

    private fun legacyDeliveredJson(identity: NotificationIdentity, deliveredAtMillis: Long): String =
        """{"format":1,"identity":"${identity.canonicalKey}","deliveredAtMillis":$deliveredAtMillis}"""
}
