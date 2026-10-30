package app.awrad.feature.practice

import android.Manifest
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradOptionRow
import app.awrad.core.designsystem.component.AwradSectionTitle
import app.awrad.core.designsystem.component.AwradTopBar
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.practice.DayReset
import app.awrad.core.domain.practice.Madhab
import app.awrad.core.domain.practice.WeekStart

@Composable
internal fun PracticeSettingsRoute(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: PracticeSettingsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var searching by rememberSaveable { mutableStateOf(false) }
    // Each search starts fresh: its ViewModel is keyed by the session.
    var searchSession by rememberSaveable { mutableIntStateOf(0) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        viewModel.onAction(
            if (granted) PracticeSettingsAction.UseMyLocation else PracticeSettingsAction.LocationPermissionDenied,
        )
    }
    if (searching) {
        BackHandler { searching = false }
        LocationSearchRoute(sessionKey = "location-search-$searchSession", onClose = { searching = false })
    } else {
        PracticeSettingsScreen(
            state = state,
            onAction = viewModel::onAction,
            onBack = onBack,
            onSearch = {
                searchSession++
                searching = true
            },
            onUseMyLocation = { permission.launch(Manifest.permission.ACCESS_COARSE_LOCATION) },
            modifier = modifier,
        )
    }
}

/**
 * Practice settings: a top bar with Back, then "Today" (the Hijri date and Maghrib), "New day starts" (with the hint
 * when Maghrib is chosen without a location), "Location", "Prayer times" (the method), "Asr time" (madhab), "Week
 * starts on" and "Hijri calendar" (adjust this month, and the corrections saved). Choices are option rows; the
 * method and the month adjustment open bottom sheets.
 */
@Composable
internal fun PracticeSettingsScreen(
    state: PracticeSettingsUiState,
    onAction: (PracticeSettingsAction) -> Unit,
    onBack: () -> Unit,
    onSearch: () -> Unit,
    onUseMyLocation: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val spacing = AwradTheme.spacing
    val navigationBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(AwradTheme.colors.background)
            .statusBarsPadding(),
    ) {
        AwradTopBar(title = stringResource(R.string.practice_title), onBack = onBack)
        val today = state.today
        if (state.isLoading || today == null) return@Column
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = spacing.pageMargin)
                .padding(top = spacing.sm, bottom = spacing.sectionGap + navigationBar),
            verticalArrangement = Arrangement.spacedBy(spacing.sectionGap),
        ) {
            TodaySection(today = today)
            ChoiceSection(
                title = stringResource(R.string.practice_section_day_reset),
                options = DayReset.entries,
                selected = state.policy.dayReset,
                label = ::dayResetLabel,
                onSelect = { onAction(PracticeSettingsAction.SetDayReset(it)) },
                note = R.string.practice_maghrib_hint_no_location.takeIf { today.showsMaghribHint },
            )
            LocationSection(state = state, onAction = onAction, onSearch = onSearch, onUseMyLocation = onUseMyLocation)
            Section(title = stringResource(R.string.practice_section_method)) {
                LinkCard(
                    title = stringResource(R.string.practice_method_label),
                    value = stringResource(methodLabel(state.policy.calculationMethod)),
                    onClick = { onAction(PracticeSettingsAction.OpenSheet(PracticeSheet.Method)) },
                )
            }
            ChoiceSection(
                title = stringResource(R.string.practice_section_madhab),
                options = Madhab.entries,
                selected = state.policy.madhab,
                label = ::madhabLabel,
                onSelect = { onAction(PracticeSettingsAction.SetMadhab(it)) },
                note = R.string.practice_madhab_note,
            )
            ChoiceSection(
                title = stringResource(R.string.practice_section_week_start),
                options = WeekStart.entries,
                selected = state.policy.weekStart,
                label = ::weekStartLabel,
                onSelect = { onAction(PracticeSettingsAction.SetWeekStart(it)) },
            )
            HijriSection(today = today, onAction = onAction)
        }
    }
    PracticeSheets(state = state, onAction = onAction)
}

/** The open bottom sheet: the calculation method, or when a month starts. */
@Composable
private fun PracticeSheets(state: PracticeSettingsUiState, onAction: (PracticeSettingsAction) -> Unit) {
    when (val sheet = state.sheet) {
        PracticeSheet.Method -> MethodSheet(selected = state.policy.calculationMethod, onAction = onAction)
        is PracticeSheet.Adjust ->
            state.today?.adjustable
                ?.firstOrNull { it.year == sheet.year && it.month == sheet.month }
                ?.let { AdjustMonthSheet(month = it, onAction = onAction) }
        null -> Unit
    }
}

/** One choice of several, as option rows (announced as radio buttons), with an optional note under them. */
@Composable
private fun <T> ChoiceSection(
    title: String,
    options: List<T>,
    selected: T,
    label: (T) -> Int,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    @StringRes note: Int? = null,
) {
    Section(title = title, modifier = modifier) {
        options.forEach { option ->
            AwradOptionRow(
                label = stringResource(label(option)),
                selected = option == selected,
                onClick = { onSelect(option) },
            )
        }
        note?.let { Note(text = stringResource(it)) }
    }
}

/** Today's Hijri date (the effective practice day's, with corrections) and today's Maghrib. */
@Composable
private fun TodaySection(today: PracticeToday, modifier: Modifier = Modifier) {
    Section(title = stringResource(R.string.practice_section_today), modifier = modifier) {
        AwradCard(spacing = AwradTheme.spacing.xs) {
            Text(
                text = today.hijriDate?.let { hijriDateText(it) } ?: stringResource(R.string.practice_hijri_outside),
                style = AwradTheme.type.cardTitle,
                color = AwradTheme.colors.onSurface,
            )
            Text(
                text = when (val maghrib = today.maghrib) {
                    is MaghribToday.At -> stringResource(R.string.practice_maghrib_at, timeText(maghrib.time))
                    MaghribToday.NoLocation -> stringResource(R.string.practice_maghrib_no_location)
                    MaghribToday.NoSunset -> stringResource(R.string.practice_maghrib_no_sunset)
                },
                style = AwradTheme.type.bodySmall,
                color = AwradTheme.colors.onSurfaceVariant,
            )
        }
    }
}

/** A titled group of settings, its rows `rowGap` apart. */
@Composable
internal fun Section(title: String, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap)) {
        AwradSectionTitle(text = title)
        content()
    }
}

/** A small explanation under a setting. */
@Composable
internal fun Note(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        modifier = modifier,
        style = AwradTheme.type.bodySmall,
        color = AwradTheme.colors.onSurfaceVariant,
    )
}
