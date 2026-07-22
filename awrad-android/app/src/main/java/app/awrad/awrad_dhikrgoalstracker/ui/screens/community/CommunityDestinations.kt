package app.awrad.awrad_dhikrgoalstracker.ui.screens.community

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import app.awrad.awrad_dhikrgoalstracker.ui.icons.phosphor.PhosphorRegular
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
import androidx.compose.ui.platform.LocalDensity
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
    val density = LocalDensity.current
    val statusBarTopPadding = with(density) { WindowInsets.statusBars.getTop(this).toDp() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(
                start = 20.dp,
                end = 20.dp,
                top = statusBarTopPadding + 8.dp,
                bottom = 32.dp,
            ),
    ) {
        IconButton(onClick = onNavigateBack) {
            Icon(
                imageVector = PhosphorRegular.ArrowLeft,
                contentDescription = stringResource(R.string.community_stats_back),
            )
        }
        Text(
            text = stringResource(R.string.community_nav_stats),
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            text = stringResource(R.string.community_stats_screen_subtitle),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(24.dp))
        CommunityStatsSection(
            state = state,
            onRetry = viewModel::retry,
            onRefresh = viewModel::refresh,
        )
    }
}

@Composable
internal fun CommunityChallengesScreen(onNavigateBack: () -> Unit) {
    CommunityPage(title = stringResource(R.string.community_challenges_title), onNavigateBack = onNavigateBack) {
        CommunityFeatureCard(
            icon = PhosphorRegular.Trophy,
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
            icon = PhosphorRegular.UsersThree,
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
            icon = PhosphorRegular.BookmarkSimple,
            eyebrow = stringResource(R.string.community_nav_saved),
            title = stringResource(R.string.community_saved_title),
            body = stringResource(R.string.community_saved_body),
            tint = MaterialTheme.colorScheme.surfaceContainerHigh,
        )
    }
}

@Composable
internal fun CommunityMessagesScreen(onNavigateBack: () -> Unit) {
    CommunityPage(title = stringResource(R.string.community_messages), onNavigateBack = onNavigateBack) {
        Text(
            text = stringResource(R.string.community_messages_subtitle),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        CommunityConversationRow(
            initials = stringResource(R.string.community_message_aisha_initials),
            name = stringResource(R.string.community_message_aisha_name),
            preview = stringResource(R.string.community_message_aisha_preview),
            time = stringResource(R.string.community_message_aisha_time),
            unread = true,
        )
        CommunityConversationRow(
            initials = stringResource(R.string.community_message_circle_initials),
            name = stringResource(R.string.community_message_circle_name),
            preview = stringResource(R.string.community_message_circle_preview),
            time = stringResource(R.string.community_message_circle_time),
            unread = true,
        )
        CommunityConversationRow(
            initials = stringResource(R.string.community_message_yusuf_initials),
            name = stringResource(R.string.community_message_yusuf_name),
            preview = stringResource(R.string.community_message_yusuf_preview),
            time = stringResource(R.string.community_message_yusuf_time),
            unread = false,
        )
    }
}

@Composable
internal fun CommunityNotificationsScreen(onNavigateBack: () -> Unit) {
    CommunityPage(title = stringResource(R.string.community_notifications), onNavigateBack = onNavigateBack) {
        Text(
            text = stringResource(R.string.community_notifications_subtitle),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        CommunityNotificationRow(
            title = stringResource(R.string.community_notification_goal_title),
            body = stringResource(R.string.community_notification_goal_body),
            time = stringResource(R.string.community_notification_goal_time),
            highlighted = true,
        )
        CommunityNotificationRow(
            title = stringResource(R.string.community_notification_invite_title),
            body = stringResource(R.string.community_notification_invite_body),
            time = stringResource(R.string.community_notification_invite_time),
            highlighted = true,
        )
        CommunityNotificationRow(
            title = stringResource(R.string.community_notification_encouragement_title),
            body = stringResource(R.string.community_notification_encouragement_body),
            time = stringResource(R.string.community_notification_encouragement_time),
            highlighted = false,
        )
    }
}

@Composable
private fun CommunityConversationRow(
    initials: String,
    name: String,
    preview: String,
    time: String,
    unread: Boolean,
) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        containerColor = communityCardContainerColor(),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                modifier = Modifier.size(52.dp),
                shape = CircleShape,
                color = MaterialTheme.colorScheme.primaryContainer,
                contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(initials, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                }
            }
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(3.dp))
                Text(
                    text = preview,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                )
            }
            Spacer(Modifier.width(10.dp))
            Column(horizontalAlignment = Alignment.End) {
                Text(time, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (unread) {
                    Spacer(Modifier.height(10.dp))
                    Surface(modifier = Modifier.size(9.dp), shape = CircleShape, color = MaterialTheme.colorScheme.primary) {}
                }
            }
        }
    }
}

@Composable
private fun CommunityNotificationRow(
    title: String,
    body: String,
    time: String,
    highlighted: Boolean,
) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        containerColor = communityCardContainerColor(
            if (highlighted) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f)
            else MaterialTheme.colorScheme.surface,
        ),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(18.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Surface(
                modifier = Modifier.size(44.dp),
                shape = CircleShape,
                color = MaterialTheme.colorScheme.secondaryContainer,
                contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(PhosphorRegular.Bell, contentDescription = null, modifier = Modifier.size(22.dp))
                }
            }
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(4.dp))
                Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(8.dp))
                Text(time, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            }
        }
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
        ) { Box(contentAlignment = Alignment.Center) { Icon(PhosphorRegular.User, null, Modifier.size(42.dp)) } }
        Text(stringResource(R.string.community_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        CommunityFeatureCard(
            icon = PhosphorRegular.SealCheck,
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
            icon = PhosphorRegular.SealCheck,
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
    val density = LocalDensity.current
    val statusBarTopPadding = with(density) { WindowInsets.statusBars.getTop(this).toDp() }
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, top = statusBarTopPadding + 8.dp, bottom = 20.dp),
    ) {
        IconButton(onClick = onNavigateBack) {
            Icon(
                PhosphorRegular.ArrowLeft,
                contentDescription = stringResource(R.string.community_stats_back),
            )
        }
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
