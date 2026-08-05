package app.awrad.awrad_dhikrgoalstracker.ui.screens.managetags

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrAudioAsset
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.UserTag
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
import app.awrad.awrad_dhikrgoalstracker.service.OwnedAudioAvailability
import app.awrad.awrad_dhikrgoalstracker.service.StagedOwnedAudio
import androidx.lifecycle.SavedStateHandle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ManageTagsViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private val dhikrId = newAwradId()

    @Before
    fun setUp() = Dispatchers.setMain(dispatcher)

    @After
    fun tearDown() = Dispatchers.resetMain()

    @Test
    fun createAssignRemoveRenameAndDeleteTags() = runTest(dispatcher) {
        val repository = FakeTagRepository(dhikrId)
        val viewModel = ManageTagsViewModel(
            dhikrRepository = repository,
            savedStateHandle = SavedStateHandle(mapOf("dhikrId" to dhikrId.toString())),
        )
        advanceUntilIdle()

        viewModel.onNewTagNameChanged("  Sleep  ")
        viewModel.createTag()
        advanceUntilIdle()
        assertEquals(1, repository.tags.value.size)
        assertTrue(viewModel.uiState.value.assignedTagIds.contains(repository.tags.value.first().id))

        val tagId = repository.tags.value.first().id
        viewModel.toggleAssignment(tagId)
        advanceUntilIdle()
        assertFalse(viewModel.uiState.value.assignedTagIds.contains(tagId))

        viewModel.toggleAssignment(tagId)
        advanceUntilIdle()
        assertTrue(viewModel.uiState.value.assignedTagIds.contains(tagId))

        viewModel.beginRename(tagId)
        viewModel.onRenameTextChanged("Before sleep")
        viewModel.commitRename()
        advanceUntilIdle()
        assertEquals("Before sleep", repository.tags.value.first().name)

        viewModel.deleteTag(tagId)
        advanceUntilIdle()
        assertTrue(repository.tags.value.isEmpty())
        assertTrue(viewModel.uiState.value.assignedTagIds.isEmpty())
    }

    @Test
    fun worksForBuiltInDhikrWithoutRequiringCustom() = runTest(dispatcher) {
        val builtInId = newAwradId()
        val repository = FakeTagRepository(builtInId, isCustom = false)
        val viewModel = ManageTagsViewModel(
            dhikrRepository = repository,
            savedStateHandle = SavedStateHandle(mapOf("dhikrId" to builtInId.toString())),
        )
        advanceUntilIdle()
        assertFalse(viewModel.uiState.value.dhikrIsCustom)
        viewModel.onNewTagNameChanged("Travel")
        viewModel.createTag()
        advanceUntilIdle()
        assertEquals(1, viewModel.uiState.value.assignedTagIds.size)
    }

    private class FakeTagRepository(
        private val targetDhikrId: AwradId,
        private val isCustom: Boolean = true,
    ) : DhikrRepository {
        val tags = MutableStateFlow<List<UserTag>>(emptyList())
        private val assignments = MutableStateFlow<Map<AwradId, Set<AwradId>>>(emptyMap())
        private val progress = MutableStateFlow(DownloadProgress())

        override fun getAllDhikrs(): Flow<List<Dhikr>> = flowOf(emptyList())
        override fun getCustomDhikrs(): Flow<List<Dhikr>> = flowOf(emptyList())
        override fun getDhikrsByCategory(category: DhikrCategory): Flow<List<Dhikr>> = flowOf(emptyList())
        override fun searchDhikrs(query: String): Flow<List<Dhikr>> = flowOf(emptyList())
        override suspend fun getDhikrById(id: AwradId): Dhikr? = Dhikr(
            id = targetDhikrId,
            title = "Dhikr",
            arabic = "ن",
            transliteration = "n",
            translation = "n",
            audioUrl = null,
            audioFileName = null,
            category = DhikrCategory.GENERAL,
            isCustom = isCustom,
        ).takeIf { id == targetDhikrId }

        override suspend fun initializeBuiltInDhikrs() = Unit
        override suspend fun getDownloadableDhikrs(): List<Dhikr> = emptyList()
        override suspend fun markAsDownloaded(dhikrId: AwradId, audioFileName: String) = Unit
        override suspend fun downloadAllAudio(): Boolean = true
        override suspend fun downloadSelectedAudio(dhikrs: List<Dhikr>): Boolean = true
        override suspend fun downloadDhikrAudio(dhikr: Dhikr): Boolean = true
        override fun getLibraryDownloadProgress(): StateFlow<DownloadProgress> = progress
        override suspend fun createDhikr(dhikr: Dhikr): AwradId = dhikr.id
        override suspend fun updateCustomDhikr(dhikr: Dhikr): Boolean = false
        override suspend fun deleteCustomDhikr(id: AwradId): Boolean = false
        override fun observeUserTags(): Flow<List<UserTag>> = tags
        override suspend fun createUserTag(rawName: String): UserTag? {
            val display = rawName.trim().replace(Regex("\\s+"), " ")
            val tag = UserTag(name = display, normalizedName = display.lowercase())
            tags.update { it + tag }
            return tag
        }

        override suspend fun renameUserTag(id: AwradId, rawName: String): UserTag? {
            val updated = tags.value.firstOrNull { it.id == id }?.copy(name = rawName) ?: return null
            tags.update { list -> list.map { if (it.id == id) updated else it } }
            return updated
        }

        override suspend fun deleteUserTag(id: AwradId): Boolean {
            tags.update { it.filterNot { tag -> tag.id == id } }
            assignments.update { current ->
                current.mapValues { (_, ids) -> ids - id }.filterValues { it.isNotEmpty() }
            }
            return true
        }

        override suspend fun setDhikrTags(dhikrId: AwradId, tagIds: Set<AwradId>) {
            assignments.update { it + (dhikrId to tagIds) }
        }

        override fun observeTagIdsForDhikr(dhikrId: AwradId): Flow<Set<AwradId>> =
            assignments.map { it[dhikrId].orEmpty() }

        override fun observeAssignments(): Flow<Map<AwradId, Set<AwradId>>> = assignments
        override suspend fun getOwnedAudio(dhikrId: AwradId): DhikrAudioAsset? = null
        override fun observeOwnedAudio(dhikrId: AwradId): Flow<DhikrAudioAsset?> = flowOf(null)
        override fun observeOwnedAudioByDhikrId(): Flow<Map<AwradId, DhikrAudioAsset>> = flowOf(emptyMap())
        override suspend fun attachOwnedAudio(dhikrId: AwradId, staged: StagedOwnedAudio) = error("unused")
        override suspend fun removeOwnedAudio(dhikrId: AwradId) = Unit
        override suspend fun ownedAudioAvailability(dhikrId: AwradId) = OwnedAudioAvailability.MISSING
        override suspend fun cleanupOwnedAudioOrphans() = Unit
    }
}
