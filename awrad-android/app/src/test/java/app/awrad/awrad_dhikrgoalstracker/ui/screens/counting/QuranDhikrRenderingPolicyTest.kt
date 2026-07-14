package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import app.awrad.awrad_dhikrgoalstracker.data.database.BuiltInDhikrs
import app.awrad.awrad_dhikrgoalstracker.data.model.QuranRef
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.QuranToken
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.splitBismillah
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.shouldRenderFullQuranInline
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.tokenizeQuranText
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class QuranDhikrRenderingPolicyTest {

    @Test
    fun `seeded Ikhlas has structured Quran identity and four ayah markers`() {
        val ikhlas = BuiltInDhikrs.dhikrs.first { it.title == "Surah Ikhlas" }
        val (bismillah, body) = splitBismillah(ikhlas.arabic)

        assertEquals(112, ikhlas.quranSurah)
        assertEquals(1, ikhlas.quranAyahStart)
        assertEquals(4, ikhlas.quranAyahEnd)
        assertTrue(bismillah?.isNotBlank() == true)
        assertEquals(4, tokenizeQuranText(body).count { it is QuranToken.AyahMarker })
    }

    @Test
    fun `short valid Quran reference renders fully inline`() {
        assertTrue(shouldRenderFullQuranInline(QuranRef(112, 1, 4), "short Arabic body"))
    }

    @Test
    fun `long or invalid Quran reference uses preview fallback`() {
        assertFalse(shouldRenderFullQuranInline(QuranRef(2, 1, 20), "body"))
        assertFalse(shouldRenderFullQuranInline(QuranRef(0, 0), "body"))
        assertFalse(shouldRenderFullQuranInline(QuranRef(1, 1, 7), "x".repeat(701)))
    }

    @Test
    fun `non Quran seed has no Quran metadata`() {
        val tahleel = BuiltInDhikrs.dhikrs.first { it.title == "Tahleel" }
        assertNull(tahleel.quranSurah)
        assertNull(tahleel.quranAyahStart)
        assertNull(tahleel.quranAyahEnd)
    }
}
