package app.awrad.awrad_dhikrgoalstracker.ui.screens.community

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.BookmarkBorder
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard

@Composable
internal fun CommunityStatsScreen(
    onNavigateBack: () -> Unit,
    viewModel: CommunityStatsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsState()
    CommunityPage(title = stringResource(R.string.community_nav_stats), onNavigateBack = onNavigateBack) {
        CommunityStatsSection(state = state, onRetry = viewModel::retry, onRefresh = viewModel::refresh)
    }
}

@Composable
internal fun CommunityChallengesScreen(onNavigateBack: () -> Unit) {
    CommunityPage(title = stringResource(R.string.community_challenges_title), onNavigateBack = onNavigateBack) {
        CommunityFeatureCard(
            icon = Icons.Rounded.EmojiEvents,
            eyebrow = stringResource(R.string.community_feed_weekly_challenge_badge),
            title = stringResource(R.string.community_feed_weekly_challenge_title),
            body = stringResource(R.string.community_feed_weekly_challenge_body),
            tint = MaterialTheme.colorScheme.secondaryContainer,
        )
        Text(
            text = stringResource(R.string.community_challenges_more),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
internal fun CommunityCirclesScreen(onNavigateBack: () -> Unit) {
    CommunityPage(title = stringResource(R.string.community_nav_circles), onNavigateBack = onNavigateBack) {
        CommunityFeatureCard(
            icon = Icons.Rounded.Groups,
            eyebrow = stringResource(R.string.community_feed_circles_title),
            title = stringResource(R.string.community_feed_circle_name),
            body = stringResource(R.string.community_feed_circle_status),
            tint = MaterialTheme.colorScheme.primaryContainer,
        )
    }
}

@Composable
internal fun CommunitySavedScreen(onNavigateBack: () -> Unit) {
    CommunityPage(title = stringResource(R.string.community_nav_saved), onNavigateBack = onNavigateBack) {
        CommunityFeatureCard(
            icon = Icons.Rounded.BookmarkBorder,
            eyebrow = stringResource(R.string.community_nav_saved),
            title = stringResource(R.string.community_saved_title),
            body = stringResource(R.string.community_saved_body),
            tint = MaterialTheme.colorScheme.surfaceContainerHigh,
        )
    }
}

@Composable
internal fun CommunityProfileScreen(onNavigateBack: () -> Unit) {
    CommunityPage(title = stringResource(R.string.community_profile_title), onNavigateBack = onNavigateBack) {
        Surface(
            modifier = Modifier.size(88.dp),
            shape = CircleShape,
            color = MaterialTheme.colorScheme.primaryContainer,
            contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
        ) { Box(contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Person, null, Modifier.size(42.dp)) } }
        Text(stringResource(R.string.community_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        CommunityFeatureCard(
            icon = Icons.Rounded.Verified,
            eyebrow = stringResource(R.string.community_profile_practice),
            title = stringResource(R.string.community_feed_suggested_goal_title),
            body = stringResource(R.string.community_profile_practice_body),
            tint = MaterialTheme.colorScheme.surfaceContainerHigh,
        )
    }
}

@Composable
internal fun CommunityPostDetailScreen(onNavigateBack: () -> Unit) {
    CommunityPage(title = stringResource(R.string.community_post_title), onNavigateBack = onNavigateBack) {
        CommunityFeatureCard(
            icon = Icons.Rounded.Verified,
            eyebrow = stringResource(R.string.community_feed_daily_dhikr_badge),
            title = stringResource(R.string.community_feed_daily_dhikr_transliteration),
            body = stringResource(R.string.community_post_reflection),
            tint = MaterialTheme.colorScheme.primaryContainer,
        )
        Text(
            text = stringResource(R.string.community_feed_daily_dhikr_arabic),
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = stringResource(R.string.community_feed_source_preview),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun CommunityPage(title: String, onNavigateBack: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp)) {
        IconButton(onClick = onNavigateBack) { Icon(Icons.Rounded.ArrowBack, contentDescription = null) }
        Text(title, style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(24.dp))
        Column(verticalArrangement = Arrangement.spacedBy(18.dp), content = content)
    }
}

@Composable
private fun CommunityFeatureCard(icon: androidx.compose.ui.graphics.vector.ImageVector, eyebrow: String, title: String, body: String, tint: androidx.compose.ui.graphics.Color) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        containerColor = communityCardContainerColor(tint),
    ) {
        Column(Modifier.padding(22.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(icon, contentDescription = null)
            Text(eyebrow, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(body, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
