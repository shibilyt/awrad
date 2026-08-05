package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase
import app.awrad.awrad_dhikrgoalstracker.data.database.BuiltInDhikrs
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrAudioAssetDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrTagAssignmentDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.UserTagDao
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrAudioAssetEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrTagAssignmentEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.UserTagEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrAudioAsset
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.QuranRef
import app.awrad.awrad_dhikrgoalstracker.data.model.UserTag
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import app.awrad.awrad_dhikrgoalstracker.data.sync.ProgressSyncRepository
import app.awrad.awrad_dhikrgoalstracker.data.sync.UserTagCoalesceRepoint
import app.awrad.awrad_dhikrgoalstracker.domain.UserTagNormalizer
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationRequestDispatcher
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationRequestReason
import app.awrad.awrad_dhikrgoalstracker.service.AudioDownloadManager
import app.awrad.awrad_dhikrgoalstracker.service.CustomDhikrAudioStore
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
import app.awrad.awrad_dhikrgoalstracker.service.OwnedAudioAvailability
import app.awrad.awrad_dhikrgoalstracker.service.OwnedAudioFile
import app.awrad.awrad_dhikrgoalstracker.service.StagedOwnedAudio
import androidx.room.withTransaction
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DhikrRepositoryImpl @Inject constructor(
    private val dhikrDao: DhikrDao,
    private val audioDownloadManager: AudioDownloadManager,
    private val database: AwradDatabase? = null,
    private val progressSyncRepository: ProgressSyncRepository? = null,
    private val userTagDao: UserTagDao? = null,
    private val assignmentDao: DhikrTagAssignmentDao? = null,
    private val audioAssetDao: DhikrAudioAssetDao? = null,
    private val goalDao: GoalDao? = null,
    private val ownedAudioStore: CustomDhikrAudioStore? = null,
    private val notificationRequests: NotificationObligationRequestDispatcher? = null,
) : DhikrRepository {

    override fun getAllDhikrs(): Flow<List<Dhikr>> =
        dhikrDao.getAllDhikrs().map { entities -> entities.map { it.toDomain() } }

    override fun getCustomDhikrs(): Flow<List<Dhikr>> =
        dhikrDao.getCustomDhikrs().map { entities -> entities.map { it.toDomain() } }

    override fun getDhikrsByCategory(category: DhikrCategory): Flow<List<Dhikr>> =
        dhikrDao.getDhikrsByCategory(category.name).map { entities -> entities.map { it.toDomain() } }

    override fun searchDhikrs(query: String): Flow<List<Dhikr>> =
        dhikrDao.searchDhikrs(query).map { entities -> entities.map { it.toDomain() } }

    override suspend fun getDhikrById(id: AwradId): Dhikr? =
        dhikrDao.getDhikrById(id)?.toDomain()

    override suspend fun initializeBuiltInDhikrs() {
        if (dhikrDao.getCount() == 0) {
            dhikrDao.insertAll(BuiltInDhikrs.dhikrs)
        } else {
            syncBuiltInDhikrs()
        }
    }

    private suspend fun syncBuiltInDhikrs() {
        for (builtIn in BuiltInDhikrs.dhikrs) {
            val catalogKey = requireNotNull(builtIn.catalogKey)
            val existing = dhikrDao.getDhikrByCatalogKey(catalogKey)
            if (existing == null) {
                dhikrDao.insertAll(listOf(builtIn))
            } else {
                check(existing.id == builtIn.id) {
                    "Built-in dhikr identity mismatch for $catalogKey: ${existing.id} != ${builtIn.id}"
                }
            }
            dhikrDao.updateBuiltInContent(
                catalogKey = catalogKey,
                title = builtIn.title,
                arabic = builtIn.arabic,
                transliteration = builtIn.transliteration,
                translation = builtIn.translation,
                category = builtIn.category.name,
                sortOrder = builtIn.sortOrder,
            )
            builtIn.audioUrl?.let { dhikrDao.updateAudioUrl(catalogKey, it) }
            if (builtIn.audioCountPerPlay != 1) {
                dhikrDao.updateAudioCountPerPlay(catalogKey, builtIn.audioCountPerPlay)
            }
            if (builtIn.title.isNotEmpty()) {
                dhikrDao.updateTitle(catalogKey, builtIn.title)
            }
            val surah = builtIn.quranSurah
            val ayahStart = builtIn.quranAyahStart
            if (surah != null && ayahStart != null) {
                dhikrDao.updateQuranContent(
                    catalogKey = catalogKey,
                    arabic = builtIn.arabic,
                    surah = surah,
                    ayahStart = ayahStart,
                    ayahEnd = builtIn.quranAyahEnd,
                )
            }
        }
    }

    override suspend fun getDownloadableDhikrs(): List<Dhikr> =
        dhikrDao.getDhikrsWithAudioUrl()
            .filter { !it.isDownloaded }
            .map { it.toDomain() }

    override suspend fun markAsDownloaded(dhikrId: AwradId, audioFileName: String) {
        dhikrDao.updateAudioDownloadStatus(dhikrId, audioFileName, isDownloaded = true)
    }

    override suspend fun downloadDhikrAudio(dhikr: Dhikr): Boolean {
        val url = dhikr.audioUrl ?: return false
        val fileName = dhikr.audioFileName
            ?: url.substringAfterLast("/").takeIf { it.isNotBlank() }
            ?: return false
        val success = audioDownloadManager.downloadSingle(url, fileName)
        if (success) {
            markAsDownloaded(dhikr.id, fileName)
        }
        return success
    }

    override suspend fun downloadSelectedAudio(dhikrs: List<Dhikr>): Boolean {
        val filesToDownload = dhikrs.mapNotNull { dhikr ->
            val url = dhikr.audioUrl ?: return@mapNotNull null
            val fileName = dhikr.audioFileName
                ?: url.substringAfterLast("/").takeIf { it.isNotBlank() }
                ?: return@mapNotNull null
            Triple(dhikr.id, url, fileName)
        }
        if (filesToDownload.isEmpty()) return true
        val urlFilenamePairs = filesToDownload.map { (_, url, fileName) -> url to fileName }
        val dhikrIdsByFileName = filesToDownload.groupBy(
            keySelector = { (_, _, fileName) -> fileName },
            valueTransform = { (dhikrId, _, _) -> dhikrId },
        )
        val successfulFiles = audioDownloadManager.downloadAll(urlFilenamePairs) { fileName ->
            dhikrIdsByFileName[fileName].orEmpty().forEach { dhikrId ->
                markAsDownloaded(dhikrId, fileName)
            }
        }
        return successfulFiles.size == filesToDownload.size
    }

    override suspend fun downloadAllAudio(): Boolean {
        val downloadable = dhikrDao.getDhikrsWithAudioUrl().filter { !it.isDownloaded }
        if (downloadable.isEmpty()) return true

        val filesToDownload = downloadable.mapNotNull { dhikr ->
            val url = dhikr.audioUrl ?: return@mapNotNull null
            val fileName = dhikr.audioFileName
                ?: url.substringAfterLast("/").takeIf { it.isNotBlank() }
                ?: return@mapNotNull null
            Triple(dhikr.id, url, fileName)
        }

        val urlFilenamePairs = filesToDownload.map { (_, url, fileName) -> url to fileName }
        val dhikrIdsByFileName = filesToDownload.groupBy(
            keySelector = { (_, _, fileName) -> fileName },
            valueTransform = { (dhikrId, _, _) -> dhikrId },
        )
        val successfulFiles = audioDownloadManager.downloadAll(urlFilenamePairs) { fileName ->
            dhikrIdsByFileName[fileName].orEmpty().forEach { dhikrId ->
                markAsDownloaded(dhikrId, fileName)
            }
        }

        return successfulFiles.size == filesToDownload.size
    }

    override fun getLibraryDownloadProgress(): StateFlow<DownloadProgress> =
        audioDownloadManager.downloadProgress

    override suspend fun createDhikr(dhikr: Dhikr): AwradId {
        val custom = dhikr.copy(isCustom = true, catalogKey = null)
        require(CustomDhikrMutationPolicy.canPersistCustom(custom))
        val entity = custom.toEntity()
        val persist: suspend () -> Unit = {
            dhikrDao.insert(entity)
            progressSyncRepository?.enqueueDhikr(custom.copy(id = entity.id))
        }
        database?.withTransaction { persist() } ?: persist()
        return entity.id
    }

    override suspend fun updateCustomDhikr(dhikr: Dhikr): Boolean {
        val existing = dhikrDao.getDhikrById(dhikr.id) ?: return false
        if (!CustomDhikrMutationPolicy.canMutateExisting(existing.isCustom)) return false
        val updated = dhikr.copy(isCustom = true, catalogKey = null)
        val persist: suspend () -> Unit = {
            val changed = dhikrDao.updateCustomContent(
                id = updated.id,
                title = updated.title,
                arabic = updated.arabic,
                transliteration = updated.transliteration,
                translation = updated.translation,
                category = updated.category.name,
                audioCountPerPlay = updated.audioCountPerPlay,
            )
            check(changed == 1)
            progressSyncRepository?.enqueueDhikr(updated)
        }
        database?.withTransaction { persist() } ?: persist()
        val goals = goalDao?.getGoalsByDhikrId(updated.id).orEmpty()
        if (goals.isNotEmpty()) {
            notificationRequests?.request(
                NotificationObligationRequestReason.GOAL_MUTATION,
                goals.map { it.id }.toSet(),
            )
        }
        return true
    }

    override suspend fun deleteCustomDhikr(id: AwradId): Boolean {
        val existing = dhikrDao.getDhikrById(id) ?: return false
        if (!CustomDhikrMutationPolicy.canMutateExisting(existing.isCustom)) return false
        val goals = goalDao?.getGoalsByDhikrId(id).orEmpty()
        val owned = audioAssetDao?.getForDhikr(id)
        // Server cascades assignment tombstones on custom_dhikr delete; enqueue local
        // assignment deletes first so outbox ordering stays coherent for capable peers.
        val assignments = assignmentDao?.getForDhikr(id).orEmpty()
        val plan = CustomDhikrDeletionCascade.plan(
            dhikrId = id,
            goalIds = goals.map { it.id },
            assignmentIds = assignments.map { it.id },
            ownedAudioRelativeFileName = owned?.relativeFileName,
        )
        val persist: suspend () -> Unit = {
            plan.assignmentIdsToDelete.forEach {
                progressSyncRepository?.enqueueDelete("dhikr_tag_assignment", it.toString())
            }
            plan.goalIdsToDelete.forEach { goalId ->
                progressSyncRepository?.enqueueDelete("goal", goalId.toString())
            }
            progressSyncRepository?.enqueueDelete("custom_dhikr", plan.dhikrIdToDelete.toString())
            // Explicit child rows before parent — do not rely on FK CASCADE at runtime.
            assignmentDao?.deleteForDhikr(id)
            plan.goalIdsToDelete.forEach { goalId -> goalDao?.deleteById(goalId) }
            audioAssetDao?.deleteForDhikr(id)
            val deleted = dhikrDao.deleteCustomById(plan.dhikrIdToDelete)
            check(deleted == 1)
        }
        database?.withTransaction { persist() } ?: persist()
        if (plan.goalIdsToDelete.isNotEmpty()) {
            notificationRequests?.request(
                NotificationObligationRequestReason.GOAL_MUTATION,
                plan.goalIdsToDelete.toSet(),
            )
        }
        plan.ownedAudioRelativeFileName?.let { ownedAudioStore?.deleteOwned(it) }
        return true
    }

    override fun observeUserTags(): Flow<List<UserTag>> =
        requireUserTagDao().observeAll().map { rows -> rows.map { it.toDomain() } }

    override suspend fun createUserTag(rawName: String): UserTag? {
        val normalized = UserTagNormalizer.normalize(rawName) ?: return null
        val dao = requireUserTagDao()
        if (!CustomDhikrMutationPolicy.canCreateTag(dao.count())) return null
        dao.getByNormalizedName(normalized.normalizedName)?.let { return it.toDomain() }
        val tag = UserTag(
            name = normalized.displayName,
            normalizedName = normalized.normalizedName,
        )
        val persist: suspend () -> Unit = {
            dao.insert(tag.toEntity())
            progressSyncRepository?.enqueueUserTag(tag)
        }
        database?.withTransaction { persist() } ?: persist()
        return tag
    }

    override suspend fun renameUserTag(id: AwradId, rawName: String): UserTag? {
        val normalized = UserTagNormalizer.normalize(rawName) ?: return null
        val dao = requireUserTagDao()
        val existing = dao.getById(id) ?: return null
        val collision = dao.getByNormalizedName(normalized.normalizedName)
        if (collision != null && collision.id != id) return null
        val updated = existing.copy(
            name = normalized.displayName,
            normalizedName = normalized.normalizedName,
            updatedAt = System.currentTimeMillis(),
        )
        val persist: suspend () -> Unit = {
            dao.update(updated)
            progressSyncRepository?.enqueueUserTag(updated.toDomain())
        }
        database?.withTransaction { persist() } ?: persist()
        return updated.toDomain()
    }

    override suspend fun deleteUserTag(id: AwradId): Boolean {
        val dao = requireUserTagDao()
        if (dao.getById(id) == null) return false
        val assignments = requireAssignmentDao().getForTag(id)
        val persist: suspend () -> Unit = {
            assignments.forEach { progressSyncRepository?.enqueueDelete("dhikr_tag_assignment", it.id.toString()) }
            progressSyncRepository?.enqueueDelete("user_tag", id.toString())
            dao.deleteById(id)
        }
        database?.withTransaction { persist() } ?: persist()
        return true
    }

    override suspend fun setDhikrTags(dhikrId: AwradId, tagIds: Set<AwradId>) {
        require(dhikrDao.getDhikrById(dhikrId) != null)
        require(tagIds.size <= CustomDhikrMutationPolicy.MAX_TAGS_PER_DHIKR)
        val assignmentDao = requireAssignmentDao()
        val current = assignmentDao.getForDhikr(dhikrId)
        val currentIds = current.map { it.tagId }.toSet()
        val toRemove = current.filter { it.tagId !in tagIds }
        val toAdd = tagIds - currentIds
        val persist: suspend () -> Unit = {
            toRemove.forEach {
                progressSyncRepository?.enqueueDelete("dhikr_tag_assignment", it.id.toString())
                assignmentDao.deleteById(it.id)
            }
            toAdd.forEach { tagId ->
                val assignment = DhikrTagAssignmentEntity(
                    tagId = tagId,
                    dhikrId = dhikrId,
                    createdAt = System.currentTimeMillis(),
                )
                assignmentDao.insert(assignment)
                progressSyncRepository?.enqueueTagAssignment(
                    id = assignment.id,
                    tagId = tagId,
                    dhikrId = dhikrId,
                    createdAt = assignment.createdAt,
                )
            }
        }
        database?.withTransaction { persist() } ?: persist()
    }

    override fun observeTagIdsForDhikr(dhikrId: AwradId): Flow<Set<AwradId>> =
        requireAssignmentDao().observeForDhikr(dhikrId).map { rows -> rows.map { it.tagId }.toSet() }

    override fun observeAssignments(): Flow<Map<AwradId, Set<AwradId>>> =
        requireAssignmentDao().observeAll().map { rows ->
            rows.groupBy({ it.dhikrId }, { it.tagId }).mapValues { it.value.toSet() }
        }

    override suspend fun getOwnedAudio(dhikrId: AwradId): DhikrAudioAsset? =
        audioAssetDao?.getForDhikr(dhikrId)?.toDomain()

    override fun observeOwnedAudio(dhikrId: AwradId): Flow<DhikrAudioAsset?> =
        requireAudioAssetDao().observeForDhikr(dhikrId).map { it?.toDomain() }

    override fun observeOwnedAudioByDhikrId(): Flow<Map<AwradId, DhikrAudioAsset>> =
        requireAudioAssetDao().observeAll().map { rows ->
            rows.associate { it.dhikrId to it.toDomain() }
        }

    override suspend fun attachOwnedAudio(dhikrId: AwradId, staged: StagedOwnedAudio): DhikrAudioAsset {
        val dhikr = dhikrDao.getDhikrById(dhikrId)
            ?: error("Dhikr not found for owned audio attach")
        OwnedAudioAttachRollbackPolicy.requireCustomDhikr(dhikr.isCustom)
        val existing = requireAudioAssetDao().getForDhikr(dhikrId)
        val store = requireOwnedAudioStore()
        val previousOwned = existing?.let {
            OwnedAudioFile(
                relativeFileName = it.relativeFileName,
                absoluteFile = store.ownedFile(it.relativeFileName),
                mimeType = it.mimeType,
                byteSize = it.byteSize,
                durationMs = it.durationMs,
                sha256 = it.sha256,
            )
        }
        val promoted = store.commitStaged(staged)
        return try {
            val asset = DhikrAudioAsset(
                id = existing?.id ?: newAwradId(),
                dhikrId = dhikrId,
                relativeFileName = promoted.relativeFileName,
                mimeType = promoted.mimeType,
                byteSize = promoted.byteSize,
                durationMs = promoted.durationMs,
                sha256 = promoted.sha256,
            )
            val persist: suspend () -> Unit = {
                requireAudioAssetDao().upsert(asset.toEntity())
            }
            database?.withTransaction { persist() } ?: persist()
            OwnedAudioAttachRollbackPolicy.onDaoSuccess(store, previousOwned, promoted)
            asset
        } catch (error: Exception) {
            OwnedAudioAttachRollbackPolicy.onDaoFailure(store, previousOwned, promoted)
            store.discardStaged(staged)
            throw error
        }
    }

    override suspend fun removeOwnedAudio(dhikrId: AwradId) {
        val existing = requireAudioAssetDao().getForDhikr(dhikrId) ?: return
        requireAudioAssetDao().deleteForDhikr(dhikrId)
        requireOwnedAudioStore().deleteOwned(existing.relativeFileName)
    }

    override suspend fun ownedAudioAvailability(dhikrId: AwradId): OwnedAudioAvailability {
        val relative = audioAssetDao?.getForDhikr(dhikrId)?.relativeFileName
            ?: return OwnedAudioAvailability.MISSING
        return requireOwnedAudioStore().resolveAvailability(relative)
    }

    override suspend fun cleanupOwnedAudioOrphans() {
        val referenced = audioAssetDao?.getAllRelativeFileNames()?.toSet().orEmpty()
        ownedAudioStore?.cleanupOrphans(
            referencedRelativeNames = referenced,
            ownedGraceMs = OWNED_ORPHAN_GRACE_MS,
            tempGraceMs = TEMP_ORPHAN_GRACE_MS,
            nowMs = System.currentTimeMillis(),
        )
    }

    suspend fun applyRemoteDhikr(dhikr: Dhikr) = requireNotNull(database).withTransaction {
        val existing = dhikrDao.getDhikrById(dhikr.id)
        val entity = dhikr.toEntity().copy(
            isDownloaded = existing?.isDownloaded ?: false,
            audioFileName = existing?.audioFileName ?: dhikr.audioFileName,
        )
        if (existing == null) dhikrDao.insert(entity) else dhikrDao.update(entity)
    }

    suspend fun deleteRemoteDhikr(id: AwradId) {
        val db = requireNotNull(database)
        val goals = goalDao?.getGoalsByDhikrId(id).orEmpty()
        val assignments = assignmentDao?.getForDhikr(id).orEmpty()
        val owned = audioAssetDao?.getForDhikr(id)
        val plan = CustomDhikrDeletionCascade.plan(
            dhikrId = id,
            goalIds = goals.map { it.id },
            assignmentIds = assignments.map { it.id },
            ownedAudioRelativeFileName = owned?.relativeFileName,
        )
        db.withTransaction {
            // Explicit child rows before parent — do not rely on FK CASCADE at runtime.
            assignmentDao?.deleteForDhikr(id)
            plan.goalIdsToDelete.forEach { goalId -> goalDao?.deleteById(goalId) }
            audioAssetDao?.deleteForDhikr(id)
            dhikrDao.deleteCustomById(plan.dhikrIdToDelete)
        }
        plan.ownedAudioRelativeFileName?.let { ownedAudioStore?.deleteOwned(it) }
    }

    suspend fun applyRemoteUserTag(tag: UserTag) = requireNotNull(database).withTransaction {
        val dao = requireUserTagDao()
        val duplicate = dao.getByNormalizedName(tag.normalizedName)
        if (duplicate != null && duplicate.id != tag.id) {
            coalesceUserTagInTransaction(localTagId = duplicate.id, canonical = tag)
        } else {
            dao.upsert(tag.toEntity())
        }
    }

    suspend fun deleteRemoteUserTag(id: AwradId) = requireNotNull(database).withTransaction {
        requireUserTagDao().deleteById(id)
    }

    suspend fun applyRemoteTagAssignment(
        id: AwradId,
        tagId: AwradId,
        dhikrId: AwradId,
        createdAt: Long,
    ) = requireNotNull(database).withTransaction {
        requireAssignmentDao().upsert(
            DhikrTagAssignmentEntity(
                id = id,
                tagId = tagId,
                dhikrId = dhikrId,
                createdAt = createdAt,
            ),
        )
    }

    suspend fun deleteRemoteTagAssignment(id: AwradId) = requireNotNull(database).withTransaction {
        requireAssignmentDao().deleteById(id)
    }

    /**
     * Consumes a coalesced user_tag receipt: install canonical tag, rewrite local assignments
     * and drop the rejected local tag id.
     */
    suspend fun coalesceUserTag(localTagId: AwradId, canonical: UserTag) =
        requireNotNull(database).withTransaction {
            coalesceUserTagInTransaction(localTagId = localTagId, canonical = canonical)
        }

    private suspend fun coalesceUserTagInTransaction(localTagId: AwradId, canonical: UserTag) {
        requireUserTagDao().upsert(canonical.toEntity())
        val assignmentDao = requireAssignmentDao()
        val losing = assignmentDao.getForTag(localTagId)
        val existingCanonicalDhikrIds = assignmentDao.getForTag(canonical.id).map { it.dhikrId }.toSet()
        val plan = UserTagCoalesceRepoint.plan(
            losingAssignments = losing.map {
                UserTagCoalesceRepoint.Assignment(id = it.id, tagId = it.tagId, dhikrId = it.dhikrId)
            },
            existingCanonicalDhikrIds = existingCanonicalDhikrIds,
            fromTagId = localTagId,
            toTagId = canonical.id,
        )
        plan.assignmentIdsToDelete.forEach { assignmentDao.deleteById(it) }
        val createdAtById = losing.associate { it.id to it.createdAt }
        plan.assignmentsToRepoint.forEach { assignment ->
            assignmentDao.upsert(
                DhikrTagAssignmentEntity(
                    id = assignment.id,
                    tagId = assignment.tagId,
                    dhikrId = assignment.dhikrId,
                    createdAt = createdAtById[assignment.id] ?: System.currentTimeMillis(),
                ),
            )
        }
        // Any remaining losing rows (should be none) then drop the duplicate tag.
        assignmentDao.deleteForTag(localTagId)
        if (localTagId != canonical.id) {
            requireUserTagDao().deleteById(localTagId)
        }
    }

    private fun requireUserTagDao(): UserTagDao = requireNotNull(userTagDao)
    private fun requireAssignmentDao(): DhikrTagAssignmentDao = requireNotNull(assignmentDao)
    private fun requireAudioAssetDao(): DhikrAudioAssetDao = requireNotNull(audioAssetDao)
    private fun requireOwnedAudioStore(): CustomDhikrAudioStore = requireNotNull(ownedAudioStore)

    private fun Dhikr.toEntity() = DhikrEntity(
        id = id,
        catalogKey = catalogKey,
        title = title,
        arabic = arabic,
        transliteration = transliteration,
        translation = translation,
        audioUrl = audioUrl,
        audioFileName = audioFileName,
        category = category,
        isDownloaded = isDownloaded,
        isCustom = isCustom,
        audioCountPerPlay = audioCountPerPlay,
        sortOrder = sortOrder,
        quranSurah = quranRef?.surah,
        quranAyahStart = quranRef?.ayahStart,
        quranAyahEnd = quranRef?.ayahEnd,
        benefitsJson = Json.encodeToString(benefits),
    )

    private fun DhikrEntity.toDomain() = Dhikr(
        id = id,
        catalogKey = catalogKey,
        title = title,
        arabic = arabic,
        transliteration = transliteration,
        translation = translation,
        audioUrl = audioUrl,
        audioFileName = audioFileName,
        category = category,
        isDownloaded = isDownloaded,
        isCustom = isCustom,
        audioCountPerPlay = audioCountPerPlay,
        sortOrder = sortOrder,
        quranRef = if (quranSurah != null && quranAyahStart != null) {
            QuranRef(quranSurah, quranAyahStart, quranAyahEnd).takeIf { it.isValid }
        } else {
            null
        },
        benefits = runCatching { Json.decodeFromString<List<String>>(benefitsJson) }.getOrDefault(emptyList()),
    )

    private fun UserTagEntity.toDomain() = UserTag(
        id = id,
        name = name,
        normalizedName = normalizedName,
        createdAt = createdAt,
        updatedAt = updatedAt,
    )

    private fun UserTag.toEntity() = UserTagEntity(
        id = id,
        name = name,
        normalizedName = normalizedName,
        createdAt = createdAt,
        updatedAt = updatedAt,
    )

    private fun DhikrAudioAssetEntity.toDomain() = DhikrAudioAsset(
        id = id,
        dhikrId = dhikrId,
        relativeFileName = relativeFileName,
        mimeType = mimeType,
        byteSize = byteSize,
        durationMs = durationMs,
        sha256 = sha256,
        source = source,
        createdAt = createdAt,
    )

    private fun DhikrAudioAsset.toEntity() = DhikrAudioAssetEntity(
        id = id,
        dhikrId = dhikrId,
        relativeFileName = relativeFileName,
        mimeType = mimeType,
        byteSize = byteSize,
        durationMs = durationMs,
        sha256 = sha256,
        source = source,
        createdAt = createdAt,
    )

    companion object {
        const val OWNED_ORPHAN_GRACE_MS = 15 * 60 * 1000L
        const val TEMP_ORPHAN_GRACE_MS = 15 * 60 * 1000L
    }
}
