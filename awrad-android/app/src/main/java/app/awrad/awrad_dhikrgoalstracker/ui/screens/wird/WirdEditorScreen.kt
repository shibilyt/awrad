package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.Remove
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.HijriAnchor
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.LANG_AR
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.LANG_EN
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.RepeatSpec
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.SegmentKind
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdCadence
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdPart
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSegment
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.resolve
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualPrimaryButton
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualScreen
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import java.time.LocalDate

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun WirdEditorScreen(
    onNavigateBack: () -> Unit,
    onSaved: (wirdId: String) -> Unit,
    onDeleted: () -> Unit = onNavigateBack,
    viewModel: WirdEditorViewModel = hiltViewModel(),
) {
    val draft by viewModel.draft.collectAsStateWithLifecycle()
    var showDelete by remember { mutableStateOf(false) }

    val canSave = draft.localizedName[LANG_EN]?.isNotBlank() == true &&
        draft.parts.any { p -> p.segments.any { it.isCountable && it.arabic.isNotBlank() } }

    RitualScreen {
        Scaffold(
            containerColor = Color.Transparent,
            contentWindowInsets = WindowInsets(0),
            topBar = {
                TopAppBar(
                    title = {
                        Text(stringResource(if (viewModel.isEditing) R.string.wird_edit_title else R.string.wird_create_title))
                    },
                    navigationIcon = {
                        IconButton(onClick = onNavigateBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                        }
                    },
                    actions = {
                        if (viewModel.isEditing) {
                            IconButton(onClick = { showDelete = true }) {
                                Icon(
                                    Icons.Outlined.DeleteOutline,
                                    contentDescription = stringResource(R.string.wird_delete),
                                    tint = MaterialTheme.colorScheme.error,
                                )
                            }
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent,
                        navigationIconContentColor = MaterialTheme.colorScheme.onSurface,
                        titleContentColor = MaterialTheme.colorScheme.onSurface,
                        actionIconContentColor = MaterialTheme.colorScheme.onSurface,
                    ),
                    windowInsets = WindowInsets.statusBars,
                )
            },
            bottomBar = {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .navigationBarsPadding()
                        .padding(horizontal = 20.dp)
                        .padding(top = 8.dp, bottom = 16.dp),
                ) {
                    RitualPrimaryButton(
                        text = stringResource(R.string.wird_save),
                        onClick = { viewModel.save(onSaved) },
                        enabled = canSave,
                    )
                }
            },
        ) { padding ->
            Column(
                Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                // Details
                SectionTitle(
                    title = stringResource(R.string.wird_details),
                    topPadding = 4.dp,
                )
                WirdTextField(
                    value = draft.localizedName[LANG_EN] ?: "",
                    onValueChange = { viewModel.setName(LANG_EN, it) },
                    label = stringResource(R.string.wird_name_en),
                )
                WirdTextField(
                    value = draft.localizedName[LANG_AR] ?: "",
                    onValueChange = { viewModel.setName(LANG_AR, it) },
                    label = stringResource(R.string.wird_name_ar),
                    arabic = true,
                )
                WirdTextField(
                    value = draft.localizedDescription[LANG_EN] ?: "",
                    onValueChange = { viewModel.setDescription(it) },
                    label = stringResource(R.string.wird_description_label),
                    singleLine = false,
                )
                WirdTextField(
                    value = draft.sourceAttribution ?: "",
                    onValueChange = { viewModel.setSource(it) },
                    label = stringResource(R.string.wird_source_label),
                )

                // Schedule
                SectionTitle(stringResource(R.string.wird_schedule))
                RitualCard(showBorder = true) {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        ScheduleEditor(
                            cadence = draft.schedule.cadence,
                            hijriAnchor = draft.schedule.hijriAnchor,
                            defaultOccasion = draft.schedule.defaultOccasion,
                            onCadence = viewModel::setCadence,
                            onHijri = viewModel::setHijriAnchor,
                            onOccasion = viewModel::setDefaultOccasion,
                        )
                    }
                }

                // Sections
                SectionTitle(stringResource(R.string.wird_sections_label))
                draft.parts.forEachIndexed { index, part ->
                    PartEditor(
                        index = index,
                        part = part,
                        onChange = { viewModel.updatePart(index, it) },
                        onDelete = { viewModel.deletePart(index) },
                        onAddSegment = { viewModel.addSegment(index) },
                        onUpdateSegment = { si, seg -> viewModel.updateSegment(index, si, seg) },
                        onDeleteSegment = { si -> viewModel.deleteSegment(index, si) },
                    )
                }
                AddButton(stringResource(R.string.wird_add_section), onClick = viewModel::addPart)

                // Reminders
                SectionTitle(stringResource(R.string.wird_reminders))
                if (draft.reminders.isEmpty()) {
                    Text(
                        stringResource(R.string.wird_no_reminders),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
                draft.reminders.forEachIndexed { index, reminder ->
                    ReminderEditor(
                        reminder = reminder,
                        onChange = { viewModel.updateReminder(index, it) },
                        onDelete = { viewModel.deleteReminder(index) },
                    )
                }
                AddButton(stringResource(R.string.wird_add_reminder), onClick = viewModel::addReminder)

                Spacer(Modifier.height(8.dp))
            }
        }
    }

    if (showDelete) {
        AlertDialog(
            onDismissRequest = { showDelete = false },
            title = { Text(stringResource(R.string.wird_delete_confirm)) },
            confirmButton = {
                TextButton(onClick = { showDelete = false; viewModel.delete(onDeleted) }) {
                    Text(stringResource(R.string.wird_delete), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDelete = false }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}

/* ----------------------------- Building blocks ----------------------------- */

@Composable
private fun SectionTitle(title: String, topPadding: androidx.compose.ui.unit.Dp = 12.dp) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleLarge,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurface,
        modifier = Modifier.padding(top = topPadding, bottom = 2.dp),
    )
}

@Composable
private fun FieldLabel(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurface,
        modifier = Modifier.padding(top = 2.dp),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WirdTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    singleLine: Boolean = true,
    arabic: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    val container = if (isAwradDarkTheme()) {
        MaterialTheme.colorScheme.surfaceContainerHigh
    } else {
        MaterialTheme.colorScheme.surface
    }
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        singleLine = singleLine,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        textStyle = if (arabic) {
            MaterialTheme.typography.bodyLarge.copy(fontFamily = NotoNaskhArabicFontFamily)
        } else {
            LocalTextStyleOrDefault()
        },
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        colors = OutlinedTextFieldDefaults.colors(
            focusedContainerColor = container,
            unfocusedContainerColor = container,
            focusedBorderColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.56f),
            unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.72f),
        ),
    )
}

@Composable
private fun LocalTextStyleOrDefault(): TextStyle = MaterialTheme.typography.bodyLarge

@Composable
private fun SelectChip(selected: Boolean, onClick: () -> Unit, label: String) {
    val cs = MaterialTheme.colorScheme
    val container = when {
        selected -> cs.primaryContainer
        isAwradDarkTheme() -> cs.surfaceContainerHigh
        else -> cs.surface
    }
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(14.dp),
        color = container,
        contentColor = if (selected) cs.onPrimaryContainer else cs.onSurfaceVariant,
        border = BorderStroke(
            1.dp,
            if (selected) cs.primary.copy(alpha = 0.36f) else cs.outlineVariant.copy(alpha = 0.6f),
        ),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 9.dp),
        )
    }
}

@Composable
private fun AddButton(text: String, onClick: () -> Unit) {
    val cs = MaterialTheme.colorScheme
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = Color.Transparent,
        contentColor = cs.primary,
        border = BorderStroke(1.dp, cs.primary.copy(alpha = 0.32f)),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 14.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text(text, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun StepperPill(value: Int, min: Int, max: Int, onChange: (Int) -> Unit) {
    val cs = MaterialTheme.colorScheme
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = if (isAwradDarkTheme()) cs.surfaceContainerHigh else cs.surfaceVariant.copy(alpha = 0.6f),
        border = BorderStroke(1.dp, cs.outlineVariant.copy(alpha = 0.6f)),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { if (value > min) onChange(value - 1) }, enabled = value > min) {
                Icon(
                    Icons.Outlined.Remove,
                    contentDescription = "−",
                    tint = if (value > min) cs.primary else cs.onSurfaceVariant.copy(alpha = 0.4f),
                )
            }
            Text(
                "$value",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = cs.onSurface,
                modifier = Modifier.width(28.dp),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
            IconButton(onClick = { if (value < max) onChange(value + 1) }, enabled = value < max) {
                Icon(
                    Icons.Outlined.Add,
                    contentDescription = "+",
                    tint = if (value < max) cs.primary else cs.onSurfaceVariant.copy(alpha = 0.4f),
                )
            }
        }
    }
}

@Composable
private fun StepperRow(label: String, value: Int, min: Int, max: Int, onChange: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            label,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        StepperPill(value, min, max, onChange)
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            label,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

/* ------------------------------- Schedule ------------------------------- */

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ScheduleEditor(
    cadence: WirdCadence,
    hijriAnchor: HijriAnchor?,
    defaultOccasion: WirdOccasion,
    onCadence: (WirdCadence) -> Unit,
    onHijri: (HijriAnchor?) -> Unit,
    onOccasion: (WirdOccasion) -> Unit,
) {
    FieldLabel(stringResource(R.string.wird_repeats))
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SelectChip(cadence is WirdCadence.EveryDay, { onCadence(WirdCadence.EveryDay) },
            stringResource(R.string.wird_cadence_every_day))
        SelectChip(cadence is WirdCadence.Rotation, { onCadence(WirdCadence.Rotation) },
            stringResource(R.string.wird_cadence_rotation))
        SelectChip(cadence is WirdCadence.DaysOfWeek, { onCadence(WirdCadence.DaysOfWeek(setOf(2, 5))) },
            stringResource(R.string.wird_cadence_specific_days))
        SelectChip(cadence is WirdCadence.Interval, { onCadence(WirdCadence.Interval(2, LocalDate.now().toString())) },
            stringResource(R.string.wird_cadence_interval, (cadence as? WirdCadence.Interval)?.days ?: 2))
    }
    if (cadence is WirdCadence.DaysOfWeek) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            (1..7).forEach { day ->
                val selected = cadence.days.contains(day)
                SelectChip(selected, {
                    val next = cadence.days.toMutableSet().apply { if (selected) remove(day) else add(day) }
                    onCadence(WirdCadence.DaysOfWeek(next))
                }, weekdayLabel(day))
            }
        }
    }
    if (cadence is WirdCadence.Interval) {
        StepperRow(
            label = stringResource(R.string.wird_cadence_interval, cadence.days),
            value = cadence.days, min = 1, max = 60,
            onChange = { onCadence(cadence.copy(days = it)) },
        )
    }

    FieldLabel(stringResource(R.string.wird_season))
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SelectChip(hijriAnchor == null, { onHijri(null) }, stringResource(R.string.wird_season_all))
        SelectChip(hijriAnchor is HijriAnchor.Ramadan, { onHijri(HijriAnchor.Ramadan) },
            stringResource(R.string.wird_season_ramadan))
        SelectChip(hijriAnchor is HijriAnchor.LastTenNights, { onHijri(HijriAnchor.LastTenNights) },
            stringResource(R.string.wird_season_last_ten))
    }

    FieldLabel(stringResource(R.string.wird_default_time))
    OccasionChips(defaultOccasion, onOccasion)
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun OccasionChips(occasion: WirdOccasion, onChange: (WirdOccasion) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SelectChip(occasion is WirdOccasion.Anytime, { onChange(WirdOccasion.Anytime) }, occasionLabel(WirdOccasion.Anytime))
        SelectChip(occasion is WirdOccasion.Morning, { onChange(WirdOccasion.Morning) }, occasionLabel(WirdOccasion.Morning))
        SelectChip(occasion is WirdOccasion.Evening, { onChange(WirdOccasion.Evening) }, occasionLabel(WirdOccasion.Evening))
        SelectChip(occasion is WirdOccasion.BeforeSleep, { onChange(WirdOccasion.BeforeSleep) }, occasionLabel(WirdOccasion.BeforeSleep))
        SelectChip(occasion is WirdOccasion.AfterPrayer, { onChange(WirdOccasion.AfterPrayer(Prayer.FAJR)) },
            stringResource(R.string.wird_reminder_prayer))
    }
    if (occasion is WirdOccasion.AfterPrayer) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Prayer.order.forEach { p ->
                SelectChip(occasion.prayer == p, { onChange(WirdOccasion.AfterPrayer(p)) }, prayerName(p))
            }
        }
    }
}

/* -------------------------------- Sections -------------------------------- */

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PartEditor(
    index: Int,
    part: WirdPart,
    onChange: (WirdPart) -> Unit,
    onDelete: () -> Unit,
    onAddSegment: () -> Unit,
    onUpdateSegment: (Int, WirdSegment) -> Unit,
    onDeleteSegment: (Int) -> Unit,
) {
    RitualCard(showBorder = true) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.wird_part_title) + " ${index + 1}",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = onDelete) {
                    Icon(
                        Icons.Outlined.DeleteOutline,
                        contentDescription = stringResource(R.string.wird_delete),
                        tint = MaterialTheme.colorScheme.error,
                    )
                }
            }
            WirdTextField(
                value = part.localizedTitle[LANG_EN] ?: "",
                onValueChange = { onChange(part.copy(localizedTitle = part.localizedTitle.put(LANG_EN, it))) },
                label = stringResource(R.string.wird_part_title),
            )
            WirdTextField(
                value = part.localizedSubtitle[LANG_EN] ?: "",
                onValueChange = { onChange(part.copy(localizedSubtitle = part.localizedSubtitle.put(LANG_EN, it))) },
                label = stringResource(R.string.wird_part_subtitle),
            )
            SwitchRow(
                label = stringResource(R.string.wird_custom_time),
                checked = part.occasion != null,
                onCheckedChange = { on -> onChange(part.copy(occasion = if (on) WirdOccasion.Morning else null)) },
            )
            if (part.occasion != null) {
                OccasionChips(part.occasion) { onChange(part.copy(occasion = it)) }
            }
            StepperRow(
                label = stringResource(R.string.wird_block_repeat, part.blockRepeat),
                value = part.blockRepeat, min = 1, max = 20,
                onChange = { onChange(part.copy(blockRepeat = it)) },
            )

            FieldLabel(stringResource(R.string.wird_items_label))
            if (part.segments.isEmpty()) {
                Text(
                    stringResource(R.string.wird_no_items),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            part.segments.forEachIndexed { si, seg ->
                SegmentEditor(
                    segment = seg,
                    onChange = { onUpdateSegment(si, it) },
                    onDelete = { onDeleteSegment(si) },
                )
            }
            AddButton(stringResource(R.string.wird_add_item), onClick = onAddSegment)
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SegmentEditor(
    segment: WirdSegment,
    onChange: (WirdSegment) -> Unit,
    onDelete: () -> Unit,
) {
    val cs = MaterialTheme.colorScheme
    RitualCard(
        showBorder = true,
        containerColor = if (isAwradDarkTheme()) {
            cs.surfaceContainerHighest.copy(alpha = 0.5f)
        } else {
            cs.surfaceVariant.copy(alpha = 0.4f)
        },
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                SegmentKind.entries.forEach { kind ->
                    SelectChip(segment.kind == kind, { onChange(segment.copy(kind = kind)) }, kindLabel(kind))
                }
            }
            if (segment.kind.isCountable) {
                WirdTextField(
                    value = segment.arabic,
                    onValueChange = { onChange(segment.copy(arabic = it)) },
                    label = stringResource(R.string.wird_arabic),
                    singleLine = false,
                    arabic = true,
                )
                WirdTextField(
                    value = segment.transliteration[LANG_EN] ?: "",
                    onValueChange = { onChange(segment.copy(transliteration = segment.transliteration.put(LANG_EN, it))) },
                    label = stringResource(R.string.wird_transliteration_label),
                    singleLine = false,
                )
                WirdTextField(
                    value = segment.translation[LANG_EN] ?: "",
                    onValueChange = { onChange(segment.copy(translation = segment.translation.put(LANG_EN, it))) },
                    label = stringResource(R.string.wird_translation_label),
                    singleLine = false,
                )
                RepeatEditor(segment.repeatSpec) { onChange(segment.copy(repeatSpec = it)) }
            } else {
                WirdTextField(
                    value = segment.localizedText[LANG_EN] ?: "",
                    onValueChange = { onChange(segment.copy(localizedText = segment.localizedText.put(LANG_EN, it))) },
                    label = stringResource(R.string.wird_text_label),
                    singleLine = false,
                )
            }
            TextButton(onClick = onDelete, modifier = Modifier.align(Alignment.End)) {
                Text(stringResource(R.string.wird_delete), color = cs.error)
            }
        }
    }
}

@Composable
private fun RepeatEditor(spec: RepeatSpec, onChange: (RepeatSpec) -> Unit) {
    val isRange = spec.min != null && spec.max != null
    SwitchRow(
        label = stringResource(R.string.wird_use_range),
        checked = isRange,
        onCheckedChange = { on ->
            onChange(if (on) RepeatSpec(count = spec.count, min = spec.target, max = spec.target + 1) else RepeatSpec(count = spec.target))
        },
    )
    if (isRange) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NumberField(stringResource(R.string.wird_min), spec.min ?: 1, Modifier.weight(1f)) { onChange(spec.copy(min = it)) }
            NumberField(stringResource(R.string.wird_max), spec.max ?: 1, Modifier.weight(1f)) { onChange(spec.copy(max = it)) }
        }
    } else {
        StepperRow(
            label = stringResource(R.string.wird_repetitions) + ": ${spec.target}",
            value = spec.target, min = 1, max = 1000,
            onChange = { onChange(RepeatSpec(count = it)) },
        )
    }
}

@Composable
private fun NumberField(label: String, value: Int, modifier: Modifier = Modifier, onChange: (Int) -> Unit) {
    WirdTextField(
        value = value.toString(),
        onValueChange = { it.toIntOrNull()?.let(onChange) },
        label = label,
        modifier = modifier,
        keyboardType = KeyboardType.Number,
    )
}

/* ------------------------------- Reminders ------------------------------- */

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ReminderEditor(
    reminder: app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdReminder,
    onChange: (app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdReminder) -> Unit,
    onDelete: () -> Unit,
) {
    val isFixed = reminder.reminderType == app.awrad.awrad_dhikrgoalstracker.data.model.wird.ReminderType.FIXED_TIME
    RitualCard(showBorder = true) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Switch(checked = reminder.enabled, onCheckedChange = { onChange(reminder.copy(enabled = it)) })
                Spacer(Modifier.width(12.dp))
                Text(
                    if (isFixed) stringResource(R.string.wird_reminder_fixed) else stringResource(R.string.wird_reminder_prayer),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = onDelete) {
                    Icon(
                        Icons.Outlined.DeleteOutline,
                        contentDescription = stringResource(R.string.wird_delete),
                        tint = MaterialTheme.colorScheme.error,
                    )
                }
            }
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SelectChip(isFixed, {
                    onChange(reminder.copy(reminderType = app.awrad.awrad_dhikrgoalstracker.data.model.wird.ReminderType.FIXED_TIME, hour = reminder.hour ?: 7, minute = reminder.minute ?: 0))
                }, stringResource(R.string.wird_reminder_fixed))
                SelectChip(!isFixed, {
                    onChange(reminder.copy(reminderType = app.awrad.awrad_dhikrgoalstracker.data.model.wird.ReminderType.PRAYER_OFFSET, prayer = reminder.prayer ?: Prayer.FAJR, offsetMinutes = reminder.offsetMinutes ?: 0))
                }, stringResource(R.string.wird_reminder_prayer))
            }
            if (isFixed) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    NumberField(stringResource(R.string.wird_hour_short), reminder.hour ?: 7, Modifier.weight(1f)) { onChange(reminder.copy(hour = it.coerceIn(0, 23))) }
                    NumberField(stringResource(R.string.wird_minute_short), reminder.minute ?: 0, Modifier.weight(1f)) { onChange(reminder.copy(minute = it.coerceIn(0, 59))) }
                }
            } else {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Prayer.order.forEach { p ->
                        SelectChip(reminder.prayer == p, { onChange(reminder.copy(prayer = p)) }, prayerName(p))
                    }
                }
                StepperRow(
                    label = stringResource(R.string.wird_offset_min) + ": ${reminder.offsetMinutes ?: 0}",
                    value = reminder.offsetMinutes ?: 0, min = 0, max = 120,
                    onChange = { onChange(reminder.copy(offsetMinutes = it)) },
                )
            }
        }
    }
}

/* -------------------------------- Helpers -------------------------------- */

@Composable
private fun kindLabel(kind: SegmentKind): String = stringResource(
    when (kind) {
        SegmentKind.DHIKR -> R.string.wird_kind_dhikr
        SegmentKind.DUA -> R.string.wird_kind_dua
        SegmentKind.SALAH -> R.string.wird_kind_salah
        SegmentKind.QURAN -> R.string.wird_kind_quran
        SegmentKind.HEADING -> R.string.wird_kind_heading
        SegmentKind.INSTRUCTION -> R.string.wird_kind_instruction
    },
)

@Composable
private fun weekdayLabel(sundayBased: Int): String {
    val dow = if (sundayBased == 1) java.time.DayOfWeek.SUNDAY else java.time.DayOfWeek.of(sundayBased - 1)
    val locale = androidx.compose.ui.platform.LocalConfiguration.current.locales[0]
    return dow.getDisplayName(java.time.format.TextStyle.SHORT, locale)
}

private fun Map<String, String>.put(key: String, value: String): Map<String, String> =
    toMutableMap().apply { if (value.isBlank()) remove(key) else put(key, value) }
