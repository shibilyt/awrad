package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.database.BuiltInDhikrs
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrDao
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.QuranRef
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.service.AudioDownloadManager
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
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
) : DhikrRepository {

    override fun getAllDhikrs(): Flow<List<Dhikr>> =
        dhikrDao.getAllDhikrs().map { entities -> entities.map { it.toDomain() } }

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
        val entity = DhikrEntity(
            id = dhikr.id,
            catalogKey = dhikr.catalogKey,
            title = dhikr.title,
            arabic = dhikr.arabic,
            transliteration = dhikr.transliteration,
            translation = dhikr.translation,
            audioUrl = dhikr.audioUrl,
            audioFileName = dhikr.audioFileName,
            category = dhikr.category,
            isDownloaded = dhikr.isDownloaded,
            isCustom = dhikr.isCustom,
            audioCountPerPlay = dhikr.audioCountPerPlay,
            sortOrder = dhikr.sortOrder,
            quranSurah = dhikr.quranRef?.surah,
            quranAyahStart = dhikr.quranRef?.ayahStart,
            quranAyahEnd = dhikr.quranRef?.ayahEnd,
            benefitsJson = Json.encodeToString(dhikr.benefits),
        )
        dhikrDao.insert(entity)
        return entity.id
    }

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
}
