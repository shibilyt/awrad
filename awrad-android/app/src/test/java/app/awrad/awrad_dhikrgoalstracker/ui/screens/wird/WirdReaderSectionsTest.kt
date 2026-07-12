package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import app.awrad.awrad_dhikrgoalstracker.data.model.wird.SegmentKind
import app.awrad.awrad_dhikrgoalstracker.data.wird.segment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WirdReaderSectionsTest {

    private fun page(id: String, kind: SegmentKind = SegmentKind.DHIKR) =
        ReaderPage(segment = segment(id, kind = kind), effectiveTarget = 1, count = 0)

    // (d) empty list → no sections.
    @Test
    fun deriveSections_emptyList_returnsEmpty() {
        assertTrue(deriveSections(emptyList()).isEmpty())
    }

    // (a) no headings → a single section covering everything.
    @Test
    fun deriveSections_noHeadings_singleSection() {
        val pages = listOf(page("a"), page("b"), page("c"))
        val sections = deriveSections(pages)

        assertEquals(1, sections.size)
        assertNull(sections[0].titleLocalized)
        assertEquals(0, sections[0].startPage)
        assertEquals(2, sections[0].endPageInclusive)
    }

    // (b) pages before the first heading form a leading, untitled section.
    @Test
    fun deriveSections_leadingPagesBeforeFirstHeading_formUntitledSection() {
        val pages = listOf(
            page("intro1"),
            page("intro2"),
            page("h1", kind = SegmentKind.HEADING),
            page("d1"),
        )
        val sections = deriveSections(pages)

        assertEquals(2, sections.size)
        // Leading section: pages 0..1, no title.
        assertNull(sections[0].titleLocalized)
        assertEquals(0, sections[0].startPage)
        assertEquals(1, sections[0].endPageInclusive)
        // Heading-anchored section: pages 2..3.
        assertEquals(2, sections[1].startPage)
        assertEquals(3, sections[1].endPageInclusive)
    }

    // (c) multiple headings produce correctly bounded ranges, each starting at its heading page.
    @Test
    fun deriveSections_multipleHeadings_boundedRanges() {
        val pages = listOf(
            page("h1", kind = SegmentKind.HEADING), // 0
            page("d1"), // 1
            page("d2"), // 2
            page("h2", kind = SegmentKind.HEADING), // 3
            page("d3"), // 4
            page("h3", kind = SegmentKind.HEADING), // 5
            page("d4"), // 6
        )
        val sections = deriveSections(pages)

        assertEquals(3, sections.size)

        assertEquals(0, sections[0].startPage)
        assertEquals(2, sections[0].endPageInclusive)

        assertEquals(3, sections[1].startPage)
        assertEquals(4, sections[1].endPageInclusive)

        assertEquals(5, sections[2].startPage)
        assertEquals(6, sections[2].endPageInclusive)
    }

    // Back-to-back headings produce a single-page section for the first heading.
    @Test
    fun deriveSections_backToBackHeadings_produceSinglePageSections() {
        val pages = listOf(
            page("h1", kind = SegmentKind.HEADING), // 0
            page("h2", kind = SegmentKind.HEADING), // 1
            page("d1"), // 2
        )
        val sections = deriveSections(pages)

        assertEquals(2, sections.size)
        assertEquals(0, sections[0].startPage)
        assertEquals(0, sections[0].endPageInclusive)
        assertEquals(1, sections[1].startPage)
        assertEquals(2, sections[1].endPageInclusive)
    }
}
