package app.awrad.core.domain.dhikr

import app.awrad.core.domain.AwradId
import app.awrad.core.testing.contractCatalog
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

class DhikrDisplayTest {

    private val dhikr = Dhikr(
        id = AwradId("0f3f7d1e-2a4b-4c5d-8e6f-7a8b9c0d1e2f"),
        key = "sample",
        kind = DhikrKind.DHIKR,
        arabic = "سُبْحَانَ ٱللَّٰهِ",
        title = LocalizedText(en = "Tasbeeh", ar = "التسبيح", ml = "തസ്ബീഹ്"),
        transliteration = Transliteration(en = "Subhanallah", ml = "സുബ്ഹാനല്ലാഹ്"),
        translation = LocalizedText(en = "Glory be to Allah.", ar = "تنزيه الله."),
    )

    @Test
    fun `each language shows its own text`() {
        assertEquals(DhikrText("Tasbeeh", "Subhanallah", "Glory be to Allah."), dhikr.textIn(ContentLanguage.EN))
        assertEquals("تنزيه الله.", dhikr.textIn(ContentLanguage.AR).translation)
        assertEquals("സുബ്ഹാനല്ലാഹ്", dhikr.textIn(ContentLanguage.ML).transliteration)
        assertEquals("തസ്ബീഹ്", dhikr.textIn(ContentLanguage.ML).title)
    }

    @Test
    fun `a missing language falls back to English`() {
        assertEquals("Glory be to Allah.", dhikr.textIn(ContentLanguage.ML).translation)
        val noMalayalam = dhikr.copy(transliteration = Transliteration(en = "Subhanallah"))
        assertEquals("Subhanallah", noMalayalam.textIn(ContentLanguage.ML).transliteration)
    }

    @Test
    fun `Arabic shows no transliteration`() {
        assertEquals(DhikrText("التسبيح", null, "تنزيه الله."), dhikr.textIn(ContentLanguage.AR))
    }

    @Test
    fun `the shared catalog falls back where ml is missing`() {
        val ikhlas = assertNotNull(contractCatalog.dhikr("surah-ikhlas"))
        val text = ikhlas.textIn(ContentLanguage.ML)
        assertEquals("സൂറത് അൽ ഇഖ്ലാസ്", text.title)
        assertEquals(ikhlas.translation.en, text.translation)
        assertEquals(ikhlas.transliteration.en, text.transliteration)
    }

    @Test
    fun `the app language is the first configured one the app ships`() {
        assertEquals(ContentLanguage.AR, ContentLanguage.of(listOf("ar")))
        assertEquals(ContentLanguage.ML, ContentLanguage.of(listOf("fr", "ml", "en")))
        assertEquals(ContentLanguage.EN, ContentLanguage.of(listOf("fr")))
        assertEquals(ContentLanguage.EN, ContentLanguage.of(emptyList()))
    }
}
