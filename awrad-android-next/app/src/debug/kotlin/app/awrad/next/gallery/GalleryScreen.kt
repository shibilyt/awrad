package app.awrad.next.gallery

import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import app.awrad.core.designsystem.component.AwradBottomBar
import app.awrad.core.designsystem.component.AwradBottomBarItem
import app.awrad.core.designsystem.component.AwradBottomBarLayout
import app.awrad.core.designsystem.component.AwradSectionTitle
import app.awrad.core.designsystem.component.AwradSwitch
import app.awrad.core.designsystem.component.AwradTopBar
import app.awrad.core.designsystem.component.awradBottomBarPadding
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.next.R

/** The gallery: four tabs in the floating bottom bar. Components is the gallery itself; Goals a sample tab. */
@Composable
internal fun GalleryScreen(
    settings: GallerySettings,
    startTab: Int,
    startWithSheet: Boolean,
    modifier: Modifier = Modifier,
) {
    var tab by rememberSaveable { mutableIntStateOf(startTab.coerceIn(0, TAB_COUNT - 1)) }
    val motion = AwradTheme.motion
    AwradBottomBarLayout(
        modifier = modifier.background(AwradTheme.colors.background),
        bottomBar = {
            AwradBottomBar(items = tabItems(), selectedIndex = tab, onSelect = { tab = it })
        },
    ) {
        AnimatedContent(
            targetState = tab,
            transitionSpec = { motion.tabSwitch() },
            label = "galleryTab",
        ) { shown ->
            when (shown) {
                0 -> ComponentsTab(settings = settings, startWithSheet = startWithSheet)
                1 -> GoalsTab()
                else -> EmptyTab()
            }
        }
    }
}

private const val TAB_COUNT = 4

@Composable
private fun tabItems(): List<AwradBottomBarItem> = listOf(
    AwradBottomBarItem(stringResource(R.string.gallery_home), AwradIcons.Home),
    AwradBottomBarItem(stringResource(R.string.gallery_goals), AwradIcons.Goals),
    AwradBottomBarItem(stringResource(R.string.gallery_library), AwradIcons.Library),
    AwradBottomBarItem(stringResource(R.string.gallery_community), AwradIcons.Community),
)

/** Every component, section by section, under the gallery's own switches. */
@Composable
private fun ComponentsTab(settings: GallerySettings, startWithSheet: Boolean, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(awradBottomBarPadding()),
    ) {
        AwradTopBar(title = stringResource(R.string.gallery_title))
        Column(verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.xl3)) {
            GallerySwitches(
                settings = settings,
                modifier = Modifier.padding(horizontal = AwradTheme.spacing.pageMargin),
            )
            ButtonsSection()
            InputsSection()
            ContainersSection(startWithSheet = startWithSheet)
            LibrarySection()
            NavigationSection()
            IconsSection()
        }
    }
}

@Composable
private fun GallerySwitches(settings: GallerySettings, modifier: Modifier = Modifier) {
    Column(modifier = modifier) {
        AwradSwitch(
            checked = settings.dark,
            onCheckedChange = settings.onDarkChange,
            label = stringResource(R.string.gallery_dark),
        )
        AwradSwitch(
            checked = settings.rtl,
            onCheckedChange = settings.onRtlChange,
            label = stringResource(R.string.gallery_rtl),
        )
        AwradSwitch(
            checked = settings.reducedMotion,
            onCheckedChange = settings.onReducedMotionChange,
            label = stringResource(R.string.gallery_reduced_motion),
        )
    }
}

/**
 * A titled group of samples, `rowGap` apart, inset by the page margin unless [isInset] is false (top bars span
 * the screen and inset themselves).
 */
@Composable
internal fun GallerySection(
    title: String,
    modifier: Modifier = Modifier,
    isInset: Boolean = true,
    content: @Composable ColumnScope.() -> Unit,
) {
    val margin = AwradTheme.spacing.pageMargin
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap)) {
        AwradSectionTitle(text = title, modifier = Modifier.padding(horizontal = margin))
        Column(
            modifier = Modifier.padding(horizontal = if (isInset) margin else AwradTheme.spacing.none),
            verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap),
            content = content,
        )
    }
}

/** A caption naming the state shown below it. */
@Composable
internal fun StateLabel(text: String, modifier: Modifier = Modifier) {
    Text(text = text, modifier = modifier, style = AwradTheme.type.caption, color = AwradTheme.colors.onSurfaceVariant)
}

@Composable
private fun EmptyTab(modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(
            text = stringResource(R.string.gallery_empty_tab),
            style = AwradTheme.type.body,
            color = AwradTheme.colors.onSurfaceVariant,
        )
    }
}
