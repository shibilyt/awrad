package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.LocalizedString
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.SegmentKind
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdPart
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSegment
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSession
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.data.repository.WirdLibraryRepository
import app.awrad.awrad_dhikrgoalstracker.data.wird.WirdEngine
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject

data class ReaderPage(
    val segment: WirdSegment,
    val effectiveTarget: Int,
    val count: Int,
) {
    val isCountable: Boolean get() = segment.isCountable
    val isSegmentComplete: Boolean get() = !isCountable || count >= effectiveTarget

    /** A repeat line locks the scroll until its count is finished; plain lines flow past freely. */
    val isRepeatLine: Boolean get() = isCountable && effectiveTarget > 1
}

/**
 * A contiguous run of [ReaderPage]s in the Contents sheet. [titleLocalized] is the raw map for the
 * originating HEADING segment (null for the leading section before any heading), resolved by the UI.
 */
data class ReaderSection(
    val titleLocalized: LocalizedString?,
    val startPage: Int,
    val endPageInclusive: Int,
)

/**
 * Splits [pages] into sections at each HEADING segment. Pages before the first heading form a
 * leading section with a null title (UI falls back to the part title). Pure + side-effect free so
 * it is directly unit-testable — see WirdReaderSectionsTest.
 */
internal fun deriveSections(pages: List<ReaderPage>): List<ReaderSection> {
    if (pages.isEmpty()) return emptyList()

    val headingIndexes = pages.withIndex()
        .filter { (_, page) -> page.segment.kind == SegmentKind.HEADING }
        .map { it.index }

    if (headingIndexes.isEmpty()) {
        return listOf(ReaderSection(titleLocalized = null, startPage = 0, endPageInclusive = pages.lastIndex))
    }

    val sections = mutableListOf<ReaderSection>()
    if (headingIndexes.first() > 0) {
        sections += ReaderSection(
            titleLocalized = null,
            startPage = 0,
            endPageInclusive = headingIndexes.first() - 1,
        )
    }
    headingIndexes.forEachIndexed { i, headingIndex ->
        val end = if (i + 1 < headingIndexes.size) headingIndexes[i + 1] - 1 else pages.lastIndex
        sections += ReaderSection(
            titleLocalized = pages[headingIndex].segment.localizedText,
            startPage = headingIndex,
            endPageInclusive = end,
        )
    }
    return sections
}

/** Headings are structural: they can never be the active line and never lock the scroll. */
internal fun ReaderPage.isActionableLine(): Boolean = segment.kind != SegmentKind.HEADING

/**
 * Index of the first repeat line (target > 1) whose count is unfinished — the anchor the scroll
 * lock clamps to. Null when nothing ahead requires counting.
 */
internal fun firstLockedLine(pages: List<ReaderPage>): Int? =
    pages.indexOfFirst { it.isRepeatLine && it.count < it.effectiveTarget }.takeIf { it >= 0 }

internal fun nextActionable(pages: List<ReaderPage>, from: Int): Int? =
    ((from + 1)..pages.lastIndex).firstOrNull { pages.getOrNull(it)?.isActionableLine() == true }

internal fun prevActionable(pages: List<ReaderPage>, from: Int): Int? =
    ((from - 1) downTo 0).firstOrNull { pages.getOrNull(it)?.isActionableLine() == true }

/** The actionable line at [at], or the nearest one after it (falling back to the nearest before). */
internal fun nearestActionableAt(pages: List<ReaderPage>, at: Int): Int {
    if (pages.isEmpty()) return 0
    val index = at.coerceIn(0, pages.lastIndex)
    if (pages[index].isActionableLine()) return index
    return nextActionable(pages, index) ?: prevActionable(pages, index) ?: index
}

/** Discrete text-size steps for the reader's "A" control, cycling back to the smallest. */
internal val READER_FONT_SCALES = listOf(0.85f, 1f, 1.15f, 1.3f)

internal fun nextReaderFontScale(current: Float): Float =
    READER_FONT_SCALES.firstOrNull { it > current + 0.01f } ?: READER_FONT_SCALES.first()

data class WirdReaderUiState(
    val wird: Wird? = null,
    val part: WirdPart? = null,
    val pages: List<ReaderPage> = emptyList(),
    val initialPage: Int = 0,
    val isPartComplete: Boolean = false,
    val streak: Int = 0,
    val isLoading: Boolean = true,
    val sections: List<ReaderSection> = emptyList(),
    val nextPart: WirdPart? = null,
) {
    /** Total repetitions across countable lines — the denominator of the top progress bar. */
    val totalRepetitions: Int get() = pages.sumOf { if (it.isCountable) it.effectiveTarget else 0 }
    val completedRepetitions: Int get() =
        pages.sumOf { if (it.isCountable) minOf(it.count, it.effectiveTarget) else 0 }
}

/** Emitted after a recite tap so the screen can drive haptics + auto-advance. */
data class ReciteEvent(val pageIndex: Int, val justCompleted: Boolean)

@HiltViewModel
class WirdReaderViewModel @Inject constructor(
    private val repository: WirdLibraryRepository,
    private val engine: WirdEngine,
    private val dateProvider: DateProvider,
    private val userPreferences: UserPreferences,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val wirdId: String = checkNotNull(savedStateHandle["wirdId"])
    private val partId: String = checkNotNull(savedStateHandle["partId"])

    val vibrateOnCount: StateFlow<Boolean> = userPreferences.vibrateOnCount
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    val readerFontScale: StateFlow<Float> = userPreferences.readerFontScale
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 1f)

    private val _uiState = MutableStateFlow(WirdReaderUiState())
    val uiState: StateFlow<WirdReaderUiState> = _uiState.asStateFlow()

    private val _reciteEvents = MutableSharedFlow<ReciteEvent>(extraBufferCapacity = 8)
    val reciteEvents: MutableSharedFlow<ReciteEvent> = _reciteEvents

    /** Serializes recites: tap-to-count can fire rapidly and each write must see the previous one. */
    private val reciteMutex = Mutex()

    private lateinit var dateKey: String

    init {
        viewModelScope.launch { load() }
    }

    private suspend fun load() {
        dateKey = dateProvider.getEffectiveToday()
        val wird = repository.getWird(wirdId)
        val part = wird?.part(partId)
        if (wird == null || part == null) {
            _uiState.value = WirdReaderUiState(isLoading = false)
            return
        }
        val session = repository.getSession(wird, part, dateKey)
        val pages = part.segments.map { seg ->
            ReaderPage(
                segment = seg,
                effectiveTarget = engine.effectiveTarget(seg, part),
                count = session?.count(seg.id) ?: 0,
            )
        }
        val isPartComplete = engine.isPartComplete(part, session)
        _uiState.value = WirdReaderUiState(
            wird = wird,
            part = part,
            pages = pages,
            initialPage = resumeIndex(pages),
            isPartComplete = isPartComplete,
            streak = repository.streak(wird, dateKey),
            isLoading = false,
            sections = deriveSections(pages),
            nextPart = computeNextPart(wird, part),
        )
    }

    /**
     * The next active-but-incomplete part for today, if any, so the completion overlay can offer a
     * "continue" shortcut. Monday (Dalail) has at most two active parts, so this stays cheap.
     */
    private suspend fun computeNextPart(wird: Wird, currentPart: WirdPart): WirdPart? {
        val date = WirdEngine.parseDateKeyOrNull(dateKey) ?: return null
        val active = engine.activeParts(wird, date)
        if (active.none { it.id == currentPart.id }) return null
        return active.firstOrNull { candidate ->
            candidate.id != currentPart.id &&
                !engine.isPartComplete(candidate, repository.getSession(wird, candidate, dateKey))
        }
    }

    /** Resume to first not-yet-complete countable segment; if all done, last page. */
    private fun resumeIndex(pages: List<ReaderPage>): Int {
        val idx = pages.indexOfFirst { it.isCountable && it.count < it.effectiveTarget }
        return if (idx >= 0) idx else (pages.size - 1).coerceAtLeast(0)
    }

    /**
     * Increments a countable line. [silent] recites come from scroll-past auto-completion of plain
     * lines: they persist the count but emit no [ReciteEvent], so no haptic or auto-advance fires.
     */
    fun recite(pageIndex: Int, silent: Boolean = false) {
        viewModelScope.launch {
            reciteMutex.withLock {
                val state = _uiState.value
                val wird = state.wird ?: return@withLock
                val part = state.part ?: return@withLock
                val page = state.pages.getOrNull(pageIndex) ?: return@withLock
                if (!page.isCountable || page.count >= page.effectiveTarget) return@withLock

                val newCount = repository.incrementSegment(wird, part, page.segment, dateKey)
                val updated = state.pages.toMutableList().also {
                    it[pageIndex] = page.copy(count = newCount)
                }
                val justCompleted = newCount >= page.effectiveTarget
                val complete = engine.isPartComplete(part, sessionFromPages(updated))
                val completionChanged = complete != state.isPartComplete
                _uiState.value = state.copy(
                    pages = updated,
                    isPartComplete = complete,
                    streak = if (complete && !state.isPartComplete) repository.streak(wird, dateKey) else state.streak,
                    nextPart = if (completionChanged) computeNextPart(wird, part) else state.nextPart,
                )
                if (!silent) _reciteEvents.tryEmit(ReciteEvent(pageIndex, justCompleted))
            }
        }
    }

    fun updateReadingPosition(pageIndex: Int) {
        val state = _uiState.value
        val wird = state.wird ?: return
        val part = state.part ?: return
        val seg = state.pages.getOrNull(pageIndex)?.segment ?: return
        viewModelScope.launch {
            repository.updateReadingPosition(wird, part, seg.id, dateKey)
        }
    }

    fun cycleFontScale() {
        viewModelScope.launch {
            userPreferences.setReaderFontScale(nextReaderFontScale(readerFontScale.value))
        }
    }

    fun readAgain() {
        val state = _uiState.value
        val wird = state.wird ?: return
        val part = state.part ?: return
        viewModelScope.launch {
            repository.resetSession(wird, part, dateKey)
            _uiState.value = state.copy(
                pages = state.pages.map { it.copy(count = 0) },
                isPartComplete = false,
            )
        }
    }

    /** Transient session view from current page counts, for completion checks. */
    private fun sessionFromPages(pages: List<ReaderPage>): WirdSession = WirdSession(
        wirdID = wirdId,
        partID = partId,
        dateKey = dateKey,
        segmentProgress = pages.associate { it.segment.id to it.count },
    )
}
