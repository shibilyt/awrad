import groovy.json.JsonSlurper
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals

class DhikrCatalogShapeTest {

    @Test
    fun `the shared catalog has nothing the app doesn't read`() {
        val contract = generateSequence(File("").absoluteFile) { it.parentFile }
            .map { it.resolve("contracts/dhikr-catalog/v1/catalog.json") }
            .first { it.isFile }

        assertEquals(emptyList(), DhikrCatalogShape.problems(JsonSlurper().parseText(contract.readText())))
    }

    @Test
    fun `a minimal catalog passes`() {
        assertEquals(emptyList(), problems(catalog()))
    }

    @Test
    fun `unknown keys fail, by path`() {
        assertEquals(listOf("catalog: unknown key 'featured'"), problems(catalog(root = """"featured": [],""")))
        assertEquals(
            listOf("dhikrs[tahleel]: unknown key 'occasion'"),
            problems(catalog(dhikr = """"occasion": "morning",""")),
        )
        assertEquals(
            listOf("dhikrs[tahleel].title: unknown key 'fr'"),
            problems(catalog(title = """{"en": "Tahleel", "fr": "Tahlil"}""")),
        )
        assertEquals(
            listOf("dhikrs[tahleel].audio: unknown key 'bitrate'"),
            problems(catalog(audio = """{"url": "https://dhikrs.awrad.app/a.mp3", "style": "melodic", "repetitions": 1, "bitrate": 64}""")),
        )
        assertEquals(
            listOf("dhikrs[tahleel].references[0]: unknown key 'page'"),
            problems(catalog(references = """[{"id": "q", "type": "quran", "surah": 1, "ayahStart": 1, "ayahEnd": 2, "page": 3}]""")),
        )
    }

    @Test
    fun `unknown kinds, styles and reference types fail`() {
        assertEquals(listOf("dhikrs[tahleel].kind: unknown kind 'hymn'"), problems(catalog(kind = "hymn")))
        assertEquals(
            listOf("dhikrs[tahleel].audio.style: unknown style 'remix'"),
            problems(catalog(audio = """{"url": "https://dhikrs.awrad.app/a.mp3", "style": "remix", "repetitions": 1}""")),
        )
        assertEquals(
            listOf("dhikrs[tahleel].references[0].type: unknown reference type 'podcast'"),
            problems(catalog(references = """[{"id": "p", "type": "podcast"}]""")),
        )
    }

    private fun problems(json: String) = DhikrCatalogShape.problems(JsonSlurper().parseText(json))

    private fun catalog(
        root: String = "",
        dhikr: String = "",
        kind: String = "dhikr",
        title: String = """{"en": "Tahleel", "ar": "التهليل", "ml": "തഹ്ലീൽ"}""",
        audio: String = "null",
        references: String = "[]",
    ) = """
        {
          $root
          "version": 1,
          "contentRevision": 1,
          "dhikrs": [{
            $dhikr
            "id": "0f3f7d1e-2a4b-4c5d-8e6f-7a8b9c0d1e2f",
            "key": "tahleel",
            "kind": "$kind",
            "arabic": "لَا إِلَٰهَ إِلَّا ٱللَّٰهُ",
            "title": $title,
            "transliteration": {"en": "La ilaha illallah"},
            "aliases": {"en": ["Tahlil"]},
            "tags": ["debt"],
            "translation": {"en": "There is no god but Allah."},
            "audio": $audio,
            "references": $references,
            "virtues": []
          }],
          "collections": [{"key": "dhikrs", "title": {"en": "Dhikrs", "ar": "أذكار", "ml": "ദിക്റുകൾ"}, "dhikrs": ["tahleel"]}],
          "tags": [{"key": "debt", "title": {"en": "Debt", "ar": "الدين", "ml": "കടം"}}]
        }
    """.trimIndent()
}
