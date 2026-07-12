package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import app.awrad.awrad_dhikrgoalstracker.data.model.wird.SegmentKind
import app.awrad.awrad_dhikrgoalstracker.data.wird.segment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Pure helpers behind the tap-to-flow reader: scroll-lock anchor, line navigation, font steps. */
class WirdReaderFlowTest {

    private fun page(
        id: String,
        kind: SegmentKind = SegmentKind.DHIKR,
        target: Int = 1,
        count: Int = 0,
    ) = ReaderPage(segment = segment(id, kind = kind, count = target), effectiveTarget = target, count = count)

    // --- firstLockedLine ---

    @Test
    fun firstLockedLine_noRepeatLines_returnsNull() {
        val pages = listOf(page("a"), page("b"), page("c", kind = SegmentKind.INSTRUCTION))
        assertNull(firstLockedLine(pages))
    }

    @Test
    fun firstLockedLine_findsFirstUnfinishedRepeatLine() {
        val pages = listOf(
            page("a"), // plain, never locks
            page("b", target = 3, count = 3), // repeat but finished
            page("c", target = 7, count = 2), // first unfinished repeat
            page("d", target = 3),
        )
        assertEquals(2, firstLockedLine(pages))
    }

    @Test
    fun firstLockedLine_allRepeatLinesFinished_returnsNull() {
        val pages = listOf(page("a", target = 3, count = 3), page("b", target = 2, count = 5))
        assertNull(firstLockedLine(pages))
    }

    // --- next/prev/nearest actionable (headings are never active) ---

    @Test
    fun nextActionable_skipsHeadings() {
        val pages = listOf(
            page("a"),
            page("h", kind = SegmentKind.HEADING),
            page("b"),
        )
        assertEquals(2, nextActionable(pages, 0))
    }

    @Test
    fun nextActionable_atEnd_returnsNull() {
        val pages = listOf(page("a"), page("h", kind = SegmentKind.HEADING))
        assertNull(nextActionable(pages, 0))
    }

    @Test
    fun prevActionable_skipsHeadings() {
        val pages = listOf(
            page("a"),
            page("h", kind = SegmentKind.HEADING),
            page("b"),
        )
        assertEquals(0, prevActionable(pages, 2))
    }

    @Test
    fun prevActionable_atStart_returnsNull() {
        val pages = listOf(page("a"), page("b"))
        assertNull(prevActionable(pages, 0))
    }

    @Test
    fun nearestActionableAt_headingResolvesToNextLine() {
        val pages = listOf(
            page("a"),
            page("h", kind = SegmentKind.HEADING),
            page("b"),
        )
        assertEquals(2, nearestActionableAt(pages, 1))
    }

    @Test
    fun nearestActionableAt_trailingHeadingFallsBackToPreviousLine() {
        val pages = listOf(page("a"), page("h", kind = SegmentKind.HEADING))
        assertEquals(0, nearestActionableAt(pages, 1))
    }

    @Test
    fun nearestActionableAt_clampsOutOfBounds() {
        val pages = listOf(page("a"), page("b"))
        assertEquals(1, nearestActionableAt(pages, 99))
        assertEquals(0, nearestActionableAt(pages, -5))
    }

    // --- progress = completed repetitions over total repetitions ---

    @Test
    fun repetitionTotals_sumCountablesAndCapCounts() {
        val state = WirdReaderUiState(
            pages = listOf(
                page("h", kind = SegmentKind.HEADING),
                page("a", target = 3, count = 2),
                page("b", target = 7, count = 9), // over-count caps at target
                page("i", kind = SegmentKind.INSTRUCTION),
                page("c"),
            ),
        )
        assertEquals(11, state.totalRepetitions)
        assertEquals(9, state.completedRepetitions)
    }

    // --- font scale cycling ---

    @Test
    fun nextReaderFontScale_cyclesThroughStepsAndWraps() {
        assertEquals(1f, nextReaderFontScale(0.85f))
        assertEquals(1.15f, nextReaderFontScale(1f))
        assertEquals(1.3f, nextReaderFontScale(1.15f))
        assertEquals(0.85f, nextReaderFontScale(1.3f))
    }

    @Test
    fun nextReaderFontScale_unknownValueSnapsIntoCycle() {
        assertEquals(1.15f, nextReaderFontScale(1.02f))
    }
}
