package app.awrad.awrad_dhikrgoalstracker.data.model.wird

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

class LocalizedStringTest {

    @Test
    fun `decodes legacy percent-encoded utf8 names`() {
        val encoded = mapOf(
            "en" to "Morning Adhkar%D8%B3%D8%A8%D8%AD%D8%A7%D9%86%20%D8%A7%D9%84%D9%84%D9%87",
        )
        assertEquals(
            "Morning Adhkarسبحان الله",
            encoded.decodedFromLegacyEncoding()["en"],
        )
    }

    @Test
    fun `leaves clean values untouched`() {
        val clean: LocalizedString = mapOf("en" to "Morning Adhkar", "ar" to "أذكار الصباح")
        // No percent escapes: returns the same instance (no allocation/rewrite).
        assertSame(clean, clean.decodedFromLegacyEncoding())
    }

    @Test
    fun `does not treat plus as space and ignores non-escape percents`() {
        val value = mapOf("en" to "Rabbana + 100% effort")
        assertEquals("Rabbana + 100% effort", value.decodedFromLegacyEncoding()["en"])
    }

    @Test
    fun `reverts when decoding yields invalid utf8`() {
        // 0xFF is not a valid UTF-8 lead byte → decoding would corrupt → keep original.
        val value = mapOf("en" to "abc%FF")
        assertEquals("abc%FF", value.decodedFromLegacyEncoding()["en"])
    }

    @Test
    fun `decodes only the encoded entries in a mixed map`() {
        val mixed = mapOf("en" to "Clean", "ar" to "%D8%A7%D9%84%D9%84%D9%87")
        val result = mixed.decodedFromLegacyEncoding()
        assertEquals("Clean", result["en"])
        assertEquals("الله", result["ar"])
    }
}
