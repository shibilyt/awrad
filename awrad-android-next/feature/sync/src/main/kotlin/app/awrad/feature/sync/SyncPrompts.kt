package app.awrad.feature.sync

import androidx.annotation.StringRes
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
import app.awrad.core.domain.personal.AudioUploadNotice
import app.awrad.core.domain.personal.AudioUploadProblem
import app.awrad.core.domain.personal.CustomAudioService
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

/**
 * What the app shell asks or tells, one at a time: a profile question first, then refused changes, then
 * recordings that couldn't upload.
 */
internal data class SyncPromptsUiState(
    val prompt: PendingProfilePrompt? = null,
    val notice: SyncNotice? = null,
    val upload: AudioUploadNotice? = null,
)

internal sealed interface SyncPromptsAction {
    data class Answer(val choice: ProfileChoice) : SyncPromptsAction

    data class Dismiss(val notice: SyncNotice) : SyncPromptsAction

    data class DismissUpload(val notice: AudioUploadNotice) : SyncPromptsAction
}

@HiltViewModel
internal class SyncPromptsViewModel @Inject constructor(
    private val profiles: ProfileService,
    private val sync: SyncService,
    private val audio: CustomAudioService,
) : ViewModel() {
    val state: StateFlow<SyncPromptsUiState> =
        combine(profiles.prompt, sync.notices, audio.uploadNotices) { prompt, notices, uploads ->
            SyncPromptsUiState(prompt, notices.firstOrNull(), uploads.firstOrNull())
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), SyncPromptsUiState())

    fun onAction(action: SyncPromptsAction) {
        viewModelScope.launch {
            when (action) {
                is SyncPromptsAction.Answer -> profiles.answer(action.choice)
                is SyncPromptsAction.Dismiss -> sync.dismissNotice(action.notice)
                is SyncPromptsAction.DismissUpload -> audio.dismissUploadNotice(action.notice)
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
 * whose data is still here ("Remove" or "Keep"), a change the server refused ("OK"), and a recording that couldn't
 * upload ("OK").
 */
@Composable
internal fun SyncPromptsContent(
    state: SyncPromptsUiState,
    onAction: (SyncPromptsAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    val prompt = state.prompt
    val notice = state.notice
    val upload = state.upload
    when {
        prompt is PendingProfilePrompt.AnonymousData -> AnonymousDataDialog(prompt, onAction, modifier)
        prompt is PendingProfilePrompt.AccountDeleted -> AccountDeletedDialog(prompt, onAction, modifier)
        notice != null -> ChangeRefusedDialog(notice, onAction, modifier)
        upload != null -> UploadFailedDialog(upload, onAction, modifier)
    }
}

/**
 * "Audio couldn't be uploaded": why (with the account's use and limit when storage is full), and that the recording
 * stays on this phone while the dhikr still syncs. A single "OK" closes it.
 */
@Composable
private fun UploadFailedDialog(
    notice: AudioUploadNotice,
    onAction: (SyncPromptsAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    val storage = notice.storage
    val reason = if (notice.problem == AudioUploadProblem.STORAGE_FULL && storage != null) {
        stringResource(R.string.sync_upload_storage_full_used, storageUsedText(storage))
    } else {
        stringResource(uploadProblemReason(notice.problem))
    }
    AwradDialog(
        onDismissRequest = { onAction(SyncPromptsAction.DismissUpload(notice)) },
        title = stringResource(R.string.sync_upload_failed_title),
        text = stringResource(R.string.sync_upload_failed_body, reason),
        modifier = modifier,
        confirmButton = {
            AwradTextButton(
                text = stringResource(R.string.sync_ok),
                onClick = { onAction(SyncPromptsAction.DismissUpload(notice)) },
            )
        },
    )
}

/** Why a recording couldn't upload, one message per problem. */
@StringRes
internal fun uploadProblemReason(problem: AudioUploadProblem): Int = when (problem) {
    AudioUploadProblem.UNSUPPORTED_TYPE -> R.string.sync_upload_unsupported_type
    AudioUploadProblem.INVALID_SIZE -> R.string.sync_upload_invalid_size
    AudioUploadProblem.FILE_TOO_LARGE -> R.string.sync_upload_too_large
    AudioUploadProblem.STORAGE_FULL -> R.string.sync_upload_storage_full
    AudioUploadProblem.UPLOAD_MISMATCH -> R.string.sync_upload_mismatch
}

/**
 * The "Change refused" notice (components.md): the server refused a change, which is already undone (an edit naming
 * a recording the account doesn't have is kept and sent again instead). The title, the reason for its rejection
 * code, and a single "OK" text button that closes it.
 */
@Composable
private fun ChangeRefusedDialog(
    notice: SyncNotice,
    onAction: (SyncPromptsAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    AwradDialog(
        onDismissRequest = { onAction(SyncPromptsAction.Dismiss(notice)) },
        title = stringResource(noticeTitle(notice.code)),
        text = stringResource(refusedReason(notice.code)),
        modifier = modifier,
        confirmButton = {
            AwradTextButton(
                text = stringResource(R.string.sync_ok),
                onClick = { onAction(SyncPromptsAction.Dismiss(notice)) },
            )
        },
    )
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

/** Why a change was refused, one message per rejection code: the code decides, never the server's message. */
@StringRes
internal fun refusedReason(code: RejectionCode): Int = when (code) {
    RejectionCode.DOCUMENT_INVALID, RejectionCode.UNKNOWN -> R.string.sync_reason_document_invalid
    RejectionCode.DOCUMENT_TOO_LARGE -> R.string.sync_reason_document_too_large
    RejectionCode.CUSTOM_DHIKR_LIMIT_REACHED -> R.string.sync_reason_custom_dhikr_limit
    RejectionCode.TAG_LIMIT_REACHED -> R.string.sync_reason_tag_limit
    RejectionCode.TAG_NAME_TAKEN -> R.string.sync_reason_tag_name_taken
    RejectionCode.TAG_NOT_FOUND -> R.string.sync_reason_tag_not_found
    RejectionCode.DHIKR_NOT_FOUND -> R.string.sync_reason_dhikr_not_found
    RejectionCode.ENTITY_NOT_FOUND -> R.string.sync_reason_entity_not_found
    RejectionCode.DELETE_NOT_ALLOWED -> R.string.sync_reason_delete_not_allowed
    RejectionCode.COMMAND_ID_REUSED -> R.string.sync_reason_command_id_reused
    RejectionCode.AUDIO_NOT_FOUND -> R.string.sync_reason_audio_not_found
    RejectionCode.AUDIO_MISMATCH -> R.string.sync_reason_audio_mismatch
    RejectionCode.ENTITY_ID_INVALID -> R.string.sync_reason_entity_id_invalid
    RejectionCode.GOAL_LIMIT_REACHED -> R.string.sync_reason_goal_limit
    RejectionCode.GOAL_FIELD_IMMUTABLE -> R.string.sync_reason_goal_field_immutable
    RejectionCode.GOAL_EDIT_NOT_APPLIED -> R.string.sync_reason_goal_edit_not_applied
    RejectionCode.HIJRI_CORRECTIONS_REPLACED -> R.string.sync_reason_hijri_corrections_replaced
}

/**
 * The notice's title: "Change refused", or its own for a practice-policy merge that dropped corrections and for a goal
 * edit another device's beat.
 */
@StringRes
internal fun noticeTitle(code: RejectionCode): Int = when (code) {
    RejectionCode.HIJRI_CORRECTIONS_REPLACED -> R.string.sync_hijri_replaced_title
    RejectionCode.GOAL_EDIT_NOT_APPLIED -> R.string.sync_goal_edit_not_applied_title
    else -> R.string.sync_rejected_title
}
