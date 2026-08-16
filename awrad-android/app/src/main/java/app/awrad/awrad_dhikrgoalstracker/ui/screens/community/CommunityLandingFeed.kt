package app.awrad.awrad_dhikrgoalstracker.ui.screens.community

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.icons.phosphor.PhosphorRegular

@Composable
internal fun CommunityLandingFeed(
    onOpenPost: () -> Unit,
    onNavigateToCreateGoal: () -> Unit,
    onNavigateToCircles: () -> Unit,
    onShowMessage: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var dailySaved by rememberSaveable { mutableStateOf(false) }
    var dailyLiked by rememberSaveable { mutableStateOf(false) }
    var goalSaved by rememberSaveable { mutableStateOf(false) }
    var goalLiked by rememberSaveable { mutableStateOf(false) }
    val postSavedMessage = stringResource(R.string.community_feed_post_saved)
    val postUnsavedMessage = stringResource(R.string.community_feed_post_unsaved)
    val shareMessage = stringResource(R.string.community_feed_share_coming_soon)

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        CommunityWelcomeHero(onExplore = onNavigateToCircles)

        FeedSectionHeader(
            title = stringResource(R.string.community_feed_today_title),
            action = stringResource(R.string.community_feed_see_all),
            onAction = onOpenPost,
        )
        DailyDhikrPost(
            isSaved = dailySaved,
            isLiked = dailyLiked,
            onStart = onOpenPost,
            onSave = {
                dailySaved = !dailySaved
                onShowMessage(if (dailySaved) postSavedMessage else postUnsavedMessage)
            },
            onLike = { dailyLiked = !dailyLiked },
            onShare = { onShowMessage(shareMessage) },
        )

        FeedSectionHeader(
            title = stringResource(R.string.community_feed_suggested_title),
            action = stringResource(R.string.community_feed_see_all),
            onAction = onNavigateToCreateGoal,
        )
        SuggestedGoalPost(
            isSaved = goalSaved,
            isLiked = goalLiked,
            onCreateGoal = onNavigateToCreateGoal,
            onSave = {
                goalSaved = !goalSaved
                onShowMessage(if (goalSaved) postSavedMessage else postUnsavedMessage)
            },
            onLike = { goalLiked = !goalLiked },
            onShare = { onShowMessage(shareMessage) },
        )

        FeedSectionHeader(
            title = stringResource(R.string.community_feed_circles_title),
            action = stringResource(R.string.community_feed_see_all),
            onAction = onNavigateToCircles,
        )
        CommunityCirclePreview(onOpen = onNavigateToCircles)
    }
}

@Composable
internal fun CommunityExploreFeed(
    onOpenPost: () -> Unit,
    onNavigateToChallenges: () -> Unit,
    onNavigateToCircles: () -> Unit,
    onShowMessage: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var postSaved by rememberSaveable { mutableStateOf(false) }
    var postLiked by rememberSaveable { mutableStateOf(false) }
    val postSavedMessage = stringResource(R.string.community_feed_post_saved)
    val postUnsavedMessage = stringResource(R.string.community_feed_post_unsaved)
    val shareMessage = stringResource(R.string.community_feed_share_coming_soon)

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        CommunityExploreHero(onExploreCircles = onNavigateToCircles)
        WeeklyChallengeCard(onOpenChallenge = onNavigateToChallenges)

        FeedSectionHeader(
            title = stringResource(R.string.community_feed_circles_title),
            action = stringResource(R.string.community_feed_see_all),
            onAction = onNavigateToCircles,
        )
        ExploreCirclePreview(
            onOpen = onNavigateToCircles,
            onShowMessage = onShowMessage,
        )

        FeedSectionHeader(
            title = stringResource(R.string.community_feed_today_title),
            action = stringResource(R.string.community_feed_see_all),
            onAction = onOpenPost,
        )
        DailyDhikrPost(
            isSaved = postSaved,
            isLiked = postLiked,
            onStart = onOpenPost,
            onSave = {
                postSaved = !postSaved
                onShowMessage(if (postSaved) postSavedMessage else postUnsavedMessage)
            },
            onLike = { postLiked = !postLiked },
            onShare = { onShowMessage(shareMessage) },
        )
    }
}

@Composable
internal fun CommunityGoalsFeed(
    onNavigateToCreateGoal: () -> Unit,
    onNavigateToChallenges: () -> Unit,
    onShowMessage: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var suggestedGoalSaved by rememberSaveable { mutableStateOf(false) }
    var suggestedGoalLiked by rememberSaveable { mutableStateOf(false) }
    val postSavedMessage = stringResource(R.string.community_feed_post_saved)
    val postUnsavedMessage = stringResource(R.string.community_feed_post_unsaved)
    val shareMessage = stringResource(R.string.community_feed_share_coming_soon)

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        CommunityGoalsHero()
        GoalProgressCard(onOpenGoal = onNavigateToCreateGoal)
        SuggestedGoalPost(
            isSaved = suggestedGoalSaved,
            isLiked = suggestedGoalLiked,
            onCreateGoal = onNavigateToCreateGoal,
            onSave = {
                suggestedGoalSaved = !suggestedGoalSaved
                onShowMessage(if (suggestedGoalSaved) postSavedMessage else postUnsavedMessage)
            },
            onLike = { suggestedGoalLiked = !suggestedGoalLiked },
            onShare = { onShowMessage(shareMessage) },
        )
        WeeklyChallengeCard(onOpenChallenge = onNavigateToChallenges)
    }
}

@Composable
private fun CommunityWelcomeHero(onExplore: () -> Unit) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(28.dp),
        containerColor = MaterialTheme.colorScheme.primaryContainer,
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(22.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                CommunityBadge(
                    text = stringResource(R.string.community_feed_together_badge),
                    icon = PhosphorRegular.UsersThree,
                )
                Icon(PhosphorRegular.SealCheck, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
            Spacer(Modifier.height(18.dp))
            Text(
                text = stringResource(R.string.community_feed_together_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.community_feed_together_body),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(18.dp))
            Button(onClick = onExplore, modifier = Modifier.fillMaxWidth().height(50.dp)) {
                Text(stringResource(R.string.community_feed_explore))
                Spacer(Modifier.width(8.dp))
                Icon(PhosphorRegular.CaretRight, contentDescription = null)
            }
        }
    }
}

@Composable
private fun CommunityExploreHero(onExploreCircles: () -> Unit) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(28.dp),
        containerColor = communityCardContainerColor(MaterialTheme.colorScheme.surfaceContainerLow),
        showBorder = true,
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(22.dp)) {
            Text(
                text = stringResource(R.string.community_feed_explore),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.community_feed_together_body),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(18.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CommunityMetadataPill(stringResource(R.string.community_nav_circles))
                CommunityMetadataPill(stringResource(R.string.community_nav_challenges))
                CommunityMetadataPill(stringResource(R.string.community_nav_stats))
            }
            Spacer(Modifier.height(18.dp))
            TextButton(onClick = onExploreCircles) {
                Text(stringResource(R.string.community_nav_circles))
                Spacer(Modifier.width(6.dp))
                Icon(PhosphorRegular.CaretRight, contentDescription = null)
            }
        }
    }
}

@Composable
private fun CommunityGoalsHero() {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(28.dp),
        containerColor = MaterialTheme.colorScheme.secondaryContainer,
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(22.dp)) {
            CommunityBadge(
                text = stringResource(R.string.community_tab_goals),
                icon = PhosphorRegular.Target,
            )
            Spacer(Modifier.height(16.dp))
            Text(
                text = stringResource(R.string.community_feed_suggested_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.community_feed_suggested_goal_body),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun GoalProgressCard(onOpenGoal: () -> Unit) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        containerColor = communityCardContainerColor(),
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(22.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.community_feed_active_goal_badge),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                )
                Icon(PhosphorRegular.Target, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
            Spacer(Modifier.height(12.dp))
            Text(
                text = stringResource(R.string.community_feed_suggested_goal_title),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(5.dp))
            Text(
                text = stringResource(R.string.community_feed_progress, 42, 70),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(13.dp))
            LinearProgressIndicator(
                progress = { 42f / 70f },
                modifier = Modifier.fillMaxWidth().height(8.dp),
            )
            Spacer(Modifier.height(15.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.community_feed_challenge_streak, 3),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
                TextButton(onClick = onOpenGoal) {
                    Text(stringResource(R.string.community_feed_create_goal))
                }
            }
        }
    }
}

@Composable
private fun FeedSectionHeader(
    title: String,
    action: String,
    onAction: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        TextButton(onClick = onAction) { Text(action) }
    }
}

@Composable
private fun DailyDhikrPost(
    isSaved: Boolean,
    isLiked: Boolean,
    onStart: () -> Unit,
    onSave: () -> Unit,
    onLike: () -> Unit,
    onShare: () -> Unit,
) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        containerColor = communityCardContainerColor(),
        showBorder = true,
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(22.dp)) {
            FeedPostHeader(
                context = stringResource(R.string.community_feed_daily_dhikr_badge),
                icon = PhosphorRegular.SealCheck,
                isSaved = isSaved,
                onSave = onSave,
            )
            Spacer(Modifier.height(18.dp))
            Text(
                text = stringResource(R.string.community_feed_daily_dhikr_arabic),
                modifier = Modifier.fillMaxWidth(),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(10.dp))
            Text(
                text = stringResource(R.string.community_feed_daily_dhikr_transliteration),
                modifier = Modifier.fillMaxWidth(),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = stringResource(R.string.community_feed_daily_dhikr_meaning),
                modifier = Modifier.fillMaxWidth(),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(18.dp))
            Surface(
                modifier = Modifier.fillMaxWidth(),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                shape = RoundedCornerShape(18.dp),
            ) {
                Text(
                    text = stringResource(R.string.community_feed_source_preview),
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.height(18.dp))
            Button(
                onClick = onStart,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(18.dp),
            ) {
                Icon(PhosphorRegular.Play, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.community_feed_start_dhikr))
            }
            FeedEngagementRow(
                isLiked = isLiked,
                isSaved = isSaved,
                onLike = onLike,
                onSave = onSave,
                onShare = onShare,
            )
        }
    }
}

@Composable
private fun SuggestedGoalPost(
    isSaved: Boolean,
    isLiked: Boolean,
    onCreateGoal: () -> Unit,
    onSave: () -> Unit,
    onLike: () -> Unit,
    onShare: () -> Unit,
) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        containerColor = communityCardContainerColor(),
        showBorder = true,
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(22.dp)) {
            FeedPostHeader(
                context = stringResource(R.string.community_feed_suggested_goal_badge),
                icon = PhosphorRegular.Target,
                isSaved = isSaved,
                onSave = onSave,
            )
            Spacer(Modifier.height(18.dp))
            Text(
                text = stringResource(R.string.community_feed_suggested_goal_title),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.community_feed_suggested_goal_body),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CommunityMetadataPill(stringResource(R.string.community_feed_daily))
                CommunityMetadataPill(stringResource(R.string.community_feed_seven_days))
                CommunityMetadataPill(stringResource(R.string.community_feed_private))
            }
            Spacer(Modifier.height(18.dp))
            Button(
                onClick = onCreateGoal,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(18.dp),
            ) {
                Text(stringResource(R.string.community_feed_create_goal))
            }
            FeedEngagementRow(
                isLiked = isLiked,
                isSaved = isSaved,
                onLike = onLike,
                onSave = onSave,
                onShare = onShare,
            )
        }
    }
}

@Composable
private fun WeeklyChallengeCard(onOpenChallenge: () -> Unit) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        containerColor = MaterialTheme.colorScheme.tertiaryContainer,
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(22.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CommunityBadge(
                    text = stringResource(R.string.community_feed_weekly_challenge_badge),
                    icon = PhosphorRegular.Trophy,
                )
                Icon(PhosphorRegular.Trophy, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
            Spacer(Modifier.height(16.dp))
            Text(
                text = stringResource(R.string.community_feed_weekly_challenge_title),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = stringResource(R.string.community_feed_weekly_challenge_body),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(15.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CommunityMetadataPill(stringResource(R.string.community_feed_weekly_challenge_progress))
                CommunityMetadataPill(stringResource(R.string.community_feed_challenge_streak, 3))
            }
            Spacer(Modifier.height(17.dp))
            Button(onClick = onOpenChallenge, modifier = Modifier.fillMaxWidth().height(50.dp)) {
                Text(stringResource(R.string.community_feed_view_challenge))
                Spacer(Modifier.width(8.dp))
                Icon(PhosphorRegular.CaretRight, contentDescription = null)
            }
        }
    }
}

@Composable
private fun CommunityCirclePreview(onOpen: () -> Unit) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onOpen,
        shape = RoundedCornerShape(22.dp),
        containerColor = communityCardContainerColor(),
        showBorder = true,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(20.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CommunityCircleIcon()
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.community_feed_circle_name),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = stringResource(R.string.community_feed_circle_status),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(10.dp))
                LinearProgressIndicator(
                    progress = { 0.67f },
                    modifier = Modifier.fillMaxWidth().height(6.dp),
                )
            }
            Icon(
                imageVector = PhosphorRegular.CaretRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun ExploreCirclePreview(
    onOpen: () -> Unit,
    onShowMessage: (String) -> Unit,
) {
    val joinedMessage = stringResource(R.string.community_feed_circle_joined)

    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onOpen,
        shape = RoundedCornerShape(22.dp),
        containerColor = communityCardContainerColor(),
        showBorder = true,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(20.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CommunityCircleIcon()
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.community_feed_morning_circle_name),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = stringResource(R.string.community_feed_morning_circle_status),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            TextButton(onClick = { onShowMessage(joinedMessage) }) {
                Text(stringResource(R.string.community_feed_circle_join))
            }
        }
    }
}

@Composable
private fun CommunityCircleIcon() {
    Surface(
        modifier = Modifier.size(52.dp),
        shape = CircleShape,
        color = MaterialTheme.colorScheme.primaryContainer,
        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(PhosphorRegular.UsersThree, contentDescription = null)
        }
    }
}

@Composable
private fun FeedPostHeader(
    context: String,
    icon: ImageVector,
    isSaved: Boolean,
    onSave: () -> Unit,
    contentColor: Color = MaterialTheme.colorScheme.onSurface,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Surface(
            modifier = Modifier.size(38.dp),
            shape = CircleShape,
            color = contentColor.copy(alpha = 0.16f),
            contentColor = contentColor,
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(icon, contentDescription = null, modifier = Modifier.size(19.dp))
            }
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = stringResource(R.string.community_title),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
                color = contentColor,
            )
            Text(
                text = context,
                style = MaterialTheme.typography.labelMedium,
                color = contentColor.copy(alpha = 0.78f),
            )
        }
        IconButton(onClick = onSave) {
            Icon(
                imageVector = PhosphorRegular.BookmarkSimple,
                contentDescription = stringResource(R.string.community_feed_save),
                tint = if (isSaved) MaterialTheme.colorScheme.primary else contentColor,
            )
        }
    }
}

@Composable
private fun FeedEngagementRow(
    isLiked: Boolean,
    isSaved: Boolean,
    onLike: () -> Unit,
    onSave: () -> Unit,
    onShare: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(top = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onLike) {
            Icon(
                PhosphorRegular.Heart,
                contentDescription = stringResource(R.string.community_feed_like),
                tint = if (isLiked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        IconButton(onClick = onSave) {
            Icon(
                PhosphorRegular.BookmarkSimple,
                contentDescription = stringResource(R.string.community_feed_save),
                tint = if (isSaved) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        IconButton(onClick = onShare) {
            Icon(
                PhosphorRegular.ShareNetwork,
                contentDescription = stringResource(R.string.community_feed_share),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun CommunityBadge(
    text: String,
    icon: ImageVector,
) {
    Surface(
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.72f),
        contentColor = MaterialTheme.colorScheme.onSurface,
        shape = CircleShape,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 11.dp, vertical = 7.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(16.dp))
            Text(text, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun CommunityMetadataPill(text: String) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
        contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
        shape = CircleShape,
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp),
            style = MaterialTheme.typography.labelSmall,
            maxLines = 1,
        )
    }
}
