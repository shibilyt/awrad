package app.awrad.next.gallery

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.rememberScrollState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradChip
import app.awrad.core.designsystem.component.AwradCollectionTile
import app.awrad.core.designsystem.component.AwradLinearProgress
import app.awrad.core.designsystem.component.AwradRoundButton
import app.awrad.core.designsystem.component.AwradSearchField
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.next.R

/** The library's pieces: collection tiles, the search field, chips and a progress bar of known length. */
@Composable
internal fun LibrarySection(modifier: Modifier = Modifier) {
    GallerySection(title = stringResource(R.string.gallery_section_library), modifier = modifier) {
        StateLabel(text = stringResource(R.string.gallery_collection_tiles))
        Row(
            modifier = Modifier
                .horizontalScroll(rememberScrollState())
                .height(IntrinsicSize.Max),
            horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap),
        ) {
            AwradCollectionTile(
                title = stringResource(R.string.gallery_collection_daily),
                count = pluralStringResource(R.plurals.gallery_dhikr_count, DAILY_COUNT, DAILY_COUNT),
                onClick = {},
                modifier = Modifier.fillMaxHeight(),
            )
            AwradCollectionTile(
                title = stringResource(R.string.gallery_collection_long),
                count = pluralStringResource(R.plurals.gallery_dhikr_count, ASMA_COUNT, ASMA_COUNT),
                onClick = {},
                modifier = Modifier.fillMaxHeight(),
            )
            AwradCollectionTile(
                title = stringResource(R.string.gallery_state_disabled),
                count = pluralStringResource(R.plurals.gallery_dhikr_count, 1, 1),
                onClick = {},
                modifier = Modifier.fillMaxHeight(),
                enabled = false,
            )
        }
        SearchFields()
        StateLabel(text = stringResource(R.string.gallery_chips))
        Row(horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
            AwradChip(text = stringResource(R.string.gallery_chip_debt))
            AwradChip(text = stringResource(R.string.gallery_chip_morning))
        }
        AwradCard {
            StateLabel(text = stringResource(R.string.gallery_on_card))
            AwradChip(text = stringResource(R.string.gallery_chip_debt))
            AwradLinearProgress(progress = { PROGRESS })
            StateLabel(text = stringResource(R.string.gallery_player_buttons))
            Row(horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.md)) {
                AwradRoundButton(
                    icon = AwradIcons.Play,
                    contentDescription = stringResource(R.string.gallery_play),
                    onClick = {},
                )
                AwradRoundButton(
                    icon = AwradIcons.Pause,
                    contentDescription = stringResource(R.string.gallery_play),
                    onClick = {},
                    isLoading = true,
                )
            }
        }
    }
}

@Composable
private fun SearchFields() {
    var query by rememberSaveable { mutableStateOf("") }
    val placeholder = stringResource(R.string.gallery_search_placeholder)
    AwradSearchField(value = query, onValueChange = { query = it }, placeholder = placeholder)
    AwradSearchField(
        value = stringResource(R.string.gallery_search_query),
        onValueChange = {},
        placeholder = placeholder,
    )
    StateLabel(text = stringResource(R.string.gallery_state_disabled))
    AwradSearchField(value = "", onValueChange = {}, placeholder = placeholder, enabled = false)
}

private const val DAILY_COUNT = 4
private const val ASMA_COUNT = 100
private const val PROGRESS = 0.4f
