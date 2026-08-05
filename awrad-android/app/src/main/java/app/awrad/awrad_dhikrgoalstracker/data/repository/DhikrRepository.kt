package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrAudioAsset
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.UserTag
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
import app.awrad.awrad_dhikrgoalstracker.service.OwnedAudioAvailability
import app.awrad.awrad_dhikrgoalstracker.service.StagedOwnedAudio
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow

interface DhikrRepository {
    fun getAllDhikrs(): Flow<List<Dhikr>>
    fun getCustomDhikrs(): Flow<List<Dhikr>>
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
    suspend fun updateCustomDhikr(dhikr: Dhikr): Boolean
    /** Deletes a custom dhikr and linked goals/counts/assignments/audio; cancels goal notifications. */
    suspend fun deleteCustomDhikr(id: AwradId): Boolean

    fun observeUserTags(): Flow<List<UserTag>>
    suspend fun createUserTag(rawName: String): UserTag?
    suspend fun renameUserTag(id: AwradId, rawName: String): UserTag?
    suspend fun deleteUserTag(id: AwradId): Boolean
    suspend fun setDhikrTags(dhikrId: AwradId, tagIds: Set<AwradId>)
    fun observeTagIdsForDhikr(dhikrId: AwradId): Flow<Set<AwradId>>
    fun observeAssignments(): Flow<Map<AwradId, Set<AwradId>>>

    suspend fun getOwnedAudio(dhikrId: AwradId): DhikrAudioAsset?
    fun observeOwnedAudio(dhikrId: AwradId): Flow<DhikrAudioAsset?>
    fun observeOwnedAudioByDhikrId(): Flow<Map<AwradId, DhikrAudioAsset>>
    suspend fun attachOwnedAudio(dhikrId: AwradId, staged: StagedOwnedAudio): DhikrAudioAsset
    suspend fun removeOwnedAudio(dhikrId: AwradId)
    suspend fun ownedAudioAvailability(dhikrId: AwradId): OwnedAudioAvailability
    suspend fun cleanupOwnedAudioOrphans()
}
