package app.awrad.next.gallery

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import app.awrad.core.designsystem.component.AwradBackButton
import app.awrad.core.designsystem.component.AwradButton
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradIconButton
import app.awrad.core.designsystem.component.AwradRoundButton
import app.awrad.core.designsystem.component.AwradRoundButtonSize
import app.awrad.core.designsystem.component.AwradRowButton
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.next.R

/** Main, secondary, error and text buttons; loading and disabled; row, round and icon buttons. */
@Composable
internal fun ButtonsSection(modifier: Modifier = Modifier) {
    val disabled = stringResource(R.string.gallery_state_disabled)
    val loading = stringResource(R.string.gallery_state_loading)
    GallerySection(title = stringResource(R.string.gallery_section_buttons), modifier = modifier) {
        AwradButton(text = stringResource(R.string.gallery_get_started), onClick = {})
        AwradButton(
            text = stringResource(R.string.gallery_notifications),
            onClick = {},
            variant = AwradButtonVariant.Secondary,
            leadingIcon = AwradIcons.Notifications,
        )
        AwradButton(
            text = stringResource(R.string.gallery_delete_account),
            onClick = {},
            variant = AwradButtonVariant.Error,
        )
        StateLabel(text = loading)
        AwradButton(text = stringResource(R.string.gallery_get_started), onClick = {}, isLoading = true)
        AwradButton(
            text = stringResource(R.string.gallery_notifications),
            onClick = {},
            variant = AwradButtonVariant.Secondary,
            isLoading = true,
        )
        StateLabel(text = disabled)
        AwradButton(text = stringResource(R.string.gallery_get_started), onClick = {}, enabled = false)
        AwradButton(
            text = stringResource(R.string.gallery_notifications),
            onClick = {},
            variant = AwradButtonVariant.Secondary,
            enabled = false,
        )
        AwradButton(
            text = stringResource(R.string.gallery_delete_account),
            onClick = {},
            variant = AwradButtonVariant.Error,
            enabled = false,
        )
        TextAndRowButtons(disabled = disabled)
        RoundAndIconButtons(disabled = disabled)
    }
}

@Composable
private fun TextAndRowButtons(disabled: String) {
    Column(verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap)) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AwradTextButton(text = stringResource(R.string.gallery_view_all), onClick = {})
            AwradTextButton(text = stringResource(R.string.gallery_delete), onClick = {}, isDestructive = true)
            AwradTextButton(text = disabled, onClick = {}, enabled = false)
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AwradRowButton(text = stringResource(R.string.gallery_sign_out), onClick = {})
            AwradRowButton(
                text = stringResource(R.string.gallery_get_started),
                onClick = {},
                variant = AwradButtonVariant.Main,
            )
            AwradRowButton(text = stringResource(R.string.gallery_sign_out), onClick = {}, isLoading = true)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
            AwradRowButton(
                text = stringResource(R.string.gallery_delete),
                onClick = {},
                variant = AwradButtonVariant.Error,
            )
            AwradRowButton(text = disabled, onClick = {}, enabled = false)
        }
    }
}

@Composable
private fun RoundAndIconButtons(disabled: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AwradRoundButton(
            icon = AwradIcons.Add,
            contentDescription = stringResource(R.string.gallery_add_goal),
            onClick = {},
        )
        AwradRoundButton(
            icon = AwradIcons.Forward,
            contentDescription = stringResource(R.string.gallery_open_collection),
            onClick = {},
            size = AwradRoundButtonSize.Small,
        )
        AwradRoundButton(
            icon = AwradIcons.Add,
            contentDescription = disabled,
            onClick = {},
            enabled = false,
        )
        AwradBackButton(onClick = {})
        AwradIconButton(
            icon = AwradIcons.More,
            contentDescription = stringResource(R.string.gallery_more),
            onClick = {},
        )
        AwradIconButton(
            icon = AwradIcons.More,
            contentDescription = disabled,
            onClick = {},
            enabled = false,
        )
    }
}
