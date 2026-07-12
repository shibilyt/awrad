package app.awrad.awrad_dhikrgoalstracker.data.repository

import android.content.Context
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.WirdDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.WirdSessionDao
import app.awrad.awrad_dhikrgoalstracker.data.database.mapper.toDomain
import app.awrad.awrad_dhikrgoalstracker.data.database.mapper.toEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdAssetParser
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdPart
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSegment
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSession
import app.awrad.awrad_dhikrgoalstracker.data.wird.WirdEngine
import app.awrad.awrad_dhikrgoalstracker.data.wird.WirdSeedMerger
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.LocalDate
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class WirdLibraryRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    private val wirdDao: WirdDao,
    private val sessionDao: WirdSessionDao,
    private val engine: WirdEngine,
) : WirdLibraryRepository {

    override suspend fun seedLibraryWirds() {
        val seeds = loadAssetWirds()
        if (seeds.isEmpty()) return
        val persisted = wirdDao.getAll().map { it.toDomain() }
        val upserts = WirdSeedMerger.toUpsert(persisted, seeds)
        if (upserts.isNotEmpty()) {
            wirdDao.upsertAll(upserts.map { it.toEntity() })
        }
    }

    override suspend fun bundledLibrarySlugs(): Set<String> =
        loadAssetWirds().map { it.slug }.toSet()

    private fun loadAssetWirds(): List<Wird> {
        val files = runCatching { context.assets.list(ASSET_DIR) }.getOrNull().orEmpty()
        return files.filter { it.endsWith(".json") }.mapNotNull { name ->
            runCatching {
                val text = context.assets.open("$ASSET_DIR/$name").bufferedReader().use { it.readText() }
                WirdAssetParser.parse(text)
            }.getOrNull()
        }
    }

    override fun observeWirds(): Flow<List<Wird>> =
        wirdDao.observeAll().map { list -> list.map { it.toDomain() } }

    override suspend fun getWird(id: String): Wird? = wirdDao.getById(id)?.toDomain()

    override fun observeWird(id: String): Flow<Wird?> =
        wirdDao.observeById(id).map { it?.toDomain() }

    override suspend fun getSession(wird: Wird, part: WirdPart, dateKey: String): WirdSession? {
        val occasionKey = wird.occasionFor(part).key
        return sessionDao.getByTuple(wird.id, part.id, occasionKey, dateKey)?.toDomain()
    }

    override fun observeSessionsForDate(wirdId: String, dateKey: String): Flow<List<WirdSession>> =
        sessionDao.observeForWirdOnDate(wirdId, dateKey).map { list -> list.map { it.toDomain() } }

    override fun observeAllSessions(wirdId: String): Flow<List<WirdSession>> =
        sessionDao.observeAllForWird(wirdId).map { list -> list.map { it.toDomain() } }

    override fun observeSessionsOnDate(dateKey: String): Flow<List<WirdSession>> =
        sessionDao.observeAllForDate(dateKey).map { list -> list.map { it.toDomain() } }

    override fun observeSession(wird: Wird, part: WirdPart, dateKey: String): Flow<WirdSession?> {
        val occasionKey = wird.occasionFor(part).key
        return sessionDao.observeByTuple(wird.id, part.id, occasionKey, dateKey).map { it?.toDomain() }
    }

    override suspend fun incrementSegment(
        wird: Wird,
        part: WirdPart,
        segment: WirdSegment,
        dateKey: String,
    ): Int {
        val occasionKey = wird.occasionFor(part).key
        val existing = sessionDao.getByTuple(wird.id, part.id, occasionKey, dateKey)?.toDomain()
        val result = engine.incrementSegment(
            part = part,
            segment = segment,
            existing = existing,
            wirdID = wird.id,
            occasionKey = occasionKey,
            dateKey = dateKey,
            nowMillis = System.currentTimeMillis(),
        )
        sessionDao.upsert(result.session.toEntity())
        return result.newCount
    }

    override suspend fun updateReadingPosition(
        wird: Wird,
        part: WirdPart,
        segmentId: String,
        dateKey: String,
    ) {
        val occasionKey = wird.occasionFor(part).key
        val existing = sessionDao.getByTuple(wird.id, part.id, occasionKey, dateKey)?.toDomain()
        if (existing?.lastSegmentID == segmentId) return // no-op if unchanged
        val session = existing?.copy(lastSegmentID = segmentId) ?: WirdSession(
            wirdID = wird.id,
            partID = part.id,
            occasionKey = occasionKey,
            dateKey = dateKey,
            lastSegmentID = segmentId,
            startedAt = System.currentTimeMillis(),
        )
        sessionDao.upsert(session.toEntity())
    }

    override suspend fun resetSession(wird: Wird, part: WirdPart, dateKey: String) {
        val occasionKey = wird.occasionFor(part).key
        sessionDao.deleteByTuple(wird.id, part.id, occasionKey, dateKey)
    }

    override suspend fun streak(wird: Wird, today: String): Int {
        val sessions = sessionDao.getAllForWird(wird.id).map { it.toDomain() }
        val date = WirdEngine.parseDateKeyOrNull(today) ?: LocalDate.now()
        return engine.streak(wird, sessions, date)
    }

    override suspend fun weekActivity(wird: Wird, today: String): List<WirdEngine.DayActivity> {
        val sessions = sessionDao.getAllForWird(wird.id).map { it.toDomain() }
        val date = WirdEngine.parseDateKeyOrNull(today) ?: LocalDate.now()
        return engine.recentWeek(wird, sessions, date)
    }

    override suspend fun createWird(wird: Wird): Wird {
        val slug = wird.slug.ifBlank { "custom-${wird.id.take(8)}" }
        val sortOrder = if (wird.sortOrder == 0) wirdDao.maxSortOrder() + 1 else wird.sortOrder
        val toSave = wird.copy(isCustom = true, slug = slug, sortOrder = sortOrder)
        wirdDao.upsert(toSave.toEntity())
        return toSave
    }

    override suspend fun updateWird(wird: Wird) {
        val existing = wirdDao.getById(wird.id) ?: return
        if (!existing.isCustom) return // only custom wirds are editable
        // preserve version
        wirdDao.upsert(wird.copy(isCustom = true, version = existing.version).toEntity())
    }

    override suspend fun setReminders(wird: Wird, reminders: List<WirdReminder>): Wird {
        val base = wirdDao.getById(wird.id)?.toDomain() ?: wird
        val updated = base.copy(isCustom = true, reminders = reminders)
        wirdDao.upsert(updated.toEntity())
        return updated
    }

    override suspend fun deleteWird(wird: Wird) {
        // Only deletes custom wirds; also removes their sessions. (Reminders handled in Phase 4.)
        sessionDao.deleteAllForWird(wird.id)
        wirdDao.deleteCustom(wird.id)
    }

    companion object {
        private const val ASSET_DIR = "wird_library"

        fun newCustomWirdId(): String = UUID.randomUUID().toString()
    }
}
