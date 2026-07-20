package app.awrad.awrad_dhikrgoalstracker.ui.screens.community

import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.BookmarkBorder
import androidx.compose.material.icons.rounded.DynamicFeed
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.ChatBubbleOutline
import androidx.compose.material.icons.rounded.Menu
import androidx.compose.material.icons.rounded.NotificationsNone
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.TrackChanges
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBarDefaults
import androidx.compose.material3.DismissibleDrawerSheet
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualPrimaryButton
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradTabs
import app.awrad.awrad_dhikrgoalstracker.ui.screens.auth.AuthViewModel
import app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding.AwradLogoMark
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import app.awrad.awrad_dhikrgoalstracker.data.repository.CommunityDailyCount
import app.awrad.awrad_dhikrgoalstracker.data.repository.CommunityStats
import java.math.BigInteger
import java.text.DateFormat
import java.text.NumberFormat
import java.time.ZoneId
import java.util.Date
import java.util.Locale
import android.icu.text.CompactDecimalFormat
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

@Composable
internal fun communityCardContainerColor(
    lightColor: Color = MaterialTheme.colorScheme.surface,
): Color = if (isAwradDarkTheme()) {
    NavigationBarDefaults.containerColor
} else {
    lightColor
}

@Composable
fun CommunityScreen(
    onNavigateToLogin: () -> Unit,
    onNavigateToSignup: () -> Unit,
    onNavigateToVerification: () -> Unit,
    onNavigateToStats: () -> Unit,
    onNavigateToProfile: () -> Unit,
    onNavigateToChallenges: () -> Unit,
    onNavigateToCircles: () -> Unit,
    onNavigateToSaved: () -> Unit,
    onNavigateToPost: () -> Unit,
    onOpenMenu: () -> Unit,
    authViewModel: AuthViewModel = hiltViewModel(),
    statsViewModel: CommunityStatsViewModel = hiltViewModel(),
) {
    val isLoggedIn by authViewModel.isLoggedIn.collectAsState()
    val pendingVerificationEmail by authViewModel.pendingVerificationEmail.collectAsState()
    val isEmailVerified by authViewModel.isEmailVerified.collectAsState()
    val statsState by statsViewModel.uiState.collectAsState()
    val unavailableMessage = stringResource(R.string.community_feed_destination_coming_soon)
    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()
    var selectedFeedTab by rememberSaveable { mutableIntStateOf(0) }
    val showUnavailableAction: () -> Unit = {
        coroutineScope.launch {
            snackbarHostState.showSnackbar(unavailableMessage)
        }
    }
    LaunchedEffect(isLoggedIn, isEmailVerified) {
        if (isLoggedIn && isEmailVerified) authViewModel.loadSessions()
    }
    val density = LocalDensity.current
    val statusBarTopPadding = with(density) { WindowInsets.statusBars.getTop(this).toDp() }
    var topBarHeightPx by remember { mutableFloatStateOf(0f) }
    var topBarOffsetPx by remember { mutableFloatStateOf(0f) }
    val topBarHeight = with(density) { topBarHeightPx.toDp() }
    val topBarScrollConnection = remember {
        object : NestedScrollConnection {
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                topBarOffsetPx = (topBarOffsetPx + available.y)
                    .coerceIn(-topBarHeightPx, 0f)
                return Offset.Zero
            }
        }
    }
    BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .nestedScroll(topBarScrollConnection)
                .padding(top = statusBarTopPadding + 22.dp)
                .clipToBounds(),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = maxHeight)
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Top,
            ) {
                Spacer(Modifier.height(topBarHeight))

                if (pendingVerificationEmail != null) {
                CommunityStatsSection(
                    state = statsState,
                    onRetry = statsViewModel::retry,
                    onRefresh = statsViewModel::refresh,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
                Spacer(Modifier.height(20.dp))
                VerificationRequiredContent(
                    email = pendingVerificationEmail,
                    onContinue = onNavigateToVerification,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
                } else if (isLoggedIn && isEmailVerified) {
                when (selectedFeedTab) {
                    0 -> CommunityLandingFeed(
                        onUnavailableAction = showUnavailableAction,
                        onOpenChallenges = onNavigateToChallenges,
                        onOpenPost = onNavigateToPost,
                        modifier = Modifier.padding(horizontal = 20.dp),
                    )
                    1 -> CommunityTabPlaceholder(title = stringResource(R.string.community_tab_goals))
                    else -> CommunityTabPlaceholder(title = stringResource(R.string.community_tab_explore))
                }
                } else {
                CommunityStatsSection(
                    state = statsState,
                    onRetry = statsViewModel::retry,
                    onRefresh = statsViewModel::refresh,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
                Spacer(Modifier.height(20.dp))
                GuestContent(
                    onNavigateToLogin = onNavigateToLogin,
                    onNavigateToSignup = onNavigateToSignup,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
                }

                Spacer(Modifier.height(112.dp))
            }
            Column(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .fillMaxWidth()
                    .offset { IntOffset(0, topBarOffsetPx.roundToInt()) }
                    .onSizeChanged { topBarHeightPx = it.height.toFloat() }
                    .background(MaterialTheme.colorScheme.background)
                    .zIndex(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                CommunityHeader(
                    isLoggedIn = isLoggedIn,
                    onMenuClick = onOpenMenu,
                    onNotificationsClick = showUnavailableAction,
                    onMessagesClick = showUnavailableAction,
                    onProfileClick = onNavigateToProfile,
                )

                if (isLoggedIn && isEmailVerified && pendingVerificationEmail == null) {
                    Spacer(Modifier.height(14.dp))
                    AwradTabs(
                        tabs = listOf(
                            stringResource(R.string.community_tab_for_you),
                            stringResource(R.string.community_tab_goals),
                            stringResource(R.string.community_tab_explore),
                        ),
                        selectedTab = selectedFeedTab,
                        onTabSelected = { selectedFeedTab = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState())
                            .padding(horizontal = 20.dp),
                    )
                }

                Spacer(Modifier.height(20.dp))
            }
            SnackbarHost(
                hostState = snackbarHostState,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(start = 20.dp, end = 20.dp, bottom = 132.dp),
            ) { snackbarData ->
                Snackbar(
                    snackbarData = snackbarData,
                    containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                    contentColor = MaterialTheme.colorScheme.onSurface,
                )
            }
    }
}

@Composable
internal fun CommunityStatsSection(
    state: CommunityStatsUiState,
    onRetry: () -> Unit,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
) {
    when {
        state.stats != null -> CommunityStatsContent(
            stats = state.stats,
            isRefreshing = state.isLoading,
            onRefresh = onRefresh,
            modifier = modifier,
        )
        state.hasError -> CommunityStatsError(onRetry, modifier)
        else -> CommunityStatsLoading(modifier)
    }
}

@Composable
private fun CommunityStatsLoading(modifier: Modifier = Modifier) {
    RitualCard(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(30.dp),
        containerColor = communityCardContainerColor(),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().height(220.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            CircularProgressIndicator(modifier = Modifier.size(32.dp), strokeWidth = 3.dp)
            Spacer(Modifier.height(16.dp))
            Text(
                text = stringResource(R.string.community_stats_loading),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun CommunityStatsError(onRetry: () -> Unit, modifier: Modifier = Modifier) {
    RitualCard(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(30.dp),
        containerColor = communityCardContainerColor(),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = stringResource(R.string.community_stats_unavailable_title),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.community_stats_unavailable_body),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(16.dp))
            OutlinedButton(onClick = onRetry, shape = RoundedCornerShape(16.dp)) {
                Text(stringResource(R.string.community_stats_retry))
            }
        }
    }
}

@Composable
private fun CommunityStatsContent(
    stats: CommunityStats,
    isRefreshing: Boolean,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val locale = currentLocale()
    val fullNumber = remember(locale) { NumberFormat.getIntegerInstance(locale) }
    val compactNumber = remember(locale) {
        CompactDecimalFormat.getInstance(locale, CompactDecimalFormat.CompactStyle.SHORT)
    }
    val total = remember(stats.approximateTotalCounts, locale) { fullNumber.format(stats.approximateTotalCounts) }
    val goals = remember(stats.totalTrackedGoals, locale) { fullNumber.format(stats.totalTrackedGoals) }
    val hours = remember(stats.approximateDhikrHours, locale) {
        NumberFormat.getNumberInstance(locale).apply {
            minimumFractionDigits = 1
            maximumFractionDigits = 1
        }.format(stats.approximateDhikrHours)
    }
    val asOf = remember(stats.asOf, locale) {
        DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT, locale)
            .format(Date.from(stats.asOf))
    }
    val heroDescription = stringResource(R.string.community_stats_total_accessibility, total)

    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        RitualCard(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(30.dp),
            containerColor = communityCardContainerColor(),
        ) {
            Column(modifier = Modifier.fillMaxWidth().padding(24.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = RoundedCornerShape(50),
                    ) {
                        Text(
                            text = stringResource(R.string.community_stats_synced_badge),
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                    }
                    IconButton(onClick = onRefresh, enabled = !isRefreshing) {
                        if (isRefreshing) {
                            CircularProgressIndicator(modifier = Modifier.size(22.dp), strokeWidth = 2.dp)
                        } else {
                            Icon(
                                imageVector = Icons.Rounded.Refresh,
                                contentDescription = stringResource(R.string.community_stats_refresh),
                            )
                        }
                    }
                }
                Spacer(Modifier.height(18.dp))
                Text(
                    text = stringResource(R.string.community_stats_total_label),
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = total,
                    modifier = Modifier.fillMaxWidth().semantics { contentDescription = heroDescription },
                    style = MaterialTheme.typography.displayLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = stringResource(R.string.community_stats_total_context),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            CommunityMetricCard(
                label = stringResource(R.string.community_stats_goals_label),
                value = goals,
                icon = { Icon(Icons.Rounded.TrackChanges, contentDescription = null) },
                modifier = Modifier.weight(1f),
            )
            CommunityMetricCard(
                label = stringResource(R.string.community_stats_hours_label),
                value = hours,
                icon = { Icon(Icons.Rounded.Schedule, contentDescription = null) },
                modifier = Modifier.weight(1f),
            )
        }

        RitualCard(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(30.dp),
            containerColor = communityCardContainerColor(),
        ) {
            Column(modifier = Modifier.fillMaxWidth().padding(20.dp)) {
                Text(
                    text = stringResource(R.string.community_stats_seven_day_title),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(16.dp))
                CommunityBarChart(stats.dailyCounts.takeLast(7), compactNumber::format, locale)
                Spacer(Modifier.height(16.dp))
                Text(
                    text = stringResource(R.string.community_stats_estimate_note, stats.secondsPerCount),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    text = stringResource(R.string.community_stats_as_of, asOf),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun CommunityMetricCard(
    label: String,
    value: String,
    icon: @Composable () -> Unit,
    modifier: Modifier = Modifier,
) {
    RitualCard(
        modifier = modifier.heightIn(min = 126.dp),
        shape = RoundedCornerShape(24.dp),
        containerColor = communityCardContainerColor(),
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(18.dp)) {
            Surface(
                modifier = Modifier.size(34.dp),
                shape = CircleShape,
                color = MaterialTheme.colorScheme.secondaryContainer,
                contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
            ) { Box(contentAlignment = Alignment.Center) { icon() } }
            Spacer(Modifier.height(12.dp))
            Text(value, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun CommunityBarChart(
    counts: List<CommunityDailyCount>,
    compactNumber: (BigInteger) -> String,
    locale: Locale,
) {
    val maximum = counts.maxOfOrNull { it.approximateCount }?.takeIf { it.signum() > 0 } ?: BigInteger.ONE
    Row(
        modifier = Modifier.fillMaxWidth().height(142.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.Bottom,
    ) {
        counts.forEach { day ->
            val ratio = day.approximateCount.toBigDecimal()
                .divide(maximum.toBigDecimal(), 4, java.math.RoundingMode.HALF_UP)
                .toFloat()
            val formattedCount = compactNumber(day.approximateCount)
            val weekday = day.date.dayOfWeek.getDisplayName(java.time.format.TextStyle.NARROW, locale)
            val description = stringResource(R.string.community_stats_day_accessibility, weekday, formattedCount)
            Column(
                modifier = Modifier.weight(1f).semantics { contentDescription = description },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Bottom,
            ) {
                Text(
                    text = formattedCount,
                    style = MaterialTheme.typography.labelSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Clip,
                )
                Spacer(Modifier.height(5.dp))
                Box(
                    modifier = Modifier
                        .width(18.dp)
                        .height((18 + 70 * ratio).dp)
                        .clip(RoundedCornerShape(topStart = 9.dp, topEnd = 9.dp)),
                ) {
                    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.primary) {}
                }
                Spacer(Modifier.height(6.dp))
                Text(weekday, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun currentLocale(): Locale {
    val configuration = LocalConfiguration.current
    return configuration.locales[0] ?: Locale.getDefault()
}

@Composable
private fun VerificationRequiredContent(
    email: String?,
    onContinue: () -> Unit,
    modifier: Modifier = Modifier,
) {
    RitualCard(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(30.dp),
        containerColor = communityCardContainerColor(),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            CommunityMark()
            Spacer(Modifier.height(22.dp))
            Text(
                text = stringResource(R.string.community_verify_email_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = stringResource(R.string.community_verify_email_body, email.orEmpty()),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(20.dp))
            Button(onClick = onContinue, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.auth_resume_verification))
            }
        }
    }
}

@Composable
internal fun CommunityDrawer(
    onFeed: () -> Unit,
    onChallenges: () -> Unit,
    onCircles: () -> Unit,
    onSaved: () -> Unit,
    onStats: () -> Unit,
    onProfile: () -> Unit,
) {
    DismissibleDrawerSheet(modifier = Modifier.width(320.dp)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 28.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onProfile)
                    .padding(horizontal = 12.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Surface(
                    modifier = Modifier.size(48.dp),
                    shape = CircleShape,
                    color = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.Person, contentDescription = null)
                    }
                }
                Column {
                    Text(
                        text = stringResource(R.string.community_title),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = stringResource(R.string.community_drawer_view_profile),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            NavigationDrawerItem(
                label = { Text(stringResource(R.string.community_nav_feed)) },
                selected = true,
                onClick = onFeed,
                icon = { Icon(Icons.Rounded.DynamicFeed, contentDescription = null) },
            )
            NavigationDrawerItem(
                label = { Text(stringResource(R.string.community_nav_challenges)) },
                selected = false,
                onClick = onChallenges,
                icon = { Icon(Icons.Rounded.EmojiEvents, contentDescription = null) },
            )
            NavigationDrawerItem(
                label = { Text(stringResource(R.string.community_nav_circles)) },
                selected = false,
                onClick = onCircles,
                icon = { Icon(Icons.Rounded.Groups, contentDescription = null) },
            )
            NavigationDrawerItem(
                label = { Text(stringResource(R.string.community_nav_saved)) },
                selected = false,
                onClick = onSaved,
                icon = { Icon(Icons.Rounded.BookmarkBorder, contentDescription = null) },
            )
            NavigationDrawerItem(
                label = { Text(stringResource(R.string.community_nav_stats)) },
                selected = false,
                onClick = onStats,
                icon = { Icon(Icons.Rounded.BarChart, contentDescription = null) },
            )
        }
    }
}

@Composable
private fun CommunityHeader(
    isLoggedIn: Boolean,
    onMenuClick: () -> Unit,
    onNotificationsClick: () -> Unit,
    onMessagesClick: () -> Unit,
    onProfileClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .padding(horizontal = 20.dp),
    ) {
        if (isLoggedIn) {
            IconButton(
                onClick = onMenuClick,
                modifier = Modifier.align(Alignment.CenterStart),
            ) {
                Icon(
                    imageVector = Icons.Rounded.Menu,
                    contentDescription = stringResource(R.string.community_menu_open),
                )
            }
        }
        Row(
            modifier = Modifier.align(Alignment.Center),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AwradLogoMark(modifier = Modifier.size(32.dp))
            Text(
                text = stringResource(R.string.community_title),
                style = MaterialTheme.typography.labelLarge.copy(fontSize = 21.sp, fontFeatureSettings = "smcp"),
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
        if (isLoggedIn) {
            Row(
                modifier = Modifier.align(Alignment.CenterEnd),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(
                    onClick = onNotificationsClick,
                    modifier = Modifier.size(40.dp),
                ) {
                    Icon(
                        imageVector = Icons.Rounded.NotificationsNone,
                        contentDescription = stringResource(R.string.community_notifications),
                        modifier = Modifier.size(22.dp),
                    )
                }
                IconButton(
                    onClick = onMessagesClick,
                    modifier = Modifier.size(40.dp),
                ) {
                    Icon(
                        imageVector = Icons.Rounded.ChatBubbleOutline,
                        contentDescription = stringResource(R.string.community_messages),
                        modifier = Modifier.size(22.dp),
                    )
                }
                Surface(
                    modifier = Modifier
                        .size(40.dp)
                        .clickable(onClick = onProfileClick),
                    shape = CircleShape,
                    color = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = Icons.Rounded.Person,
                            contentDescription = stringResource(R.string.community_nav_profile),
                            modifier = Modifier.size(22.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CommunityTabPlaceholder(title: String) {
    RitualCard(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
        shape = RoundedCornerShape(24.dp),
        containerColor = communityCardContainerColor(),
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(24.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.community_feed_destination_coming_soon),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun GuestContent(
    onNavigateToLogin: () -> Unit,
    onNavigateToSignup: () -> Unit,
    modifier: Modifier = Modifier,
) {
    RitualCard(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(30.dp),
        containerColor = communityCardContainerColor(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            CommunityMark()

            Spacer(Modifier.height(22.dp))

            Text(
                text = stringResource(R.string.community_join_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(Modifier.height(10.dp))

            Text(
                text = stringResource(R.string.community_join_subtitle),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            Spacer(Modifier.height(28.dp))

            RitualPrimaryButton(
                text = stringResource(R.string.auth_signup),
                onClick = onNavigateToSignup,
            )

            Spacer(Modifier.height(12.dp))

            OutlinedButton(
                onClick = onNavigateToLogin,
                modifier = Modifier.fillMaxWidth().height(54.dp),
                shape = RoundedCornerShape(18.dp),
            ) {
                Text(stringResource(R.string.auth_login))
            }
        }
    }
}

@Composable
private fun CommunityMark(
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier.size(68.dp),
        shape = CircleShape,
        color = if (isAwradDarkTheme()) {
            MaterialTheme.colorScheme.surfaceContainerHigh
        } else {
            MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.58f)
        },
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = Icons.Rounded.Groups,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(34.dp),
            )
        }
    }
}
