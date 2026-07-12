package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.QuranToken
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.QURAN_SURAH_NAMES
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.buildQuranAnnotated
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.quranQuoteRanges
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.splitBismillah
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.surahName
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.tokenizeQuranText
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.toArabicIndicDigits
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class QuranRenderingTest {

    // --- surah names table ---

    @Test
    fun surahTable_has114UniqueEntries() {
        assertEquals(114, QURAN_SURAH_NAMES.size)
        assertEquals(114, QURAN_SURAH_NAMES.map { it.arabic }.toSet().size)
        assertEquals(114, QURAN_SURAH_NAMES.map { it.transliteration }.toSet().size)
    }

    @Test
    fun surahName_resolvesKnownSurahs() {
        assertEquals("الفاتحة", surahName(1)?.arabic)
        assertEquals("Yā Sīn", surahName(36)?.transliteration)
        assertEquals("الإخلاص", surahName(112)?.arabic)
        assertEquals("An-Nās", surahName(114)?.transliteration)
    }

    @Test
    fun surahName_outOfRange_returnsNull() {
        assertNull(surahName(0))
        assertNull(surahName(115))
    }

    // --- digits ---

    @Test
    fun toArabicIndicDigits_convertsMultiDigitNumbers() {
        assertEquals("٧", toArabicIndicDigits(7))
        assertEquals("٢٥٥", toArabicIndicDigits(255))
    }

    // --- ayah marker tokenization ---

    @Test
    fun tokenize_parenMarkers_becomeAyahMedallions() {
        val tokens = tokenizeQuranText("الْحَمْدُ لِلَّهِ (2) الرَّحْمَٰنِ الرَّحِيمِ (3)")
        assertEquals(
            listOf(
                QuranToken.Body("الْحَمْدُ لِلَّهِ"),
                QuranToken.AyahMarker("۝٢"),
                QuranToken.Body("الرَّحْمَٰنِ الرَّحِيمِ"),
                QuranToken.AyahMarker("۝٣"),
            ),
            tokens,
        )
    }

    @Test
    fun tokenize_arabicIndicDigitsInParens_normalize() {
        val tokens = tokenizeQuranText("قُلْ هُوَ اللَّهُ أَحَدٌ (١)")
        assertEquals(QuranToken.AyahMarker("۝١"), tokens[1])
    }

    @Test
    fun tokenize_existingAyahSign_keepsNumber() {
        val tokens = tokenizeQuranText("مَالِكِ يَوْمِ الدِّينِ ۝4 إِيَّاكَ نَعْبُدُ")
        assertEquals(
            listOf(
                QuranToken.Body("مَالِكِ يَوْمِ الدِّينِ"),
                QuranToken.AyahMarker("۝٤"),
                QuranToken.Body("إِيَّاكَ نَعْبُدُ"),
            ),
            tokens,
        )
    }

    @Test
    fun tokenize_bareAyahSign_hasNoDigits() {
        val tokens = tokenizeQuranText("آية ۝ تكملة")
        assertEquals(QuranToken.AyahMarker("۝"), tokens[1])
    }

    @Test
    fun tokenize_plainTextWithoutMarkers_isSingleBody() {
        val tokens = tokenizeQuranText("نص بلا علامات")
        assertEquals(listOf<QuranToken>(QuranToken.Body("نص بلا علامات")), tokens)
    }

    // --- bismillah split ---

    @Test
    fun splitBismillah_firstLineBismillah_isSeparated() {
        val raw = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\nقُلْ هُوَ اللَّهُ أَحَدٌ (1)"
        val (bismillah, body) = splitBismillah(raw)
        assertEquals("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ", bismillah)
        assertEquals("قُلْ هُوَ اللَّهُ أَحَدٌ (1)", body)
    }

    @Test
    fun splitBismillah_waslaVariant_matches() {
        val raw = "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ\nالْحَمْدُ لِلَّهِ"
        val (bismillah, _) = splitBismillah(raw)
        assertEquals("بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ", bismillah)
    }

    @Test
    fun splitBismillah_noNewline_returnsWholeBody() {
        val raw = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ الْحَمْدُ لِلَّهِ (1)"
        val (bismillah, body) = splitBismillah(raw)
        assertNull(bismillah)
        assertEquals(raw, body)
    }

    @Test
    fun splitBismillah_ordinaryFirstLine_notSplit() {
        val raw = "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ\nوَعَلَى آلِ مُحَمَّدٍ"
        val (bismillah, body) = splitBismillah(raw)
        assertNull(bismillah)
        assertEquals(raw, body)
    }

    // --- embedded quote ranges ---

    @Test
    fun quranQuoteRanges_findsBracketedSpans() {
        val text = "قال تعالى ﴿إِنَّ اللَّهَ وَمَلَائِكَتَهُ﴾ صدق الله"
        val ranges = quranQuoteRanges(text)
        assertEquals(1, ranges.size)
        assertEquals('﴿', text[ranges[0].first])
        assertEquals('﴾', text[ranges[0].last])
    }

    @Test
    fun quranQuoteRanges_noBrackets_isEmpty() {
        assertTrue(quranQuoteRanges("لا اقتباس هنا").isEmpty())
    }

    @Test
    fun quranQuoteRanges_unclosedBracket_ignored() {
        assertTrue(quranQuoteRanges("﴿ بداية بلا نهاية").isEmpty())
    }

    // --- annotated assembly ---

    @Test
    fun buildQuranAnnotated_joinsTokensWithSpacedMedallions() {
        val annotated = buildQuranAnnotated(
            listOf(
                QuranToken.Body("الْحَمْدُ لِلَّهِ"),
                QuranToken.AyahMarker("۝٢"),
                QuranToken.Body("الرَّحْمَٰنِ"),
            ),
            markerStyle = androidx.compose.ui.text.SpanStyle(),
        )
        assertEquals("الْحَمْدُ لِلَّهِ ۝٢ الرَّحْمَٰنِ", annotated.text)
    }
}
