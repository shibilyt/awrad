package app.awrad.feature.sync

import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradChip
import app.awrad.core.designsystem.component.AwradDialog
import app.awrad.core.designsystem.component.AwradRowButton
import app.awrad.core.designsystem.component.AwradSectionTitle
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.component.AwradTopBar
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.personal.AudioStorage
import app.awrad.core.domain.sync.ConflictChoice
import app.awrad.core.domain.sync.LocalProfile
import app.awrad.core.domain.sync.SyncState
import app.awrad.core.domain.sync.SyncStatus
import java.time.Instant

@Composable
internal fun DataSyncRoute(
    onBack: () -> Unit,
    onOpenAccount: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: DataSyncViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    DataSyncScreen(
        state = state,
        onAction = viewModel::onAction,
        onBack = onBack,
        onOpenAccount = onOpenAccount,
        modifier = modifier,
    )
}

/**
 * "Data and sync": a top bar with Back; "Sync" (where it stands, when it last synced, how many changes wait, the
 * account's audio storage when known, and Sync now while signed in); "Changed on another device" (each open
 * conflict with Keep mine and Use theirs); and "On this device", every local profile with "Remove from this device".
 */
@Composable
internal fun DataSyncScreen(
    state: DataSyncUiState,
    onAction: (DataSyncAction) -> Unit,
    onBack: () -> Unit,
    onOpenAccount: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val spacing = AwradTheme.spacing
    val navigationBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(AwradTheme.colors.background)
            .statusBarsPadding(),
    ) {
        AwradTopBar(title = stringResource(R.string.sync_title), onBack = onBack)
        if (state.isLoading) return@Column
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = spacing.pageMargin)
                .padding(top = spacing.sm, bottom = spacing.sectionGap + navigationBar),
            verticalArrangement = Arrangement.spacedBy(spacing.sectionGap),
        ) {
            StatusSection(
                headline = state.headline,
                status = state.status,
                audioStorage = state.audioStorage,
                onAction = onAction,
                onOpenAccount = onOpenAccount,
            )
            if (state.conflicts.isNotEmpty()) ConflictsSection(conflicts = state.conflicts, onAction = onAction)
            ProfilesSection(profiles = state.profiles, onAction = onAction)
        }
    }
    state.removing?.let { RemoveDialog(removing = it, onAction = onAction) }
}

@Composable
private fun StatusSection(
    headline: SyncHeadline,
    status: SyncStatus,
    audioStorage: AudioStorage?,
    onAction: (DataSyncAction) -> Unit,
    onOpenAccount: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
        AwradSectionTitle(text = stringResource(R.string.sync_section_status))
        AwradCard(spacing = AwradTheme.spacing.sm) {
            Text(text = headlineText(headline), style = AwradTheme.type.rowTitle, color = AwradTheme.colors.onSurface)
            Text(
                text = status.lastSyncedAt?.let { lastSyncedText(it) } ?: stringResource(R.string.sync_never_synced),
                style = AwradTheme.type.bodySmall,
                color = AwradTheme.colors.onSurfaceVariant,
            )
            Text(
                text = if (status.pendingCount == 0) {
                    stringResource(R.string.sync_nothing_pending)
                } else {
                    pluralStringResource(R.plurals.sync_pending, status.pendingCount, status.pendingCount)
                },
                style = AwradTheme.type.bodySmall,
                color = AwradTheme.colors.onSurfaceVariant,
            )
            audioStorage?.let { storage ->
                Text(
                    text = audioStorageText(storage),
                    style = AwradTheme.type.bodySmall,
                    color = AwradTheme.colors.onSurfaceVariant,
                )
            }
            if (status.state == SyncState.SIGNED_OUT) {
                AwradTextButton(text = stringResource(R.string.sync_sign_in), onClick = onOpenAccount)
            } else {
                AwradTextButton(
                    text = stringResource(R.string.sync_now),
                    onClick = { onAction(DataSyncAction.SyncNow) },
                    enabled = status.state != SyncState.SYNCING && status.state != SyncState.WAITING,
                )
            }
        }
    }
}

@Composable
private fun ConflictsSection(
    conflicts: List<NamedConflict>,
    onAction: (DataSyncAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
        AwradSectionTitle(text = stringResource(R.string.sync_section_conflicts))
        conflicts.forEach { named ->
            AwradCard(spacing = AwradTheme.spacing.sm) {
                Text(
                    text = conflictText(named.name),
                    style = AwradTheme.type.body,
                    color = AwradTheme.colors.onSurface,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
                    AwradRowButton(
                        text = stringResource(R.string.sync_keep_mine),
                        onClick = { onAction(DataSyncAction.Resolve(named.conflict.key, ConflictChoice.KEEP_MINE)) },
                        variant = AwradButtonVariant.Main,
                    )
                    AwradRowButton(
                        text = stringResource(R.string.sync_use_theirs),
                        onClick = { onAction(DataSyncAction.Resolve(named.conflict.key, ConflictChoice.USE_THEIRS)) },
                    )
                }
            }
        }
    }
}

@Composable
private fun ProfilesSection(
    profiles: List<LocalProfile>,
    onAction: (DataSyncAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
        AwradSectionTitle(text = stringResource(R.string.sync_section_profiles))
        Text(
            text = stringResource(R.string.sync_profiles_hint),
            style = AwradTheme.type.bodySmall,
            color = AwradTheme.colors.onSurfaceVariant,
        )
        profiles.forEach { profile -> ProfileCard(profile = profile, onAction = onAction) }
    }
}

@Composable
private fun ProfileCard(profile: LocalProfile, onAction: (DataSyncAction) -> Unit, modifier: Modifier = Modifier) {
    AwradCard(modifier = modifier.fillMaxWidth(), spacing = AwradTheme.spacing.sm) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = profile.email ?: stringResource(R.string.sync_profile_anonymous),
                modifier = Modifier.weight(1f),
                style = AwradTheme.type.rowTitle,
                color = AwradTheme.colors.onSurface,
            )
            if (profile.isActive) AwradChip(text = stringResource(R.string.sync_profile_active))
        }
        val status = when {
            profile.accountDeleted -> R.string.sync_profile_account_deleted
            profile.hasUnsent -> R.string.sync_profile_unsent
            else -> null
        }
        if (status != null) {
            Text(
                text = stringResource(status),
                style = AwradTheme.type.bodySmall,
                color = AwradTheme.colors.onSurfaceVariant,
            )
        }
        AwradTextButton(
            text = stringResource(R.string.sync_remove_profile),
            onClick = { onAction(DataSyncAction.AskRemove(profile.profileId)) },
            isDestructive = true,
        )
    }
}

/** "Remove from this device", with the unsent-changes warning when the profile has any. */
@Composable
private fun RemoveDialog(removing: Removing, onAction: (DataSyncAction) -> Unit, modifier: Modifier = Modifier) {
    val who = removing.profile.email ?: stringResource(R.string.sync_profile_anonymous)
    AwradDialog(
        onDismissRequest = { onAction(DataSyncAction.CancelRemove) },
        title = stringResource(R.string.sync_remove_title, who),
        text = stringResource(if (removing.warnsUnsent) R.string.sync_remove_unsent else R.string.sync_remove_body),
        modifier = modifier,
        confirmButton = {
            AwradRowButton(
                text = stringResource(R.string.sync_remove_confirm),
                onClick = { onAction(DataSyncAction.ConfirmRemove) },
                variant = AwradButtonVariant.Error,
            )
        },
        dismissButton = {
            AwradTextButton(
                text = stringResource(R.string.sync_cancel),
                onClick = { onAction(DataSyncAction.CancelRemove) },
            )
        },
    )
}

/** "Last synced just now" within a minute, else "Last synced 5 minutes ago" (Android's relative time). */
@Composable
private fun lastSyncedText(at: Instant): String {
    val millis = at.toEpochMilli()
    val now = System.currentTimeMillis()
    return if (now - millis < DateUtils.MINUTE_IN_MILLIS) {
        stringResource(R.string.sync_last_synced_now)
    } else {
        val relative = DateUtils.getRelativeTimeSpanString(millis, now, DateUtils.MINUTE_IN_MILLIS).toString()
        stringResource(R.string.sync_last_synced, relative)
    }
}

@Composable
private fun headlineText(headline: SyncHeadline): String = when (headline) {
    is SyncHeadline.State -> stateText(headline.state)
    is SyncHeadline.Conflicts -> pluralStringResource(R.plurals.sync_conflicts_open, headline.count, headline.count)
}

@Composable
private fun stateText(state: SyncState): String = stringResource(
    when (state) {
        SyncState.SIGNED_OUT -> R.string.sync_state_signed_out
        SyncState.WAITING -> R.string.sync_state_waiting
        SyncState.SYNCING -> R.string.sync_state_syncing
        SyncState.IDLE -> R.string.sync_state_idle
        SyncState.RETRYING -> R.string.sync_state_retrying
        SyncState.ACCOUNT_MISMATCH -> R.string.sync_state_mismatch
    },
)

@Composable
private fun conflictText(name: ConflictName): String = when (name) {
    is ConflictName.Dhikr -> name.title?.let { stringResource(R.string.sync_conflict_dhikr, it) }
        ?: stringResource(R.string.sync_conflict_dhikr_unnamed)
    is ConflictName.Tags -> name.dhikrTitle?.let { stringResource(R.string.sync_conflict_tags, it) }
        ?: stringResource(R.string.sync_conflict_tags_unnamed)
    is ConflictName.Tag -> name.name?.let { stringResource(R.string.sync_conflict_tag, it) }
        ?: stringResource(R.string.sync_conflict_tag_unnamed)
    ConflictName.PracticeSettings -> stringResource(R.string.sync_conflict_practice)
    ConflictName.Goals -> stringResource(R.string.sync_conflict_goals)
}
