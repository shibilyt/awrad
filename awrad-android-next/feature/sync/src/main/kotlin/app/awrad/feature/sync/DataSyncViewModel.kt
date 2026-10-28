package app.awrad.feature.sync

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.DhikrCatalogSource
import app.awrad.core.domain.personal.CustomDhikrRepository
import app.awrad.core.domain.personal.TagRepository
import app.awrad.core.domain.sync.ConflictChoice
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalProfile
import app.awrad.core.domain.sync.OpenConflict
import app.awrad.core.domain.sync.ProfilePrompt
import app.awrad.core.domain.sync.ProfileService
import app.awrad.core.domain.sync.SyncService
import app.awrad.core.domain.sync.SyncState
import app.awrad.core.domain.sync.SyncStatus
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * "Data and sync" in Settings: where syncing stands (last synced, changes waiting), open conflicts, and the
 * profiles on this phone, each removable after a confirmation that warns about unsent changes.
 */
@HiltViewModel
internal class DataSyncViewModel @Inject constructor(
    private val sync: SyncService,
    private val profiles: ProfileService,
    customDhikrs: CustomDhikrRepository,
    tags: TagRepository,
    catalogSource: DhikrCatalogSource,
) : ViewModel() {

    private val mutableState = MutableStateFlow(DataSyncUiState())
    val state: StateFlow<DataSyncUiState> = mutableState.asStateFlow()

    init {
        viewModelScope.launch {
            val catalog = catalogSource.catalog()
            combine(sync.status, profiles.profiles, sync.conflicts, customDhikrs.dhikrs, tags.tags) {
                    status, list, conflicts, dhikrs, allTags ->
                val names: (EntityKey) -> ConflictName = { key ->
                    val dhikrTitle = (dhikrs.firstOrNull { it.id == key.id }?.title?.preferred(ContentLanguage.EN))
                        ?: catalog.dhikr(key.id)?.title?.en
                    when (key.type) {
                        EntityType.CUSTOM_DHIKR -> ConflictName.Dhikr(dhikrTitle)
                        EntityType.DHIKR_PERSONAL -> ConflictName.Tags(dhikrTitle)
                        EntityType.USER_TAG -> ConflictName.Tag(allTags.firstOrNull { it.id == key.id }?.name)
                    }
                }
                Loaded(status, list, conflicts.map { NamedConflict(it, names(it.key)) })
            }.collect { loaded ->
                mutableState.update {
                    it.copy(
                        isLoading = false,
                        status = loaded.status,
                        profiles = loaded.profiles,
                        conflicts = loaded.conflicts,
                    )
                }
            }
        }
    }

    fun onAction(action: DataSyncAction) {
        when (action) {
            DataSyncAction.SyncNow -> sync.requestSync(debounced = false)
            is DataSyncAction.Resolve -> viewModelScope.launch { sync.resolve(action.key, action.choice) }
            is DataSyncAction.AskRemove -> viewModelScope.launch {
                val profile = mutableState.value.profiles.firstOrNull { it.profileId == action.profileId }
                    ?: return@launch
                val warns = profiles.removalPrompt(profile.profileId) == ProfilePrompt.UNSENT_CHANGES
                mutableState.update { it.copy(removing = Removing(profile, warns)) }
            }
            DataSyncAction.CancelRemove -> mutableState.update { it.copy(removing = null) }
            DataSyncAction.ConfirmRemove -> {
                val removing = mutableState.value.removing ?: return
                mutableState.update { it.copy(removing = null) }
                viewModelScope.launch { profiles.remove(removing.profile.profileId) }
            }
        }
    }

    private class Loaded(val status: SyncStatus, val profiles: List<LocalProfile>, val conflicts: List<NamedConflict>)
}

/** What a conflict is about, for its line: a dhikr's text, its tags, or a tag; names are null when unknown. */
internal sealed interface ConflictName {
    data class Dhikr(val title: String?) : ConflictName

    data class Tags(val dhikrTitle: String?) : ConflictName

    data class Tag(val name: String?) : ConflictName
}

internal data class NamedConflict(val conflict: OpenConflict, val name: ConflictName)

/** A profile waiting for the remove confirmation; [warnsUnsent] when its queue isn't empty. */
internal data class Removing(val profile: LocalProfile, val warnsUnsent: Boolean)

internal data class DataSyncUiState(
    val isLoading: Boolean = true,
    val status: SyncStatus = SyncStatus(),
    val profiles: List<LocalProfile> = emptyList(),
    val conflicts: List<NamedConflict> = emptyList(),
    val removing: Removing? = null,
) {
    /** The status card's first line: open conflicts instead of "Up to date", since syncing isn't done with them. */
    val headline: SyncHeadline
        get() = if (status.state == SyncState.IDLE && conflicts.isNotEmpty()) {
            SyncHeadline.Conflicts(conflicts.size)
        } else {
            SyncHeadline.State(status.state)
        }
}

/** What the status card leads with: the sync state, or how many conflicts are left to resolve. */
internal sealed interface SyncHeadline {
    data class State(val state: SyncState) : SyncHeadline

    data class Conflicts(val count: Int) : SyncHeadline
}

internal sealed interface DataSyncAction {
    data object SyncNow : DataSyncAction

    data class Resolve(val key: EntityKey, val choice: ConflictChoice) : DataSyncAction

    data class AskRemove(val profileId: AwradId) : DataSyncAction

    data object CancelRemove : DataSyncAction

    data object ConfirmRemove : DataSyncAction
}
