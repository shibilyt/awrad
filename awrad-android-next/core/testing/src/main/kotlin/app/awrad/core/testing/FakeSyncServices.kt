package app.awrad.core.testing

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.sync.ConflictChoice
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.LocalProfile
import app.awrad.core.domain.sync.OpenConflict
import app.awrad.core.domain.sync.PendingProfilePrompt
import app.awrad.core.domain.sync.ProfileChoice
import app.awrad.core.domain.sync.ProfilePrompt
import app.awrad.core.domain.sync.ProfileService
import app.awrad.core.domain.sync.SyncNotice
import app.awrad.core.domain.sync.SyncService
import app.awrad.core.domain.sync.SyncStatus
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** A [SyncService] whose state tests set; it records requests and resolutions. */
public class FakeSyncService(status: SyncStatus = SyncStatus()) : SyncService {
    override val status: MutableStateFlow<SyncStatus> = MutableStateFlow(status)
    public val conflictState: MutableStateFlow<List<OpenConflict>> = MutableStateFlow(emptyList())
    public val noticeState: MutableStateFlow<List<SyncNotice>> = MutableStateFlow(emptyList())
    public val resolved: MutableList<Pair<EntityKey, ConflictChoice>> = mutableListOf()
    public var requests: Int = 0
        private set

    override val conflicts: Flow<List<OpenConflict>> = conflictState
    override val notices: Flow<List<SyncNotice>> = noticeState

    override fun requestSync(debounced: Boolean) {
        requests++
    }

    override suspend fun resolve(key: EntityKey, choice: ConflictChoice) {
        resolved += key to choice
        conflictState.value = conflictState.value.filterNot { it.key == key }
    }

    override suspend fun dismissNotice(notice: SyncNotice) {
        noticeState.value = noticeState.value - notice
    }
}

/** A [ProfileService] whose profiles and question tests set; it records answers and removals. */
public class FakeProfileService(profiles: List<LocalProfile> = emptyList()) : ProfileService {
    public val profileState: MutableStateFlow<List<LocalProfile>> = MutableStateFlow(profiles)
    private val promptState = MutableStateFlow<PendingProfilePrompt?>(null)
    public val answers: MutableList<ProfileChoice> = mutableListOf()
    public val removed: MutableList<AwradId> = mutableListOf()

    override val profiles: Flow<List<LocalProfile>> = profileState
    override val prompt: StateFlow<PendingProfilePrompt?> = promptState

    public fun ask(prompt: PendingProfilePrompt?) {
        promptState.value = prompt
    }

    override suspend fun answer(choice: ProfileChoice) {
        answers += choice
        promptState.value = null
    }

    override suspend fun removalPrompt(profileId: AwradId): ProfilePrompt? =
        ProfilePrompt.UNSENT_CHANGES.takeIf {
            profileState.value.firstOrNull { it.profileId == profileId }?.hasUnsent == true
        }

    override suspend fun remove(profileId: AwradId) {
        removed += profileId
        profileState.value = profileState.value.filterNot { it.profileId == profileId }
    }
}
