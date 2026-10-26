package app.awrad.feature.account.settings

import androidx.annotation.StringRes
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.DeleteForever
import androidx.compose.material.icons.filled.Devices
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Password
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import app.awrad.core.designsystem.component.AwradSecondaryButton
import app.awrad.core.domain.account.Account
import app.awrad.feature.account.AccountPage
import app.awrad.feature.account.BodyText
import app.awrad.feature.account.R

/** The signed-in account: its email, links to its settings, and sign out. */
@Composable
internal fun AccountOverviewScreen(
    account: Account,
    onAction: (OverviewAction) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    AccountPage(title = stringResource(R.string.account_title_signed_in), onBack = onBack, modifier = modifier) {
        Text(
            text = stringResource(R.string.account_signed_in_as),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = account.email,
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
        BodyText(text = stringResource(R.string.account_signed_in_body))
        Column {
            SettingsLink(
                icon = Icons.Filled.Devices,
                title = R.string.account_link_devices,
                onClick = { onAction(OverviewAction.DEVICES) },
                detail = R.string.account_link_devices_detail,
            )
            HorizontalDivider()
            SettingsLink(
                icon = Icons.Filled.Password,
                title = R.string.account_title_change_password,
                onClick = { onAction(OverviewAction.CHANGE_PASSWORD) },
            )
            HorizontalDivider()
            SettingsLink(
                icon = Icons.Filled.Email,
                title = R.string.account_title_change_email,
                onClick = { onAction(OverviewAction.CHANGE_EMAIL) },
            )
            HorizontalDivider()
            SettingsLink(
                icon = Icons.Filled.DeleteForever,
                title = R.string.account_title_delete,
                onClick = { onAction(OverviewAction.DELETE_ACCOUNT) },
                isDestructive = true,
            )
        }
        AwradSecondaryButton(
            text = stringResource(R.string.account_action_sign_out),
            onClick = { onAction(OverviewAction.SIGN_OUT) },
        )
    }
}

@Composable
private fun SettingsLink(
    icon: ImageVector,
    @StringRes title: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    @StringRes detail: Int? = null,
    isDestructive: Boolean = false,
) {
    val color = if (isDestructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface
    ListItem(
        modifier = modifier.clickable(onClick = onClick),
        colors = ListItemDefaults.colors(
            containerColor = MaterialTheme.colorScheme.background,
            headlineColor = color,
            leadingIconColor = color,
        ),
        leadingContent = { Icon(imageVector = icon, contentDescription = null) },
        headlineContent = { Text(text = stringResource(title)) },
        supportingContent = detail?.let { { Text(text = stringResource(it)) } },
        trailingContent = {
            Icon(imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
        },
    )
}
