package app.awrad.feature.account.settings

import android.text.format.DateUtils
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Devices
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.PhoneIphone
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.core.designsystem.component.AwradSecondaryButton
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.domain.account.AccountSession
import app.awrad.feature.account.AccountPage
import app.awrad.feature.account.BodyText
import app.awrad.feature.account.ConfirmDialog
import app.awrad.feature.account.R
import app.awrad.feature.account.message
import app.awrad.feature.account.pageStatus
import java.time.Duration
import java.time.Instant

@Composable
internal fun DevicesRoute(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: DevicesViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    DevicesScreen(state = state, onAction = viewModel::onAction, onBack = onBack, modifier = modifier)
}

/** Every phone and browser signed in, this device marked; any other can be signed out. */
@Composable
internal fun DevicesScreen(
    state: DevicesUiState,
    onAction: (DevicesAction) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    AccountPage(
        title = stringResource(R.string.account_title_devices),
        onBack = onBack,
        modifier = modifier,
        isBusy = state.isBusy,
        status = pageStatus(error = state.error?.message(), notice = state.notice?.message()),
    ) {
        BodyText(text = stringResource(R.string.account_devices_intro))
        val sessions = state.sessions
        if (sessions == null) {
            if (state.canRetry) {
                AwradSecondaryButton(
                    text = stringResource(R.string.account_action_retry),
                    onClick = { onAction(DevicesAction.Reload) },
                )
            }
        } else {
            SessionList(sessions = sessions, now = state.loadedAt, onRevoke = { onAction(DevicesAction.Revoke(it)) })
            if (state.others.isEmpty()) BodyText(text = stringResource(R.string.account_devices_none_other))
            AwradSecondaryButton(
                text = stringResource(R.string.account_action_revoke_others),
                onClick = { onAction(DevicesAction.RevokeOthers) },
                enabled = state.canRevoke,
            )
        }
        state.confirming?.let { confirmation ->
            RevokeDialog(
                confirmation = confirmation,
                onConfirm = { onAction(DevicesAction.Confirm) },
                onDismiss = { onAction(DevicesAction.Dismiss) },
            )
        }
    }
}

@Composable
private fun SessionList(
    sessions: List<AccountSession>,
    now: Instant,
    onRevoke: (AccountSession) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(0.dp)) {
        sessions.forEachIndexed { index, session ->
            if (index > 0) HorizontalDivider()
            SessionRow(session = session, now = now, onRevoke = { onRevoke(session) })
        }
    }
}

@Composable
private fun SessionRow(session: AccountSession, now: Instant, onRevoke: () -> Unit, modifier: Modifier = Modifier) {
    val name = sessionName(session)
    val detail = if (session.isCurrent) {
        stringResource(R.string.account_devices_this_device)
    } else {
        lastUsedText(lastSeen = session.lastSeenAt, now = now)
    }
    ListItem(
        modifier = modifier,
        colors = ListItemDefaults.colors(containerColor = MaterialTheme.colorScheme.background),
        leadingContent = { Icon(imageVector = session.platform.icon(), contentDescription = null) },
        headlineContent = { Text(text = name) },
        supportingContent = {
            Text(text = stringResource(R.string.account_devices_detail, platformLabel(session.platform), detail))
        },
        trailingContent = if (session.isCurrent) {
            null
        } else {
            {
                val description = stringResource(R.string.account_action_revoke_named, name)
                AwradTextButton(
                    text = stringResource(R.string.account_action_revoke),
                    onClick = onRevoke,
                    modifier = Modifier.semantics { contentDescription = description },
                )
            }
        },
    )
}

@Composable
private fun RevokeDialog(
    confirmation: DevicesConfirmation,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    when (confirmation) {
        is DevicesConfirmation.RevokeOne -> ConfirmDialog(
            title = stringResource(R.string.account_devices_confirm_one_title, sessionName(confirmation.session)),
            text = stringResource(R.string.account_devices_confirm_one_body),
            confirmLabel = stringResource(R.string.account_action_revoke),
            onConfirm = onConfirm,
            onDismiss = onDismiss,
            modifier = modifier,
        )
        DevicesConfirmation.RevokeOthers -> ConfirmDialog(
            title = stringResource(R.string.account_devices_confirm_others_title),
            text = stringResource(R.string.account_devices_confirm_others_body),
            confirmLabel = stringResource(R.string.account_action_revoke_others_short),
            onConfirm = onConfirm,
            onDismiss = onDismiss,
            modifier = modifier,
        )
    }
}

/** The model or browser the server reported, or a generic label ("Web browser" for an unnamed browser). */
@Composable
private fun sessionName(session: AccountSession): String = session.name ?: when {
    session.kind == AccountSession.Kind.BROWSER || session.platform == AccountSession.Platform.WEB ->
        stringResource(R.string.account_devices_unnamed_browser)
    else -> stringResource(R.string.account_devices_unnamed_device)
}

@Composable
private fun platformLabel(platform: AccountSession.Platform): String = stringResource(
    when (platform) {
        AccountSession.Platform.ANDROID -> R.string.account_devices_platform_android
        AccountSession.Platform.IOS -> R.string.account_devices_platform_ios
        AccountSession.Platform.WEB -> R.string.account_devices_platform_web
        AccountSession.Platform.OTHER -> R.string.account_devices_platform_other
    },
)

private fun AccountSession.Platform.icon(): ImageVector = when (this) {
    AccountSession.Platform.ANDROID -> Icons.Filled.PhoneAndroid
    AccountSession.Platform.IOS -> Icons.Filled.PhoneIphone
    AccountSession.Platform.WEB -> Icons.Filled.Language
    AccountSession.Platform.OTHER -> Icons.Filled.Devices
}

/** "Last used 5 minutes ago", in the app's language; "Active now" within the last minute. */
@Composable
private fun lastUsedText(lastSeen: Instant, now: Instant): String =
    if (Duration.between(lastSeen, now) < Duration.ofMinutes(1)) {
        stringResource(R.string.account_devices_active_now)
    } else {
        val relative = DateUtils.getRelativeTimeSpanString(
            lastSeen.toEpochMilli(),
            now.toEpochMilli(),
            DateUtils.MINUTE_IN_MILLIS,
        )
        stringResource(R.string.account_devices_last_used, relative.toString())
    }
