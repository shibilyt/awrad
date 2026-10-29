package app.awrad.feature.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import app.awrad.core.designsystem.component.AwradBottomSheet
import app.awrad.core.designsystem.component.AwradButton
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradCardSize
import app.awrad.core.designsystem.component.AwradOptionRow
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.practice.CalculationMethod

/**
 * "Location": the chosen place (or none) and that it stays on this phone; "Use my location" (asks for the coarse
 * permission first), "Search for a place", and "Remove location" when one is set. A reading that failed says why.
 */
@Composable
internal fun LocationSection(
    state: PracticeSettingsUiState,
    onAction: (PracticeSettingsAction) -> Unit,
    onSearch: () -> Unit,
    onUseMyLocation: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Section(title = stringResource(R.string.practice_section_location), modifier = modifier) {
        AwradCard(spacing = AwradTheme.spacing.xs) {
            Text(
                text = state.location?.let { locationText(it) } ?: stringResource(R.string.practice_location_none),
                style = AwradTheme.type.rowTitle,
                color = AwradTheme.colors.onSurface,
            )
            Note(text = stringResource(R.string.practice_location_note))
        }
        state.locationProblem?.let { problem ->
            Text(
                text = stringResource(
                    when (problem) {
                        LocationProblem.PERMISSION_DENIED -> R.string.practice_location_denied
                        LocationProblem.UNAVAILABLE -> R.string.practice_location_unavailable
                    },
                ),
                style = AwradTheme.type.bodySmall,
                color = AwradTheme.colors.error,
            )
        }
        AwradButton(
            text = stringResource(R.string.practice_use_my_location),
            onClick = onUseMyLocation,
            variant = AwradButtonVariant.Secondary,
            leadingIcon = AwradIcons.Location,
            isLoading = state.isLocating,
        )
        AwradButton(
            text = stringResource(R.string.practice_search_place),
            onClick = onSearch,
            variant = AwradButtonVariant.Secondary,
            leadingIcon = AwradIcons.Search,
        )
        if (state.location != null) {
            AwradTextButton(
                text = stringResource(R.string.practice_clear_location),
                onClick = { onAction(PracticeSettingsAction.ClearLocation) },
            )
        }
    }
}

/**
 * "Hijri calendar": a link to adjust this month (and the next one in this month's last days) with the start in force,
 * then the corrections saved, each removable when the rest stay valid.
 */
@Composable
internal fun HijriSection(
    today: PracticeToday,
    onAction: (PracticeSettingsAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    Section(title = stringResource(R.string.practice_section_hijri), modifier = modifier) {
        Note(text = stringResource(R.string.practice_hijri_note))
        today.adjustable.forEach { month ->
            key(month.year, month.month) {
                LinkCard(
                    title = stringResource(R.string.practice_adjust_month, monthYearText(month.year, month.month)),
                    value = stringResource(offsetLabel(month.offset)),
                    onClick = {
                        onAction(
                            PracticeSettingsAction.OpenSheet(PracticeSheet.Adjust(month.year, month.month)),
                        )
                    },
                )
            }
        }
        if (today.corrections.isNotEmpty()) {
            Text(
                text = stringResource(R.string.practice_corrections_title),
                style = AwradTheme.type.label,
                color = AwradTheme.colors.onSurfaceVariant,
            )
            AwradCard(spacing = AwradTheme.spacing.xs) {
                today.corrections.forEach { row -> CorrectionLine(row = row, onAction = onAction) }
            }
        }
    }
}

@Composable
private fun CorrectionLine(
    row: CorrectionRow,
    onAction: (PracticeSettingsAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    val correction = row.correction
    Row(modifier = modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = stringResource(
                R.string.practice_correction_line,
                monthYearText(correction.year, correction.month),
                stringResource(offsetLabel(correction.offsetDays)),
            ),
            modifier = Modifier.weight(1f),
            style = AwradTheme.type.body,
            color = AwradTheme.colors.onSurface,
        )
        AwradTextButton(
            text = stringResource(R.string.practice_correction_remove),
            onClick = { onAction(PracticeSettingsAction.RemoveCorrection(correction)) },
            enabled = row.removable,
            isDestructive = true,
        )
    }
}

/** A setting that opens a choice: its name, the current value, and a chevron; the whole tile is one target. */
@Composable
internal fun LinkCard(title: String, value: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    AwradCard(onClick = onClick, modifier = modifier, size = AwradCardSize.Tile) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.xxs)) {
                Text(text = title, style = AwradTheme.type.rowTitle, color = AwradTheme.colors.onSurface)
                Text(text = value, style = AwradTheme.type.bodySmall, color = AwradTheme.colors.onSurfaceVariant)
            }
            // `chevron` flips in right-to-left layouts, so it always points the way the row opens.
            Icon(
                imageVector = AwradIcons.Chevron,
                contentDescription = null,
                modifier = Modifier.size(AwradTheme.sizes.iconSmall),
                tint = AwradTheme.colors.onSurfaceVariant,
            )
        }
    }
}

/** The ten calculation methods as option rows; choosing one saves it and closes the sheet. */
@Composable
internal fun MethodSheet(
    selected: CalculationMethod,
    onAction: (PracticeSettingsAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    SheetColumn(
        title = stringResource(R.string.practice_method_label),
        note = stringResource(R.string.practice_method_note),
        onClose = { onAction(PracticeSettingsAction.CloseSheet) },
        modifier = modifier,
    ) {
        CalculationMethod.entries.forEach { method ->
            AwradOptionRow(
                label = stringResource(methodLabel(method)),
                selected = method == selected,
                onClick = { onAction(PracticeSettingsAction.SetMethod(method)) },
            )
        }
    }
}

/** When [month] starts: only the offsets that keep every month 29 or 30 days, the one in force selected. */
@Composable
internal fun AdjustMonthSheet(
    month: AdjustableMonth,
    onAction: (PracticeSettingsAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    SheetColumn(
        title = stringResource(R.string.practice_adjust_title, monthYearText(month.year, month.month)),
        note = stringResource(R.string.practice_adjust_note),
        onClose = { onAction(PracticeSettingsAction.CloseSheet) },
        modifier = modifier,
    ) {
        month.allowed.forEach { offset ->
            AwradOptionRow(
                label = stringResource(offsetLabel(offset)),
                selected = offset == month.offset,
                onClick = { onAction(PracticeSettingsAction.Adjust(month.year, month.month, offset)) },
            )
        }
    }
}

@Composable
private fun SheetColumn(
    title: String,
    note: String,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val spacing = AwradTheme.spacing
    AwradBottomSheet(onDismissRequest = onClose, modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = spacing.pageMargin)
                .padding(bottom = spacing.sectionGap),
            verticalArrangement = Arrangement.spacedBy(spacing.rowGap),
        ) {
            Text(
                text = title,
                modifier = Modifier.semantics { heading() },
                style = AwradTheme.type.title,
                color = AwradTheme.colors.onSurface,
            )
            Note(text = note)
            content()
        }
    }
}
