package app.awrad.feature.account.settings

import androidx.annotation.StringRes
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import app.awrad.core.designsystem.component.AwradButton
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.account.Account
import app.awrad.feature.account.AccountPage
import app.awrad.feature.account.DeviceNote
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
            style = AwradTheme.type.label,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = account.email,
            style = AwradTheme.type.cardTitle,
            color = MaterialTheme.colorScheme.onSurface,
        )
        DeviceNote(text = stringResource(R.string.account_signed_in_body))
        // Grouped on a card, as in the design; rows are separated by their own padding, never divider lines.
        AwradCard(
            contentPadding = PaddingValues(vertical = AwradTheme.spacing.sm),
            spacing = AwradTheme.spacing.none,
        ) {
            SettingsLink(
                icon = AwradIcons.Devices,
                title = R.string.account_link_devices,
                onClick = { onAction(OverviewAction.DEVICES) },
                detail = R.string.account_link_devices_detail,
            )
            SettingsLink(
                icon = AwradIcons.Password,
                title = R.string.account_title_change_password,
                onClick = { onAction(OverviewAction.CHANGE_PASSWORD) },
            )
            SettingsLink(
                icon = AwradIcons.Email,
                title = R.string.account_title_change_email,
                onClick = { onAction(OverviewAction.CHANGE_EMAIL) },
            )
            SettingsLink(
                icon = AwradIcons.Delete,
                title = R.string.account_title_delete,
                onClick = { onAction(OverviewAction.DELETE_ACCOUNT) },
                isDestructive = true,
            )
        }
        AwradButton(
            variant = AwradButtonVariant.Secondary,
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
    // The leading icon is quieter than the title, except on a destructive row, where it takes the title's colour.
    val iconColor = if (isDestructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant
    ListItem(
        modifier = modifier.clickable(onClick = onClick),
        colors = ListItemDefaults.colors(
            containerColor = Color.Transparent,
            headlineColor = color,
        ),
        leadingContent = {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(AwradTheme.sizes.icon),
                tint = iconColor,
            )
        },
        headlineContent = { Text(text = stringResource(title), style = AwradTheme.type.rowTitle) },
        supportingContent = detail?.let { { Text(text = stringResource(it), style = AwradTheme.type.bodySmall) } },
        // `chevron` flips in right-to-left layouts, so it always points the way the row opens.
        trailingContent = {
            Icon(
                imageVector = AwradIcons.Chevron,
                contentDescription = null,
                modifier = Modifier.size(AwradTheme.sizes.iconSmall),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        },
    )
}
