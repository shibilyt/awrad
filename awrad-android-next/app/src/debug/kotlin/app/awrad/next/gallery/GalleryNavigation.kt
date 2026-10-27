package app.awrad.next.gallery

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradCardSize
import app.awrad.core.designsystem.component.AwradContentSheet
import app.awrad.core.designsystem.component.AwradIconButton
import app.awrad.core.designsystem.component.AwradLargeTitlePage
import app.awrad.core.designsystem.component.AwradRoundButton
import app.awrad.core.designsystem.component.AwradRoundButtonSize
import app.awrad.core.designsystem.component.AwradSectionTitle
import app.awrad.core.designsystem.component.AwradSegmentedPills
import app.awrad.core.designsystem.component.AwradStepIndicator
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.component.AwradTopBar
import app.awrad.core.designsystem.component.awradBottomBarPadding
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.next.R

/** The steps of the sample onboarding flow. */
private const val SAMPLE_STEPS = 7

/** How many sample goals the Goals tab lists, enough to scroll. */
private const val SAMPLE_GOALS = 10

/** Top bars (back and title, back and steps, actions, a text action) and the step indicator. */
@Composable
internal fun NavigationSection(modifier: Modifier = Modifier) {
    GallerySection(
        title = stringResource(R.string.gallery_section_navigation),
        modifier = modifier,
        isInset = false,
    ) {
        Column {
            AwradTopBar(title = stringResource(R.string.gallery_welcome), onBack = {})
            AwradTopBar(onBack = {}, center = { AwradStepIndicator(step = 2, count = SAMPLE_STEPS) })
            AwradTopBar(
                title = stringResource(R.string.gallery_title),
                actions = {
                    AwradIconButton(
                        icon = Icons.Rounded.Notifications,
                        contentDescription = stringResource(R.string.gallery_notifications),
                        onClick = {},
                    )
                    AwradIconButton(
                        icon = Icons.Rounded.MoreVert,
                        contentDescription = stringResource(R.string.gallery_more),
                        onClick = {},
                    )
                },
            )
            AwradTopBar(
                onBack = {},
                actions = { AwradTextButton(text = stringResource(R.string.gallery_done), onClick = {}) },
            )
        }
        Column(
            modifier = Modifier.padding(horizontal = AwradTheme.spacing.pageMargin),
            verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap),
        ) {
            AwradStepIndicator(step = 1, count = SAMPLE_STEPS)
            AwradStepIndicator(step = 4, count = SAMPLE_STEPS)
            AwradStepIndicator(step = SAMPLE_STEPS, count = SAMPLE_STEPS)
        }
    }
}

/** My Goals: a large-title header with a round button, segmented pills and a content sheet of goal tiles. */
@Composable
internal fun GoalsTab(modifier: Modifier = Modifier) {
    var view by rememberSaveable { mutableIntStateOf(0) }
    AwradLargeTitlePage(
        title = stringResource(R.string.gallery_my_goals),
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding(),
        action = {
            AwradRoundButton(
                icon = Icons.Rounded.Add,
                contentDescription = stringResource(R.string.gallery_add_goal),
                onClick = {},
            )
        },
    ) {
        Column {
            AwradSegmentedPills(
                options = listOf(stringResource(R.string.gallery_active), stringResource(R.string.gallery_history)),
                selectedIndex = view,
                onSelect = { view = it },
                modifier = Modifier.padding(horizontal = AwradTheme.spacing.pageMargin),
            )
            AwradContentSheet(
                modifier = Modifier.padding(top = AwradTheme.spacing.lg),
                contentPadding = awradBottomBarPadding(),
            ) {
                Text(
                    text = stringResource(R.string.gallery_goals_hint),
                    style = AwradTheme.type.bodySmall,
                    color = AwradTheme.colors.onSurfaceVariant,
                )
                AwradSectionTitle(text = stringResource(R.string.gallery_today))
                repeat(SAMPLE_GOALS) {
                    AwradCard(onClick = {}, size = AwradCardSize.Tile) {
                        TileText(
                            title = stringResource(R.string.gallery_tile_title),
                            body = stringResource(R.string.gallery_tile_body),
                        )
                    }
                }
                AwradRoundButton(
                    icon = Icons.AutoMirrored.Rounded.ArrowForward,
                    contentDescription = stringResource(R.string.gallery_open_collection),
                    onClick = {},
                    size = AwradRoundButtonSize.Small,
                )
            }
        }
    }
}
