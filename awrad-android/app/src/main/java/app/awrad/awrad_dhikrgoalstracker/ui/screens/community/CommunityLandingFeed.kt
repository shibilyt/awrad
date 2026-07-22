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
import app.awrad.awrad_dhikrgoalstracker.ui.icons.phosphor.PhosphorRegular
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard

@Composable
internal fun CommunityLandingFeed(
    onUnavailableAction: () -> Unit,
    onOpenPost: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        DailyDhikrPost(
            onStart = onOpenPost,
            onSave = onUnavailableAction,
        )

        SuggestedGoalPost(onCreateGoal = onUnavailableAction)

        FeedSectionHeader(
            title = stringResource(R.string.community_feed_circles_title),
            action = stringResource(R.string.community_feed_manage),
            onAction = onUnavailableAction,
        )
        CirclesPreview(onOpenCircles = onUnavailableAction)
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
        TextButton(onClick = onAction) {
            Text(action)
        }
    }
}

@Composable
private fun DailyDhikrPost(
    onStart: () -> Unit,
    onSave: () -> Unit,
) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(22.dp),
        containerColor = communityCardContainerColor(),
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(22.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                FeedPostHeader(
                    context = stringResource(R.string.community_feed_daily_dhikr_badge),
                    icon = PhosphorRegular.SealCheck,
                    onSave = onSave,
                )
                IconButton(onClick = onSave) {
                    Icon(
                        imageVector = PhosphorRegular.BookmarkSimple,
                        contentDescription = stringResource(R.string.community_feed_save),
                    )
                }
            }
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
            FeedEngagementRow(onSave = onSave)
        }
    }
}

@Composable
private fun SuggestedGoalPost(onCreateGoal: () -> Unit) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(22.dp),
        containerColor = communityCardContainerColor(),
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(22.dp)) {
            FeedPostHeader(
                context = stringResource(R.string.community_feed_suggested_goal_badge),
                icon = PhosphorRegular.Target,
                onSave = onCreateGoal,
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
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CommunityMetadataPill(stringResource(R.string.community_feed_daily))
                    CommunityMetadataPill(stringResource(R.string.community_feed_seven_days))
                }
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
            FeedEngagementRow(onSave = onCreateGoal)
        }
    }
}

@Composable
private fun CirclesPreview(onOpenCircles: () -> Unit) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onOpenCircles,
        shape = RoundedCornerShape(22.dp),
        containerColor = communityCardContainerColor(),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(22.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                modifier = Modifier.size(54.dp),
                shape = CircleShape,
                color = MaterialTheme.colorScheme.primaryContainer,
                contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(PhosphorRegular.UsersThree, contentDescription = null)
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.community_feed_circle_name),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(5.dp))
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
private fun FeedPostHeader(
    context: String,
    icon: ImageVector,
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
                tint = contentColor,
            )
        }
    }
}

@Composable
private fun FeedEngagementRow(
    onSave: () -> Unit,
    contentColor: Color = MaterialTheme.colorScheme.onSurfaceVariant,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onSave) {
            Icon(PhosphorRegular.Heart, contentDescription = null, tint = contentColor)
        }
        IconButton(onClick = onSave) {
            Icon(PhosphorRegular.ChatCircle, contentDescription = null, tint = contentColor)
        }
        IconButton(onClick = onSave) {
            Icon(PhosphorRegular.ShareNetwork, contentDescription = null, tint = contentColor)
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
