package app.awrad.next.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.core.designsystem.component.AwradButton
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.component.awradBottomBarPadding
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.feature.library.FeaturedCollections
import app.awrad.feature.library.LibraryDestination
import app.awrad.next.R

/**
 * The Home tab, a stand-in until the real home feature exists: the scaffold's note and its account, data and sync,
 * practice settings and onboarding links (the settings live here until a Settings tab exists), then "Featured dhikr
 * collections" from the library. It scrolls under the floating bottom bar.
 */
@Composable
fun HomeTab(
    onOpenAccount: () -> Unit,
    onOpenDataSync: () -> Unit,
    onOpenPracticeSettings: () -> Unit,
    onRestartOnboarding: () -> Unit,
    onNavigate: (LibraryDestination) -> Unit,
    onViewLibrary: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: HomePlaceholderViewModel = hiltViewModel(),
) {
    val spacing = AwradTheme.spacing
    Column(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(awradBottomBarPadding())
            .padding(top = spacing.xl2),
        verticalArrangement = Arrangement.spacedBy(spacing.xl2),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = spacing.pageMargin),
            verticalArrangement = Arrangement.spacedBy(spacing.rowGap),
        ) {
            Text(
                text = stringResource(R.string.home_placeholder_title),
                style = AwradTheme.type.title,
                color = AwradTheme.colors.onSurface,
            )
            Text(
                text = stringResource(R.string.home_placeholder_body),
                style = AwradTheme.type.body,
                color = AwradTheme.colors.onSurfaceVariant,
            )
            AwradButton(text = stringResource(R.string.home_placeholder_account), onClick = onOpenAccount)
            AwradButton(
                text = stringResource(R.string.home_placeholder_data_sync),
                onClick = onOpenDataSync,
                variant = AwradButtonVariant.Secondary,
            )
            AwradButton(
                text = stringResource(R.string.home_placeholder_practice),
                onClick = onOpenPracticeSettings,
                variant = AwradButtonVariant.Secondary,
                leadingIcon = AwradIcons.Practice,
            )
            AwradTextButton(
                text = stringResource(R.string.home_placeholder_restart),
                onClick = { viewModel.restartOnboarding(onRestartOnboarding) },
            )
        }
        FeaturedCollections(onNavigate = onNavigate, onViewAll = onViewLibrary)
    }
}
