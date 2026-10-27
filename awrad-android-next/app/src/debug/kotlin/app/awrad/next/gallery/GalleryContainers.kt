package app.awrad.next.gallery

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import app.awrad.core.designsystem.component.AwradBottomSheet
import app.awrad.core.designsystem.component.AwradButton
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradCardSize
import app.awrad.core.designsystem.component.AwradDialog
import app.awrad.core.designsystem.component.AwradOptionRow
import app.awrad.core.designsystem.component.AwradRowButton
import app.awrad.core.designsystem.component.AwradSelectionMode
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.next.R

/** Cards (static, clickable, disabled; card and tile), option rows, dialogs and the bottom sheet. */
@Composable
internal fun ContainersSection(startWithSheet: Boolean, modifier: Modifier = Modifier) {
    GallerySection(title = stringResource(R.string.gallery_section_containers), modifier = modifier) {
        Cards()
        Languages()
        Reminders()
        Overlays(startWithSheet = startWithSheet)
        StateLabel(text = stringResource(R.string.gallery_large_title_hint))
    }
}

@Composable
private fun Cards() {
    AwradCard {
        Text(text = stringResource(R.string.gallery_card_title), style = AwradTheme.type.cardTitle)
        Text(
            text = stringResource(R.string.gallery_card_body),
            style = AwradTheme.type.body,
            color = AwradTheme.colors.onSurfaceVariant,
        )
    }
    AwradCard(onClick = {}, size = AwradCardSize.Tile) {
        TileText(title = stringResource(R.string.gallery_tile_title), body = stringResource(R.string.gallery_tap_card))
    }
    StateLabel(text = stringResource(R.string.gallery_state_disabled))
    AwradCard(onClick = {}, size = AwradCardSize.Tile, enabled = false) {
        TileText(title = stringResource(R.string.gallery_tile_title), body = stringResource(R.string.gallery_tile_body))
    }
    SecondaryOnACard()
}

/** On a `surface` card, secondary controls fill with `background` instead of `secondaryContainer`. */
@Composable
private fun SecondaryOnACard() {
    var selected by rememberSaveable { mutableIntStateOf(0) }
    AwradCard {
        StateLabel(text = stringResource(R.string.gallery_on_card))
        AwradOptionRow(
            label = stringResource(R.string.gallery_after_fajr),
            selected = selected == 0,
            onClick = { selected = 0 },
        )
        AwradOptionRow(
            label = stringResource(R.string.gallery_after_isha),
            selected = selected == 1,
            onClick = { selected = 1 },
        )
        AwradButton(
            text = stringResource(R.string.gallery_notifications),
            onClick = {},
            variant = AwradButtonVariant.Secondary,
        )
    }
}

@Composable
internal fun TileText(title: String, body: String, modifier: Modifier = Modifier) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.xxs)) {
        Text(text = title, style = AwradTheme.type.rowTitle)
        Text(text = body, style = AwradTheme.type.bodySmall, color = AwradTheme.colors.onSurfaceVariant)
    }
}

@Composable
private fun Languages() {
    var language by rememberSaveable { mutableIntStateOf(0) }
    val options = listOf(
        stringResource(R.string.gallery_lang_en) to stringResource(R.string.gallery_avatar_en),
        stringResource(R.string.gallery_lang_ar) to stringResource(R.string.gallery_avatar_ar),
        stringResource(R.string.gallery_lang_ml) to stringResource(R.string.gallery_avatar_ml),
    )
    StateLabel(text = stringResource(R.string.gallery_language))
    options.forEachIndexed { index, (label, avatar) ->
        AwradOptionRow(label = label, selected = index == language, onClick = { language = index }, avatar = avatar)
    }
}

@Composable
private fun Reminders() {
    var fajr by rememberSaveable { mutableStateOf(true) }
    var isha by rememberSaveable { mutableStateOf(false) }
    StateLabel(text = stringResource(R.string.gallery_reminders))
    AwradOptionRow(
        label = stringResource(R.string.gallery_after_fajr),
        selected = fajr,
        onClick = { fajr = !fajr },
        mode = AwradSelectionMode.Multiple,
    )
    AwradOptionRow(
        label = stringResource(R.string.gallery_after_isha),
        selected = isha,
        onClick = { isha = !isha },
        mode = AwradSelectionMode.Multiple,
    )
    StateLabel(text = stringResource(R.string.gallery_state_disabled))
    AwradOptionRow(label = stringResource(R.string.gallery_after_fajr), selected = true, onClick = {}, enabled = false)
    AwradOptionRow(label = stringResource(R.string.gallery_after_isha), selected = false, onClick = {}, enabled = false)
}

@Composable
private fun Overlays(startWithSheet: Boolean) {
    var dialog by rememberSaveable { mutableStateOf(false) }
    var errorDialog by rememberSaveable { mutableStateOf(false) }
    var sheet by rememberSaveable { mutableStateOf(startWithSheet) }
    AwradButton(
        text = stringResource(R.string.gallery_show_dialog),
        onClick = { dialog = true },
        variant = AwradButtonVariant.Secondary,
    )
    AwradButton(
        text = stringResource(R.string.gallery_show_error_dialog),
        onClick = { errorDialog = true },
        variant = AwradButtonVariant.Secondary,
    )
    AwradButton(
        text = stringResource(R.string.gallery_show_sheet),
        onClick = { sheet = true },
        variant = AwradButtonVariant.Secondary,
    )
    if (dialog) {
        AwradDialog(
            onDismissRequest = { dialog = false },
            title = stringResource(R.string.gallery_dialog_title),
            text = stringResource(R.string.gallery_dialog_body),
            confirmButton = {
                AwradRowButton(
                    text = stringResource(R.string.gallery_sign_out),
                    onClick = { dialog = false },
                    variant = AwradButtonVariant.Main,
                )
            },
            dismissButton = {
                AwradTextButton(text = stringResource(R.string.gallery_cancel), onClick = { dialog = false })
            },
        )
    }
    if (errorDialog) {
        AwradDialog(
            onDismissRequest = { errorDialog = false },
            title = stringResource(R.string.gallery_delete_title),
            text = stringResource(R.string.gallery_delete_body),
            confirmButton = {
                AwradRowButton(
                    text = stringResource(R.string.gallery_delete),
                    onClick = { errorDialog = false },
                    variant = AwradButtonVariant.Error,
                )
            },
            dismissButton = {
                AwradTextButton(text = stringResource(R.string.gallery_cancel), onClick = { errorDialog = false })
            },
        )
    }
    if (sheet) SampleSheet(onDismissRequest = { sheet = false })
}

@Composable
private fun SampleSheet(onDismissRequest: () -> Unit) {
    var choice by rememberSaveable { mutableIntStateOf(0) }
    AwradBottomSheet(onDismissRequest = onDismissRequest) {
        Text(text = stringResource(R.string.gallery_sheet_title), style = AwradTheme.type.cardTitle)
        AwradOptionRow(
            label = stringResource(R.string.gallery_after_fajr),
            selected = choice == 0,
            onClick = { choice = 0 },
        )
        AwradOptionRow(
            label = stringResource(R.string.gallery_after_isha),
            selected = choice == 1,
            onClick = { choice = 1 },
        )
        AwradButton(text = stringResource(R.string.gallery_done), onClick = onDismissRequest)
    }
}
