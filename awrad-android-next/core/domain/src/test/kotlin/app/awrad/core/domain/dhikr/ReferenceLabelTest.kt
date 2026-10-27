package app.awrad.core.domain.dhikr

import kotlin.test.Test
import kotlin.test.assertEquals

class ReferenceLabelTest {

    private fun isolated(text: String) = "⁦$text⁩"

    @Test
    fun `a Qur'an range reads surah, then the first and last ayah`() {
        assertEquals(
            ReferenceLabel("Qur'an ${isolated("112:1–4")}"),
            Reference.Quran("q", surah = 112, ayahStart = 1, ayahEnd = 4).label("Qur'an"),
        )
    }

    @Test
    fun `one ayah has no range, and the word is the app language's`() {
        assertEquals(
            ReferenceLabel("القرآن ${isolated("71:10")}"),
            Reference.Quran("q", surah = 71, ayahStart = 10, ayahEnd = 10).label("القرآن"),
        )
    }

    @Test
    fun `a hadith is its collection and number, then its grade`() {
        assertEquals(
            ReferenceLabel("Sahih Muslim 408"),
            Reference.Hadith("h", collection = "Sahih Muslim", number = "408").label("Qur'an"),
        )
        assertEquals(
            ReferenceLabel("Sunan Abi Dawud 1518 · Da'if (al-Albani)"),
            Reference.Hadith("h", "Sunan Abi Dawud", number = "1518", grade = "Da'if (al-Albani)").label("Qur'an"),
        )
        assertEquals(ReferenceLabel("Musnad Ahmad"), Reference.Hadith("h", "Musnad Ahmad").label("Qur'an"))
    }

    @Test
    fun `a book is its title, author and volume and page`() {
        assertEquals(
            ReferenceLabel("Al-Adhkar, An-Nawawi, ${isolated("2:45")}"),
            Reference.Book("b", "Al-Adhkar", author = "An-Nawawi", volume = "2", page = "45").label("Qur'an"),
        )
        assertEquals(
            ReferenceLabel("Al-Adhkar, ${isolated("45")}"),
            Reference.Book("b", "Al-Adhkar", page = "45").label("Qur'an"),
        )
        assertEquals(ReferenceLabel("Al-Adhkar"), Reference.Book("b", "Al-Adhkar").label("Qur'an"))
    }

    @Test
    fun `a shaykh is the name, and other is the text with its link`() {
        assertEquals(ReferenceLabel("Shaykh Ahmad"), Reference.Shaykh("s", "Shaykh Ahmad", note = "Ijaza").label("Q"))
        assertEquals(
            ReferenceLabel("Family practice", "https://example.org/source"),
            Reference.Other("o", "Family practice", url = "https://example.org/source").label("Q"),
        )
    }
}
