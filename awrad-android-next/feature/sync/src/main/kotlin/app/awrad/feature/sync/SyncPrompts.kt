package app.awrad.feature.sync

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradDialog
import app.awrad.core.designsystem.component.AwradRowButton
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.PendingProfilePrompt
import app.awrad.core.domain.sync.ProfileChoice
import app.awrad.core.domain.sync.ProfileService
import app.awrad.core.domain.sync.RejectionCode
import app.awrad.core.domain.sync.SyncNotice
import app.awrad.core.domain.sync.SyncService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** What the app shell asks or tells, one at a time: a profile question first, then refused changes. */
internal data class SyncPromptsUiState(val prompt: PendingProfilePrompt? = null, val notice: SyncNotice? = null)

internal sealed interface SyncPromptsAction {
    data class Answer(val choice: ProfileChoice) : SyncPromptsAction

    data class Dismiss(val notice: SyncNotice) : SyncPromptsAction
}

@HiltViewModel
internal class SyncPromptsViewModel @Inject constructor(
    private val profiles: ProfileService,
    private val sync: SyncService,
) : ViewModel() {
    val state: StateFlow<SyncPromptsUiState> = combine(profiles.prompt, sync.notices) { prompt, notices ->
        SyncPromptsUiState(prompt, notices.firstOrNull())
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), SyncPromptsUiState())

    fun onAction(action: SyncPromptsAction) {
        viewModelScope.launch {
            when (action) {
                is SyncPromptsAction.Answer -> profiles.answer(action.choice)
                is SyncPromptsAction.Dismiss -> sync.dismissNotice(action.notice)
            }
        }
    }

    private companion object {
        const val STOP_TIMEOUT_MS = 5_000L
    }
}

/** Stateful prompts for the app shell, over every page. */
@Composable
internal fun SyncPromptsRoute(modifier: Modifier = Modifier, viewModel: SyncPromptsViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    SyncPromptsContent(state = state, onAction = viewModel::onAction, modifier = modifier)
}

/**
 * The first sign-in with data made before it ("Add to my account" or "Erase", asked once), a deleted account
 * whose data is still here ("Remove" or "Keep"), and a change the server refused, which was undone ("OK").
 */
@Composable
internal fun SyncPromptsContent(
    state: SyncPromptsUiState,
    onAction: (SyncPromptsAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    val prompt = state.prompt
    val notice = state.notice
    when {
        prompt is PendingProfilePrompt.AnonymousData -> AnonymousDataDialog(prompt, onAction, modifier)
        prompt is PendingProfilePrompt.AccountDeleted -> AccountDeletedDialog(prompt, onAction, modifier)
        notice != null -> AwradDialog(
            onDismissRequest = { onAction(SyncPromptsAction.Dismiss(notice)) },
            title = stringResource(R.string.sync_rejected_title),
            text = rejectedText(notice),
            modifier = modifier,
            confirmButton = {
                AwradRowButton(
                    text = stringResource(R.string.sync_ok),
                    onClick = { onAction(SyncPromptsAction.Dismiss(notice)) },
                    variant = AwradButtonVariant.Main,
                )
            },
        )
    }
}

/** "Add to my account" or "Erase": asked once, and it must be answered (Back or a tap outside keeps it open). */
@Composable
private fun AnonymousDataDialog(
    prompt: PendingProfilePrompt.AnonymousData,
    onAction: (SyncPromptsAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    AwradDialog(
        onDismissRequest = {},
        title = stringResource(R.string.sync_anonymous_title),
        text = stringResource(R.string.sync_anonymous_body, prompt.email),
        modifier = modifier,
        confirmButton = {
            AwradRowButton(
                text = stringResource(R.string.sync_anonymous_add),
                onClick = { onAction(SyncPromptsAction.Answer(ProfileChoice.ADD_TO_ACCOUNT)) },
                variant = AwradButtonVariant.Main,
            )
        },
        dismissButton = {
            AwradTextButton(
                text = stringResource(R.string.sync_anonymous_erase),
                onClick = { onAction(SyncPromptsAction.Answer(ProfileChoice.ERASE)) },
                isDestructive = true,
            )
        },
    )
}

/** A deleted account's data on this phone: "Remove" it, or "Keep" it (dismissing keeps it). */
@Composable
private fun AccountDeletedDialog(
    prompt: PendingProfilePrompt.AccountDeleted,
    onAction: (SyncPromptsAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    AwradDialog(
        onDismissRequest = { onAction(SyncPromptsAction.Answer(ProfileChoice.KEEP)) },
        title = stringResource(R.string.sync_deleted_title),
        text = stringResource(
            R.string.sync_deleted_body,
            prompt.email ?: stringResource(R.string.sync_profile_anonymous),
        ),
        modifier = modifier,
        confirmButton = {
            AwradRowButton(
                text = stringResource(R.string.sync_remove_confirm),
                onClick = { onAction(SyncPromptsAction.Answer(ProfileChoice.REMOVE)) },
                variant = AwradButtonVariant.Error,
            )
        },
        dismissButton = {
            AwradTextButton(
                text = stringResource(R.string.sync_deleted_keep),
                onClick = { onAction(SyncPromptsAction.Answer(ProfileChoice.KEEP)) },
            )
        },
    )
}

/** Which change was undone, and why: the code decides, never the message. */
@Composable
private fun rejectedText(notice: SyncNotice): String {
    val what = stringResource(
        when (notice.key.type) {
            EntityType.CUSTOM_DHIKR -> R.string.sync_rejected_dhikr
            EntityType.USER_TAG -> R.string.sync_rejected_tag
            EntityType.DHIKR_PERSONAL -> R.string.sync_rejected_tags
        },
    )
    val why = stringResource(
        when (notice.code) {
            RejectionCode.TAG_NAME_TAKEN -> R.string.sync_reason_tag_name_taken
            RejectionCode.TAG_LIMIT_REACHED -> R.string.sync_reason_tag_limit
            RejectionCode.CUSTOM_DHIKR_LIMIT_REACHED -> R.string.sync_reason_dhikr_limit
            RejectionCode.DOCUMENT_TOO_LARGE -> R.string.sync_reason_too_large
            RejectionCode.TAG_NOT_FOUND, RejectionCode.DHIKR_NOT_FOUND, RejectionCode.ENTITY_NOT_FOUND ->
                R.string.sync_reason_not_found
            RejectionCode.DOCUMENT_INVALID, RejectionCode.DELETE_NOT_ALLOWED, RejectionCode.COMMAND_ID_REUSED,
            RejectionCode.UNKNOWN,
            -> R.string.sync_reason_invalid
        },
    )
    return stringResource(R.string.sync_rejected_body, what, why)
}
