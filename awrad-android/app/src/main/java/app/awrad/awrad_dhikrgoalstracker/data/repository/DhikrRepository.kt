package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow

interface DhikrRepository {
    fun getAllDhikrs(): Flow<List<Dhikr>>
    fun getDhikrsByCategory(category: DhikrCategory): Flow<List<Dhikr>>
    fun searchDhikrs(query: String): Flow<List<Dhikr>>
    suspend fun getDhikrById(id: AwradId): Dhikr?
    suspend fun initializeBuiltInDhikrs()
    suspend fun getDownloadableDhikrs(): List<Dhikr>
    suspend fun markAsDownloaded(dhikrId: AwradId, audioFileName: String)
    suspend fun downloadAllAudio(): Boolean
    suspend fun downloadSelectedAudio(dhikrs: List<Dhikr>): Boolean
    suspend fun downloadDhikrAudio(dhikr: Dhikr): Boolean
    fun getLibraryDownloadProgress(): StateFlow<DownloadProgress>
    suspend fun createDhikr(dhikr: Dhikr): AwradId
}
