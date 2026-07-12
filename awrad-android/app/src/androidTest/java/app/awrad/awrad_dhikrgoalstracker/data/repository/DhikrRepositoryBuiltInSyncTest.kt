package app.awrad.awrad_dhikrgoalstracker.data.repository

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.service.AudioDownloadManager
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.flow.first
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DhikrRepositoryBuiltInSyncTest {

    private lateinit var database: AwradDatabase

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AwradDatabase::class.java,
        ).allowMainThreadQueries().build()
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun existingIkhlasReceivesCanonicalQuranMetadataWhileNonQuranRemainsNull() = runBlocking {
        val dao = database.dhikrDao()
        dao.insertAll(
            listOf(
                DhikrEntity(
                    title = "Old Ikhlas",
                    arabic = "old text",
                    transliteration = "Qul huwa Allahu ahad",
                    translation = "Surah Ikhlas",
                    audioUrl = null,
                    audioFileName = null,
                    category = DhikrCategory.QURAN,
                ),
                DhikrEntity(
                    title = "Tahleel",
                    arabic = "لَا إِلٰهَ إِلَّا ٱللَّٰهُ",
                    transliteration = "La ilaha illallah",
                    translation = "Tahleel",
                    audioUrl = null,
                    audioFileName = null,
                    category = DhikrCategory.PRAISE,
                ),
            ),
        )

        val repository = DhikrRepositoryImpl(
            dhikrDao = dao,
            audioDownloadManager = AudioDownloadManager(ApplicationProvider.getApplicationContext()),
        )
        repository.initializeBuiltInDhikrs()

        val synced = dao.getAllDhikrs().first()
        val ikhlas = synced.first { it.transliteration == "Qul huwa Allahu ahad" }
        val tahleel = synced.first { it.transliteration == "La ilaha illallah" }
        assertEquals(112, ikhlas.quranSurah)
        assertEquals(1, ikhlas.quranAyahStart)
        assertEquals(4, ikhlas.quranAyahEnd)
        assertEquals(4, Regex("\\([1-4]\\)").findAll(ikhlas.arabic).count())
        assertNull(tahleel.quranSurah)
    }
}
