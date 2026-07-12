package app.awrad.awrad_dhikrgoalstracker.ui.screens.home

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.components.DayProgressRing
import app.awrad.awrad_dhikrgoalstracker.ui.components.GoalStreakChip
import app.awrad.awrad_dhikrgoalstracker.ui.components.FeaturedCollectionsSection
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualPrimaryButton
import app.awrad.awrad_dhikrgoalstracker.ui.screens.wird.WirdCatalogCard
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.LocalDate

@Composable
fun HomeScreen(
    onNavigateToGoal: (Long) -> Unit,
    onNavigateToCreateGoal: () -> Unit,
    onNavigateToGoals: () -> Unit = {},
    onNavigateToCategory: (String) -> Unit = {},
    onNavigateToSettings: () -> Unit = {},
    onNavigateToLibrary: () -> Unit = {},
    onNavigateToWirdList: () -> Unit = {},
    onNavigateToWirdReader: (wirdId: String, partId: String) -> Unit = { _, _ -> },
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val uiState = viewModel.uiState.collectAsStateWithLifecycle().value
    val prayerCardState = viewModel.prayerCardState.collectAsStateWithLifecycle().value
    val wirdHome = viewModel.wirdHome.collectAsStateWithLifecycle().value
    val now by rememberHomeNow()
    val visuals = resolveHomeVisuals(
        now = now,
        prayerState = prayerCardState,
        isDarkTheme = isAwradDarkTheme(),
    )
    val primaryGoal = uiState.suggestedGoal ?: uiState.activeGoals.firstOrNull()
    val density = LocalDensity.current
    val statusBarTopPadding = with(density) { WindowInsets.statusBars.getTop(this).toDp() }

    val context = LocalContext.current
    val locationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            detectLocationOrFallback(context, viewModel, onNavigateToSettings)
        } else {
            onNavigateToSettings()
        }
    }
    val enablePrayerTimes = {
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (hasPermission) {
            detectLocationOrFallback(context, viewModel, onNavigateToSettings)
        } else {
            locationPermissionLauncher.launch(Manifest.permission.ACCESS_COARSE_LOCATION)
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = statusBarTopPadding + 22.dp, bottom = 112.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                HomeHeader(
                    primaryDate = uiState.primaryDate,
                    secondaryDate = uiState.secondaryDate,
                    visuals = visuals,
                    onNavigateToSettings = onNavigateToSettings,
                )
            }

            item {
                if (primaryGoal != null) {
                    ContinueDhikrCard(
                        goal = primaryGoal,
                        visuals = visuals,
                        onClick = { onNavigateToGoal(primaryGoal.goal.id) },
                    )
                } else {
                    EmptyHomeStartCard(
                        visuals = visuals,
                        onClick = onNavigateToCreateGoal,
                    )
                }
            }

            if (prayerCardState.isVisible) {
                item {
                    PrayerRhythmCard(
                        state = prayerCardState,
                        visuals = visuals,
                        onClick = onNavigateToSettings,
                    )
                }
            } else {
                item {
                    PrayerTimesPromptCard(
                        visuals = visuals,
                        onEnable = enablePrayerTimes,
                    )
                }
            }

            if (uiState.activeGoals.isNotEmpty()) {
                item {
                    TodayGoalsSection(
                        goals = uiState.activeGoals.take(3),
                        visuals = visuals,
                        onGoalClick = { onNavigateToGoal(it.goal.id) },
                        onViewAll = onNavigateToGoals,
                    )
                }
            }

            item {
                FeaturedCollectionsSection(
                    categoryCounts = uiState.categoryDhikrCounts,
                    onCollectionClick = { onNavigateToCategory(it.name) },
                    onViewAll = onNavigateToLibrary,
                )
            }

            if (wirdHome.featured.isNotEmpty()) {
                item {
                    WirdsSection(
                        state = wirdHome,
                        onOpenReader = onNavigateToWirdReader,
                        onSeeAll = onNavigateToWirdList,
                    )
                }
            }
        }
    }
}

@Composable
private fun WirdsSection(
    state: WirdHomeUi,
    onOpenReader: (wirdId: String, partId: String) -> Unit,
    onSeeAll: () -> Unit,
) {
    Column(Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 22.dp, end = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.wird_tab_featured),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
            )
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .clickable(onClick = onSeeAll)
                    .padding(start = 8.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.home_view_all),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary,
                )
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp),
                )
            }
        }

        Spacer(Modifier.height(14.dp))

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            state.featured.take(4).forEach { card ->
                WirdCatalogCard(
                    wird = card.wird,
                    isActiveToday = card.isActiveToday,
                    progress = card.progress,
                    onClick = { card.part?.let { onOpenReader(card.wird.id, it.id) } },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@Composable
private fun rememberHomeNow() = produceState(initialValue = Instant.now()) {
    while (true) {
        value = Instant.now()
        val nextMinuteDelay = 60_000L - (System.currentTimeMillis() % 60_000L)
        delay(nextMinuteDelay)
    }
}

@Composable
private fun HomeHeader(
    primaryDate: String,
    secondaryDate: String,
    visuals: HomeVisuals,
    onNavigateToSettings: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 22.dp, end = 18.dp),
    ) {
        Column(
            modifier = Modifier.align(Alignment.CenterStart),
        ) {
            Text(
                text = stringResource(R.string.home_today),
                style = MaterialTheme.typography.displayMedium,
                fontWeight = FontWeight.Bold,
                color = visuals.primaryTextColor,
                maxLines = 1,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = primaryDate,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = visuals.primaryTextColor.copy(alpha = if (visuals.isDarkTheme) 0.84f else 0.92f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (secondaryDate.isNotBlank()) {
                Text(
                    text = secondaryDate,
                    style = MaterialTheme.typography.titleSmall,
                    color = visuals.secondaryTextColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 3.dp),
                )
            }
        }
        Surface(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .size(56.dp),
            shape = CircleShape,
            color = visuals.chipColor.copy(alpha = if (visuals.isDarkTheme) 0.68f else 0.78f),
        ) {
            IconButton(onClick = onNavigateToSettings) {
                Icon(
                    imageVector = Icons.Filled.Tune,
                    contentDescription = stringResource(R.string.settings_title),
                    tint = visuals.chipContentColor,
                )
            }
        }
    }
}

@Composable
private fun HomeCardSurface(
    visuals: HomeVisuals,
    modifier: Modifier = Modifier,
    shape: RoundedCornerShape = RoundedCornerShape(24.dp),
    color: Color = visuals.cardColor,
    showBorder: Boolean = false,
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    Surface(
        modifier = modifier.then(
            if (onClick != null) Modifier.clickable { onClick() } else Modifier,
        ),
        shape = shape,
        color = color,
        border = if (showBorder) BorderStroke(
            1.dp,
            visuals.cardBorderColor.copy(alpha = if (visuals.isDarkTheme) 0.16f else 0.24f),
        ) else null,
        shadowElevation = 0.dp,
        content = content,
    )
}

@Composable
private fun ContinueDhikrCard(
    goal: GoalWithProgress,
    visuals: HomeVisuals,
    onClick: () -> Unit,
) {
    HomeCardSurface(
        visuals = visuals,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        onClick = onClick,
        shape = RoundedCornerShape(24.dp),
        color = visuals.elevatedCardColor,
    ) {
        Box(modifier = Modifier.fillMaxWidth()) {
            Image(
                painter = painterResource(visuals.featuredImageRes),
                contentDescription = null,
                modifier = Modifier.matchParentSize(),
                contentScale = ContentScale.Crop,
            )
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .background(
                        Brush.horizontalGradient(
                            colors = if (visuals.isDarkTheme) {
                                listOf(Color(0xD90A1118), Color(0x8A0A1118), Color(0x330A1118))
                            } else {
                                listOf(Color(0xF2FFFFFF), Color(0xC7FFFFFF), Color(0x66FFFFFF))
                            },
                        ),
                    ),
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 18.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (goal.dailyTarget > 0) {
                    DayProgressRing(
                        progress = goal.dailyProgress,
                        count = goal.todayCount,
                        ringColor = visuals.goalAccentColor,
                        trackColor = visuals.trackColor.copy(alpha = if (visuals.isDarkTheme) 0.45f else 0.7f),
                        textColor = visuals.primaryTextColor,
                        size = 52.dp,
                        strokeWidth = 5.dp,
                    )
                    Spacer(modifier = Modifier.width(14.dp))
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = stringResource(R.string.home_continue_goal, goal.displayName()),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = visuals.primaryTextColor,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = goal.continueSubtitle(),
                        style = MaterialTheme.typography.bodySmall,
                        color = visuals.secondaryTextColor,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                Spacer(modifier = Modifier.width(12.dp))
                Surface(
                    modifier = Modifier.size(36.dp),
                    shape = CircleShape,
                    color = visuals.goalAccentColor,
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.padding(6.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun GoalWithProgress.continueSubtitle(): String = when {
    dailyTarget <= 0 -> stringResource(R.string.home_count_today, todayCount)
    dailyProgress >= 1f -> stringResource(R.string.action_done)
    else -> stringResource(R.string.home_left_today, (dailyTarget - todayCount).coerceAtLeast(0L))
}

@Composable
private fun EmptyHomeStartCard(
    visuals: HomeVisuals,
    onClick: () -> Unit,
) {
    HomeCardSurface(
        visuals = visuals,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        onClick = onClick,
        shape = RoundedCornerShape(24.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Surface(
                shape = RoundedCornerShape(18.dp),
                color = visuals.chipColor.copy(alpha = 0.78f),
            ) {
                Icon(
                    imageVector = Icons.Filled.Add,
                    contentDescription = null,
                    tint = visuals.chipContentColor,
                    modifier = Modifier
                        .padding(14.dp)
                        .size(28.dp),
                )
            }
            Text(
                text = stringResource(R.string.home_no_goals_title),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
                color = visuals.primaryTextColor,
                textAlign = TextAlign.Center,
            )
            Text(
                text = stringResource(R.string.home_no_goals_body),
                style = MaterialTheme.typography.bodyMedium,
                color = visuals.secondaryTextColor,
                textAlign = TextAlign.Center,
            )
            RitualPrimaryButton(
                text = stringResource(R.string.action_create_goal),
                onClick = onClick,
            )
        }
    }
}

/**
 * Reads the last-known location (permission already granted) and persists it so the prayer card
 * appears. Falls back to opening Settings when no fix is available or permission was denied.
 */
private fun detectLocationOrFallback(
    context: Context,
    viewModel: HomeViewModel,
    onFallback: () -> Unit,
) {
    val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    val location = try {
        locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            ?: locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
    } catch (e: SecurityException) {
        null
    }
    if (location != null) {
        viewModel.onLocationDetected(location.latitude, location.longitude)
    } else {
        onFallback()
    }
}

@Composable
private fun PrayerTimesPromptCard(
    visuals: HomeVisuals,
    onEnable: () -> Unit,
) {
    HomeCardSurface(
        visuals = visuals,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        onClick = onEnable,
        shape = RoundedCornerShape(24.dp),
        color = visuals.elevatedCardColor,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 18.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                shape = CircleShape,
                color = visuals.chipColor.copy(alpha = 0.7f),
            ) {
                Icon(
                    imageVector = Icons.Filled.LocationOn,
                    contentDescription = null,
                    tint = visuals.chipContentColor,
                    modifier = Modifier
                        .padding(10.dp)
                        .size(22.dp),
                )
            }
            Spacer(modifier = Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.home_enable_prayer_title),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = visuals.primaryTextColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = stringResource(R.string.home_enable_prayer_body),
                    style = MaterialTheme.typography.bodySmall,
                    color = visuals.secondaryTextColor,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = visuals.secondaryTextColor,
                modifier = Modifier.size(22.dp),
            )
        }
    }
}

@Composable
private fun PrayerRhythmCard(
    state: PrayerCardState,
    visuals: HomeVisuals,
    onClick: () -> Unit,
) {
    val nextPrayer = state.nextPrayer
    HomeCardSurface(
        visuals = visuals,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        onClick = onClick,
        shape = RoundedCornerShape(24.dp),
        color = visuals.elevatedCardColor,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            PrayerIconBadge(visuals = visuals)
            Spacer(modifier = Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.home_next_prayer),
                    style = MaterialTheme.typography.bodyMedium,
                    color = visuals.secondaryTextColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = nextPrayer?.let { "${it.name} · ${it.timeFormatted}" }
                        ?: stringResource(R.string.home_all_prayers_complete),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = visuals.primaryTextColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (nextPrayer != null && nextPrayer.countdown.isNotBlank()) {
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = nextPrayer.countdown,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = visuals.accentColor,
                    maxLines = 1,
                )
            }
            Spacer(modifier = Modifier.width(6.dp))
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = visuals.secondaryTextColor.copy(alpha = 0.7f),
                modifier = Modifier.size(22.dp),
            )
        }
    }
}

@Composable
private fun PrayerIconBadge(
    visuals: HomeVisuals,
) {
    Surface(
        modifier = Modifier.size(52.dp),
        shape = CircleShape,
        color = visuals.accentColor.copy(alpha = if (visuals.isDarkTheme) 0.22f else 0.14f),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Canvas(modifier = Modifier.size(26.dp)) {
                drawMosque(visuals.accentColor)
            }
        }
    }
}

/** Draws a filled mosque silhouette (dome, two minarets, base) scaled to the canvas size. */
private fun DrawScope.drawMosque(color: Color) {
    val w = size.width
    val h = size.height

    // Base platform
    drawRoundRect(
        color = color,
        topLeft = Offset(w * 0.08f, h * 0.80f),
        size = androidx.compose.ui.geometry.Size(w * 0.84f, h * 0.09f),
        cornerRadius = CornerRadius(w * 0.03f, w * 0.03f),
    )

    // Minarets (shaft + rounded cap + finial)
    listOf(0.17f, 0.83f).forEach { cx ->
        drawRoundRect(
            color = color,
            topLeft = Offset(w * (cx - 0.035f), h * 0.42f),
            size = androidx.compose.ui.geometry.Size(w * 0.07f, h * 0.40f),
            cornerRadius = CornerRadius(w * 0.02f, w * 0.02f),
        )
        drawCircle(color = color, radius = w * 0.055f, center = Offset(w * cx, h * 0.42f))
        drawCircle(color = color, radius = w * 0.022f, center = Offset(w * cx, h * 0.33f))
    }

    // Central body + onion dome as one silhouette
    val dome = Path().apply {
        moveTo(w * 0.36f, h * 0.80f)
        lineTo(w * 0.36f, h * 0.46f)
        quadraticBezierTo(w * 0.36f, h * 0.18f, w * 0.50f, h * 0.13f)
        quadraticBezierTo(w * 0.64f, h * 0.18f, w * 0.64f, h * 0.46f)
        lineTo(w * 0.64f, h * 0.80f)
        close()
    }
    drawPath(dome, color = color)

    // Finial on top of the central dome
    drawCircle(color = color, radius = w * 0.028f, center = Offset(w * 0.50f, h * 0.06f))
}

@Composable
private fun TodayGoalsSection(
    goals: List<GoalWithProgress>,
    visuals: HomeVisuals,
    onGoalClick: (GoalWithProgress) -> Unit,
    onViewAll: () -> Unit,
) {
    HomeCardSurface(
        visuals = visuals,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        shape = RoundedCornerShape(24.dp),
        color = visuals.elevatedCardColor,
    ) {
        Box(modifier = Modifier.fillMaxWidth()) {
            Image(
                painter = painterResource(visuals.goalsImageRes),
                contentDescription = null,
                modifier = Modifier.matchParentSize(),
                contentScale = ContentScale.Crop,
            )
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .background(
                        Brush.horizontalGradient(
                            colors = if (visuals.isDarkTheme) {
                                listOf(Color(0xC90A1118), Color(0x620A1118), Color.Transparent)
                            } else {
                                listOf(Color(0xEFFFFFFF), Color(0xB8FFFFFF), Color.Transparent)
                            },
                        ),
                    ),
            )
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 18.dp, vertical = 18.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.weight(1f),
                    ) {
                        GoalIconBadge(visuals = visuals)
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            text = stringResource(R.string.home_todays_goals),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = visuals.primaryTextColor,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                    Row(
                        modifier = Modifier
                            .clickable { onViewAll() }
                            .padding(start = 8.dp, top = 6.dp, bottom = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = stringResource(R.string.home_view_all),
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Bold,
                            color = visuals.goalAccentColor,
                        )
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                            contentDescription = null,
                            tint = visuals.goalAccentColor,
                            modifier = Modifier.size(22.dp),
                        )
                    }
                }
                Spacer(modifier = Modifier.height(14.dp))
                goals.forEachIndexed { index, goal ->
                    GoalQueueRow(
                        goal = goal,
                        visuals = visuals,
                        onClick = { onGoalClick(goal) },
                    )
                    if (index != goals.lastIndex) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 12.dp, bottom = 12.dp)
                                .height(1.dp)
                                .background(visuals.secondaryTextColor.copy(alpha = 0.18f)),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun GoalIconBadge(
    visuals: HomeVisuals,
) {
    Surface(
        modifier = Modifier.size(40.dp),
        shape = CircleShape,
        color = visuals.goalAccentColor.copy(alpha = if (visuals.isDarkTheme) 0.16f else 0.12f),
        border = BorderStroke(1.dp, visuals.goalAccentColor.copy(alpha = 0.28f)),
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val center = Offset(size.width / 2f, size.height / 2f)
            drawCircle(
                color = visuals.goalAccentColor,
                radius = size.minDimension * 0.2f,
                center = center,
                style = Stroke(width = 4f),
            )
            drawCircle(
                color = visuals.goalAccentColor,
                radius = size.minDimension * 0.05f,
                center = center + Offset(size.width * 0.13f, -size.height * 0.13f),
            )
            drawLine(
                color = visuals.goalAccentColor,
                start = center,
                end = center + Offset(size.width * 0.18f, -size.height * 0.18f),
                strokeWidth = 3f,
            )
        }
    }
}

@Composable
private fun GoalQueueRow(
    goal: GoalWithProgress,
    visuals: HomeVisuals,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = goal.displayName(),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = visuals.primaryTextColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            // Compact streak chip — the full day strip stays on the featured hero card only.
            if (goal.streakDays > 0) {
                Spacer(modifier = Modifier.height(4.dp))
                GoalStreakChip(streakDays = goal.streakDays)
            }
        }
        Spacer(modifier = Modifier.width(12.dp))
        if (goal.dailyTarget > 0) {
            DayProgressRing(
                progress = goal.dailyProgress,
                count = goal.todayCount,
                ringColor = visuals.goalAccentColor,
                trackColor = visuals.trackColor.copy(alpha = if (visuals.isDarkTheme) 0.45f else 0.7f),
                textColor = visuals.primaryTextColor,
                size = 46.dp,
                strokeWidth = 4.dp,
            )
        } else {
            Text(
                text = goal.compactProgressText(),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = visuals.goalAccentColor,
            )
        }
        Spacer(modifier = Modifier.width(4.dp))
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = visuals.goalAccentColor,
            modifier = Modifier.size(22.dp),
        )
    }
}

private fun GoalWithProgress.displayName(): String =
    dhikrTranslation.ifBlank { dhikrTransliteration.ifBlank { "Dhikr" } }

@Composable
private fun GoalWithProgress.compactProgressText(): String =
    when {
        dailyTarget <= 0 -> todayCount.toString()
        dailyProgress >= 1f -> stringResource(R.string.action_done)
        else -> "$todayCount / $dailyTarget"
    }
