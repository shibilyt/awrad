package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.HijriAnchor
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.LANG_AR
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.LANG_EN
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.RepeatSpec
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.SegmentKind
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdCadence
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdPart
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSchedule
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSegment
import app.awrad.awrad_dhikrgoalstracker.data.repository.WirdLibraryRepository
import app.awrad.awrad_dhikrgoalstracker.notification.WirdReminderScheduler
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class WirdEditorViewModel @Inject constructor(
    private val repository: WirdLibraryRepository,
    private val reminderScheduler: WirdReminderScheduler,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val editingWirdId: String? = savedStateHandle["wirdId"]
    val isEditing: Boolean = editingWirdId != null

    private val _draft = MutableStateFlow(blankWird())
    val draft: StateFlow<Wird> = _draft.asStateFlow()

    init {
        if (editingWirdId != null) {
            viewModelScope.launch {
                repository.getWird(editingWirdId)?.let { _draft.value = it }
            }
        }
    }

    // §5.4 — name (EN) non-empty AND at least one part has at least one countable segment with non-empty Arabic.
    val canSave: Boolean
        get() {
            val d = _draft.value
            val nameOk = d.localizedName[LANG_EN]?.isNotBlank() == true
            val partOk = d.parts.any { part ->
                part.segments.any { it.isCountable && it.arabic.isNotBlank() }
            }
            return nameOk && partOk
        }

    // --- Details ---
    fun setName(lang: String, value: String) = _draft.update {
        it.copy(localizedName = it.localizedName.withValue(lang, value))
    }

    fun setDescription(value: String) = _draft.update {
        it.copy(localizedDescription = it.localizedDescription.withValue(LANG_EN, value))
    }

    fun setSource(value: String) = _draft.update {
        it.copy(sourceAttribution = value.ifBlank { null })
    }

    // --- Schedule ---
    fun setCadence(cadence: WirdCadence) = _draft.update {
        it.copy(schedule = it.schedule.copy(cadence = cadence))
    }

    fun setHijriAnchor(anchor: HijriAnchor?) = _draft.update {
        it.copy(schedule = it.schedule.copy(hijriAnchor = anchor))
    }

    fun setDefaultOccasion(occasion: WirdOccasion) = _draft.update {
        it.copy(schedule = it.schedule.copy(defaultOccasion = occasion))
    }

    // --- Parts ---
    fun addPart() = _draft.update {
        it.copy(parts = it.parts + WirdPart(id = UUID.randomUUID().toString()))
    }

    fun updatePart(index: Int, part: WirdPart) = _draft.update {
        it.copy(parts = it.parts.replaceAt(index, part))
    }

    fun deletePart(index: Int) = _draft.update {
        it.copy(parts = it.parts.removeAt(index))
    }

    fun movePart(index: Int, delta: Int) = _draft.update {
        it.copy(parts = it.parts.swap(index, index + delta))
    }

    // --- Segments (within a part) ---
    fun addSegment(partIndex: Int) = mutatePart(partIndex) { part ->
        part.copy(segments = part.segments + WirdSegment(id = UUID.randomUUID().toString()))
    }

    fun updateSegment(partIndex: Int, segIndex: Int, segment: WirdSegment) = mutatePart(partIndex) { part ->
        part.copy(segments = part.segments.replaceAt(segIndex, segment))
    }

    fun deleteSegment(partIndex: Int, segIndex: Int) = mutatePart(partIndex) { part ->
        part.copy(segments = part.segments.removeAt(segIndex))
    }

    private fun mutatePart(index: Int, transform: (WirdPart) -> WirdPart) = _draft.update {
        val part = it.parts.getOrNull(index) ?: return@update it
        it.copy(parts = it.parts.replaceAt(index, transform(part)))
    }

    // --- Reminders ---
    fun addReminder() = _draft.update {
        it.copy(reminders = it.reminders + WirdReminder(id = UUID.randomUUID().toString(), hour = 7, minute = 0))
    }

    fun updateReminder(index: Int, reminder: WirdReminder) = _draft.update {
        it.copy(reminders = it.reminders.replaceAt(index, reminder))
    }

    fun deleteReminder(index: Int) = _draft.update {
        it.copy(reminders = it.reminders.removeAt(index))
    }

    fun save(onSaved: (String) -> Unit) {
        if (!canSave) return
        viewModelScope.launch {
            val saved = if (isEditing) {
                repository.updateWird(_draft.value)
                _draft.value
            } else {
                repository.createWird(_draft.value)
            }
            reminderScheduler.schedule(saved)
            onSaved(saved.id)
        }
    }

    fun delete(onDeleted: () -> Unit) {
        viewModelScope.launch {
            val wird = _draft.value
            reminderScheduler.cancel(wird.id, wird.reminders.map { it.id })
            repository.deleteWird(wird)
            onDeleted()
        }
    }

    private fun blankWird(): Wird = Wird(
        id = UUID.randomUUID().toString(),
        slug = "",
        isCustom = true,
        schedule = WirdSchedule(),
        parts = listOf(WirdPart(id = UUID.randomUUID().toString())),
    )

    companion object {
        fun defaultSegment(): WirdSegment = WirdSegment(
            id = UUID.randomUUID().toString(),
            kind = SegmentKind.DHIKR,
            repeatSpec = RepeatSpec(count = 1),
        )
    }
}

// --- small immutable helpers ---
private fun Map<String, String>.withValue(key: String, value: String): Map<String, String> =
    toMutableMap().apply { if (value.isBlank()) remove(key) else put(key, value) }

private fun <T> List<T>.replaceAt(index: Int, value: T): List<T> =
    toMutableList().apply { if (index in indices) set(index, value) }

private fun <T> List<T>.removeAt(index: Int): List<T> =
    toMutableList().apply { if (index in indices) removeAt(index) }

private fun <T> List<T>.swap(a: Int, b: Int): List<T> =
    if (a in indices && b in indices) toMutableList().apply { val t = this[a]; this[a] = this[b]; this[b] = t } else this
