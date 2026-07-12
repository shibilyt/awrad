package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GoalRepositoryDhikrMappingTest {

    @Test
    fun `goal dhikr mapping keeps valid Quran metadata`() {
        val dhikr = ikhlasEntity(quranSurah = 112, quranAyahStart = 1, quranAyahEnd = 4)
            .toGoalDhikr()

        assertEquals(112, dhikr.quranRef?.surah)
        assertEquals(1, dhikr.quranRef?.ayahStart)
        assertEquals(4, dhikr.quranRef?.ayahEnd)
    }

    @Test
    fun `goal dhikr mapping rejects incomplete Quran metadata`() {
        val dhikr = ikhlasEntity(quranSurah = 112, quranAyahStart = null, quranAyahEnd = 4)
            .toGoalDhikr()

        assertNull(dhikr.quranRef)
    }

    private fun ikhlasEntity(
        quranSurah: Int?,
        quranAyahStart: Int?,
        quranAyahEnd: Int?,
    ) = DhikrEntity(
        title = "Surah Ikhlas",
        arabic = "Quran text",
        transliteration = "Qul huwa Allahu ahad",
        translation = "Surah Ikhlas",
        audioUrl = null,
        audioFileName = null,
        category = DhikrCategory.QURAN,
        quranSurah = quranSurah,
        quranAyahStart = quranAyahStart,
        quranAyahEnd = quranAyahEnd,
    )
}
