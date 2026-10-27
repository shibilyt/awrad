package app.awrad.core.domain.dhikr

import app.awrad.core.testing.contractCatalog
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class DhikrCatalogTest {

    private val catalog = contractCatalog

    @Test
    fun `the shared catalog parses with every dhikr and collection`() {
        assertEquals(113, catalog.dhikrs.size)
        assertEquals(5, catalog.collections.size)
        assertEquals(
            listOf("daily-essentials", "dhikrs", "swalaths", "ramadan", "asma-ul-husna"),
            catalog.collections.map { it.key },
        )
        assertEquals(100, catalog.dhikrs.count { it.kind == DhikrKind.NAME_OF_ALLAH })
        assertTrue(catalog.contentRevision >= 1)
    }

    @Test
    fun `every collection key resolves, in order, and every dhikr is in one`() {
        catalog.collections.forEach { collection ->
            assertTrue(collection.dhikrs.isNotEmpty(), collection.key)
            collection.dhikrs.forEach { assertEquals(it, catalog.dhikr(it.key)) }
        }
        val asma = assertNotNull(catalog.collection("asma-ul-husna"))
        assertEquals(100, asma.dhikrs.size)
        assertEquals("asma-ul-husna-allah", asma.dhikrs.first().key)
        val listed = catalog.collections.flatMap { it.dhikrs }.toSet()
        assertEquals(catalog.dhikrs.toSet(), listed)
    }

    @Test
    fun `fields map to the domain types`() {
        val ikhlas = assertNotNull(catalog.dhikr("surah-ikhlas"))
        assertEquals(DhikrKind.QURAN, ikhlas.kind)
        assertEquals("c88b9491-40ad-4b42-a5b8-e07c4b4d31ef", ikhlas.id.value)
        assertEquals(5, ikhlas.arabicLines.size)
        assertEquals(listOf(Reference.Quran("quran-112-1-4", 112, 1, 4)), ikhlas.references)
        assertEquals("https://dhikrs.awrad.app/ikhlas.mp3", ikhlas.audio?.url)
        assertEquals(AudioStyle.RECITATION, ikhlas.audio?.style)

        val isthighfar = assertNotNull(catalog.dhikr("isthighfar"))
        assertEquals(listOf("أستغفر الله"), isthighfar.aliases[ContentLanguage.AR])
        val hadith = isthighfar.references.first() as Reference.Hadith
        assertEquals("Da'if (al-Albani)", hadith.grade)
        assertEquals(listOf(hadith), isthighfar.virtues.first().references)

        val debt = assertNotNull(catalog.dhikr("swalath-for-debt"))
        assertEquals(listOf("debt"), debt.tags.map { it.key })
        assertEquals("കടം", debt.tags.single().title.ml)

        assertNull(catalog.dhikr("asma-ul-husna-as-sabur")?.audio)
        assertNull(catalog.dhikr("no-such-dhikr"))
    }

    @Test
    fun `an unknown key fails instead of being dropped`() {
        assertFailsWith<IllegalArgumentException> {
            DhikrCatalog.parse(minimal(dhikrExtra = """"occasion": "morning","""))
        }
        assertFailsWith<IllegalArgumentException> { DhikrCatalog.parse(minimal(rootExtra = """"featured": [],""")) }
    }

    @Test
    fun `an unknown kind or reference type fails`() {
        assertFailsWith<IllegalArgumentException> { DhikrCatalog.parse(minimal(kind = "hymn")) }
        assertFailsWith<IllegalArgumentException> {
            DhikrCatalog.parse(minimal(references = """[{"id": "x", "type": "podcast", "text": "?"}]"""))
        }
    }

    @Test
    fun `broken links fail`() {
        assertFailsWith<IllegalArgumentException> { DhikrCatalog.parse(minimal(collectionKeys = """["missing"]""")) }
        assertFailsWith<IllegalArgumentException> {
            DhikrCatalog.parse(minimal(virtues = """[{"text": {"en": "A virtue"}, "references": ["missing"]}]"""))
        }
    }

    @Test
    fun `a minimal catalog parses`() {
        val parsed = DhikrCatalog.parse(minimal())
        assertEquals(listOf("tahleel"), parsed.dhikrs.map { it.key })
        assertEquals(LocalizedText("Tahleel", "التهليل", "തഹ്ലീൽ"), parsed.dhikrs.single().title)
    }

    private fun minimal(
        rootExtra: String = "",
        dhikrExtra: String = "",
        kind: String = "dhikr",
        references: String = "[]",
        virtues: String = "[]",
        collectionKeys: String = """["tahleel"]""",
    ): String = """
        {
          $rootExtra
          "version": 1,
          "contentRevision": 1,
          "dhikrs": [{
            $dhikrExtra
            "id": "0f3f7d1e-2a4b-4c5d-8e6f-7a8b9c0d1e2f",
            "key": "tahleel",
            "kind": "$kind",
            "arabic": "لَا إِلَٰهَ إِلَّا ٱللَّٰهُ",
            "title": {"en": "Tahleel", "ar": "التهليل", "ml": "തഹ്ലീൽ"},
            "transliteration": {"en": "La ilaha illallah"},
            "translation": {"en": "There is no god but Allah."},
            "audio": null,
            "references": $references,
            "virtues": $virtues
          }],
          "collections": [{
            "key": "dhikrs",
            "title": {"en": "Dhikrs", "ar": "أذكار", "ml": "ദിക്റുകൾ"},
            "dhikrs": $collectionKeys
          }],
          "tags": []
        }
    """.trimIndent()
}
