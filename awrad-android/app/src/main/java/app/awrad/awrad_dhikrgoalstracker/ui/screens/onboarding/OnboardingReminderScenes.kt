package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.components.ReminderReliabilityPolicy
import app.awrad.awrad_dhikrgoalstracker.ui.components.ReminderReliabilityUiState
import app.awrad.awrad_dhikrgoalstracker.ui.components.oemBatteryName
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

// ─── Notifications Scene ─────────────────────────────────────────────────────

internal fun isNotificationPermissionGranted(context: android.content.Context): Boolean =
    Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED

@Composable
internal fun NotificationsScene(
    notificationsGranted: Boolean,
    reliability: ReminderReliabilityUiState,
    onPermissionResult: (Boolean) -> Unit,
    onOpenExactAlarmSettings: () -> Unit,
    onOpenBatterySettings: () -> Unit,
    onShowOemGuide: () -> Unit,
) {
    val context = LocalContext.current

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        onPermissionResult(granted)
    }

    LaunchedEffect(Unit) {
        onPermissionResult(isNotificationPermissionGranted(context))
    }

    val requiredActions = ReminderReliabilityPolicy.requiredSystemActions(reliability)
    val showOemGuide = ReminderReliabilityPolicy.shouldShowOemGuide(reliability)
    val allReliable = requiredActions.isEmpty() && !showOemGuide

    OnboardingScene(
        icon = {
            ReminderReliabilityGlyph(
                ready = notificationsGranted,
                modifier = Modifier.size(108.dp),
            )
        },
        title = stringResource(R.string.onboarding_notifications_title),
        subtitle = stringResource(R.string.onboarding_notifications_subtitle),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (notificationsGranted) {
                ReadyCard(
                    title = stringResource(R.string.onboarding_notifications_ready_title),
                    body = stringResource(R.string.onboarding_notifications_ready_desc),
                )
            } else {
                Button(
                    onClick = {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else {
                            onPermissionResult(true)
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(54.dp),
                    shape = RoundedCornerShape(20.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = greenAccent(),
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                    ),
                ) {
                    Icon(
                        imageVector = Icons.Filled.NotificationsActive,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = stringResource(R.string.onboarding_notifications_enable),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }

                Text(
                    text = stringResource(R.string.onboarding_notifications_hint),
                    modifier = Modifier.fillMaxWidth(),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // The quiet plumbing that makes reminders actually arrive on time.
            if (!reliability.canScheduleExactAlarms) {
                ReliabilityActionCard(
                    icon = Icons.Outlined.Schedule,
                    title = stringResource(R.string.settings_exact_alarm_status),
                    body = stringResource(R.string.settings_exact_alarm_needs_attention_sub),
                    buttonText = stringResource(R.string.onboarding_reliability_exact_action),
                    onClick = onOpenExactAlarmSettings,
                )
            }

            if (!reliability.isIgnoringBatteryOptimizations) {
                ReliabilityActionCard(
                    icon = Icons.Filled.Notifications,
                    title = stringResource(R.string.settings_battery_optimization_status),
                    body = stringResource(R.string.settings_battery_optimized_sub),
                    buttonText = stringResource(R.string.onboarding_reliability_battery_action),
                    onClick = onOpenBatterySettings,
                )
            }

            reliability.oemBatteryInfo?.let { info ->
                ReliabilityActionCard(
                    icon = Icons.Filled.Info,
                    title = stringResource(R.string.settings_oem_battery_guide_title, oemBatteryName(info.type)),
                    body = stringResource(R.string.settings_oem_battery_guide_sub),
                    buttonText = stringResource(R.string.onboarding_reliability_oem_action),
                    onClick = onShowOemGuide,
                )
            }

            if (notificationsGranted && allReliable) {
                ReadyCard(
                    title = stringResource(R.string.onboarding_reliability_ready_title),
                    body = stringResource(R.string.onboarding_reliability_ready_desc),
                )
            }
        }
    }
}

@Composable
internal fun ReminderReliabilityGlyph(
    ready: Boolean,
    modifier: Modifier = Modifier,
) {
    val accent = if (ready) greenAccent() else greenAccent()
    val soft = if (ready) greenContainerColor() else greenAccent().copy(alpha = 0.18f)

    Box(
        modifier = modifier
            .clip(CircleShape)
            .background(soft),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = if (ready) Icons.Filled.CheckCircle else Icons.Filled.Notifications,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = accent,
        )
    }
}

@Composable
internal fun ReliabilityActionCard(
    icon: ImageVector,
    title: String,
    body: String,
    buttonText: String,
    onClick: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.24f)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top,
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(greenContainerColor()),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        modifier = Modifier.size(22.dp),
                        tint = onGreenContainerColor(),
                    )
                }
                Spacer(modifier = Modifier.width(14.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = body,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            Button(
                onClick = onClick,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = greenAccent(),
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            ) {
                Text(
                    text = buttonText,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
internal fun ReadyCard(
    title: String,
    body: String,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        color = greenContainerColor(),
        border = BorderStroke(1.dp, greenAccent().copy(alpha = 0.28f)),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(greenAccent()),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    modifier = Modifier.size(22.dp),
                    tint = MaterialTheme.colorScheme.onPrimary,
                )
            }
            Spacer(modifier = Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = onGreenContainerColor(),
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = body,
                    style = MaterialTheme.typography.bodyMedium,
                    color = onGreenContainerColor().copy(alpha = 0.8f),
                )
            }
        }
    }
}

// ─── Reminder Presets Scene ──────────────────────────────────────────────────

private data class ReminderPresetUi(
    val preset: OnboardingReminderPreset,
    val titleRes: Int,
    val descRes: Int,
)

private val reminderPresetUis = listOf(
    ReminderPresetUi(
        preset = OnboardingReminderPreset.AFTER_FAJR,
        titleRes = R.string.onboarding_reminder_after_fajr,
        descRes = R.string.onboarding_reminder_after_fajr_desc,
    ),
    ReminderPresetUi(
        preset = OnboardingReminderPreset.MORNING,
        titleRes = R.string.onboarding_reminder_morning,
        descRes = R.string.onboarding_reminder_morning_desc,
    ),
    ReminderPresetUi(
        preset = OnboardingReminderPreset.AFTER_ASR,
        titleRes = R.string.onboarding_reminder_after_asr,
        descRes = R.string.onboarding_reminder_after_asr_desc,
    ),
    ReminderPresetUi(
        preset = OnboardingReminderPreset.AFTER_MAGHRIB,
        titleRes = R.string.onboarding_reminder_after_maghrib,
        descRes = R.string.onboarding_reminder_after_maghrib_desc,
    ),
)

@Composable
internal fun ReminderPresetsScene(
    selectedPresets: Set<OnboardingReminderPreset>,
    presetTimes: Map<OnboardingReminderPreset, String>,
    onPresetToggled: (OnboardingReminderPreset) -> Unit,
) {
    OnboardingScene(
        icon = {
            DayArcGlyph(
                highlighted = selectedPresets.map { it.ordinal }.toSet(),
                modifier = Modifier.size(116.dp),
            )
        },
        title = stringResource(R.string.onboarding_reminders_title),
        subtitle = stringResource(R.string.onboarding_reminders_subtitle),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            reminderPresetUis.forEach { ui ->
                ReminderPresetCard(
                    title = stringResource(ui.titleRes),
                    description = stringResource(ui.descRes),
                    time = presetTimes[ui.preset],
                    selected = ui.preset in selectedPresets,
                    onClick = { onPresetToggled(ui.preset) },
                )
            }

            Text(
                text = stringResource(R.string.onboarding_reminders_hint),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 4.dp),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun ReminderPresetCard(
    title: String,
    description: String,
    time: String?,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val borderColor by animateColorAsState(
        targetValue = if (selected) greenAccent() else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.36f),
        animationSpec = tween(180),
        label = "presetBorder",
    )
    val scale by animateFloatAsState(
        targetValue = if (selected) 1f else 0.98f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "presetScale",
    )

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { scaleX = scale; scaleY = scale },
        shape = RoundedCornerShape(22.dp),
        color = if (selected) greenContainerColor() else MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(if (selected) 2.dp else 1.dp, borderColor),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OnboardingSelectionDot(selected = selected)

            Spacer(modifier = Modifier.width(14.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            if (time != null) {
                Spacer(modifier = Modifier.width(10.dp))
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = if (selected) {
                        greenAccent().copy(alpha = 0.16f)
                    } else {
                        MaterialTheme.colorScheme.surfaceContainerHighest
                    },
                ) {
                    Text(
                        text = time,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = if (selected) greenAccent() else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

/**
 * A sun-path arc across the day with a marker for each of the four reminder
 * moments; selected moments light up in the accent color.
 */
@Composable
private fun DayArcGlyph(
    highlighted: Set<Int>,
    modifier: Modifier = Modifier,
) {
    val accent = greenAccent()
    val soft = greenContainerColor()
    val track = MaterialTheme.colorScheme.outlineVariant

    Canvas(modifier = modifier) {
        val center = Offset(size.width / 2f, size.height * 0.78f)
        val radius = size.minDimension * 0.52f

        drawCircle(color = soft, radius = size.minDimension * 0.46f, center = Offset(size.width / 2f, size.height / 2f))

        // Horizon
        drawLine(
            color = accent.copy(alpha = 0.35f),
            start = Offset(center.x - radius - 4.dp.toPx(), center.y),
            end = Offset(center.x + radius + 4.dp.toPx(), center.y),
            strokeWidth = 2.dp.toPx(),
            cap = StrokeCap.Round,
        )

        // Sun path
        drawArc(
            color = accent.copy(alpha = 0.5f),
            startAngle = 180f,
            sweepAngle = 180f,
            useCenter = false,
            topLeft = Offset(center.x - radius, center.y - radius),
            size = androidx.compose.ui.geometry.Size(radius * 2f, radius * 2f),
            style = Stroke(width = 2.5.dp.toPx(), cap = StrokeCap.Round),
        )

        // Four moments along the arc: dawn, morning, late afternoon, sunset.
        val momentAngles = listOf(196f, 224f, 306f, 344f)
        momentAngles.forEachIndexed { index, angleDeg ->
            val rad = angleDeg * PI.toFloat() / 180f
            val point = Offset(
                x = center.x + radius * cos(rad),
                y = center.y + radius * sin(rad),
            )
            val isLit = index in highlighted
            if (isLit) {
                drawCircle(color = accent.copy(alpha = 0.28f), radius = 8.dp.toPx(), center = point)
            }
            drawCircle(
                color = if (isLit) accent else track,
                radius = if (isLit) 5.dp.toPx() else 3.5.dp.toPx(),
                center = point,
            )
        }
    }
}
