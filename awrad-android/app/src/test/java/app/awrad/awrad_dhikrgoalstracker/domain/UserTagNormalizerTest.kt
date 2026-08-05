package app.awrad.awrad_dhikrgoalstracker.domain

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UserTagNormalizerTest {

    @Test
    fun sharedFixtureTrimCollapseCasefold() {
        val result = UserTagNormalizer.normalize("  Before   Sleep  ")
        assertNotNull(result)
        assertEquals("Before Sleep", result!!.displayName)
        assertEquals("before sleep", result.normalizedName)
    }

    @Test
    fun sharedFixtureNfcAndCasefoldPreservesDiacritics() {
        val result = UserTagNormalizer.normalize("Beforé Sleep")
        assertNotNull(result)
        assertEquals("Beforé Sleep", result!!.displayName)
        assertEquals("beforé sleep", result.normalizedName)
    }

    @Test
    fun arabicMarksAreNotStrippedForUniqueness() {
        val withMarks = UserTagNormalizer.normalize("سَلام")
        val withoutMarks = UserTagNormalizer.normalize("سلام")
        assertNotNull(withMarks)
        assertNotNull(withoutMarks)
        assertFalse(withMarks!!.normalizedName == withoutMarks!!.normalizedName)
    }

    @Test
    fun rejectsEmptyWhitespaceAndOversizedNames() {
        assertNull(UserTagNormalizer.normalize("   "))
        assertNull(UserTagNormalizer.normalize("a".repeat(41)))
        assertNotNull(UserTagNormalizer.normalize("Sleep"))
    }

    @Test
    fun rejectsNamesOver128Utf8Bytes() {
        // 40 graphemes of a 4-byte emoji exceeds 128 UTF-8 bytes.
        val emoji = "😀".repeat(40)
        assertTrue(emoji.codePointCount(0, emoji.length) <= 40)
        assertTrue(emoji.toByteArray(Charsets.UTF_8).size > 128)
        assertNull(UserTagNormalizer.normalize(emoji))
    }

    @Test
    fun sharedBehaviorFixtureTagNormalizationCases() {
        val document = Json.parseToJsonElement(fixture().readText()).jsonObject
        val cases = document.getValue("tag_normalization").jsonArray.map { it.jsonObject }

        cases.forEach { case ->
            when (case.getValue("id").jsonPrimitive.content) {
                "trim_collapse_casefold", "nfc_and_casefold" -> {
                    val input = case.getValue("input").jsonPrimitive.content
                    val result = UserTagNormalizer.normalize(input)
                    assertNotNull(case.toString(), result)
                    assertEquals(
                        case.getValue("expected_display").jsonPrimitive.content,
                        result!!.displayName,
                    )
                    assertEquals(
                        case.getValue("expected_normalized").jsonPrimitive.content,
                        result.normalizedName,
                    )
                }
                "arabic_marks_preserved" -> {
                    val a = UserTagNormalizer.normalize(case.getValue("input_a").jsonPrimitive.content)
                    val b = UserTagNormalizer.normalize(case.getValue("input_b").jsonPrimitive.content)
                    assertNotNull(a)
                    assertNotNull(b)
                    assertEquals(
                        case.getValue("expected_same_normalized").jsonPrimitive.boolean,
                        a!!.normalizedName == b!!.normalizedName,
                    )
                }
                "reject_empty_and_oversized" -> {
                    case.getValue("cases").jsonArray.forEach { element ->
                        val row = element.jsonObject
                        val input = row.getValue("input").jsonPrimitive.content
                        val accepted = row.getValue("accepted").jsonPrimitive.boolean
                        val result = UserTagNormalizer.normalize(input)
                        if (accepted) {
                            assertNotNull(input, result)
                        } else {
                            assertNull(row.get("reason")?.jsonPrimitive?.contentOrNull ?: input, result)
                        }
                    }
                }
            }
        }
    }

    private fun fixture(): File {
        val candidates = listOf(
            File("../contracts/behavior-model/v1/fixtures/behavior-cases.json"),
            File("../../contracts/behavior-model/v1/fixtures/behavior-cases.json"),
            File("contracts/behavior-model/v1/fixtures/behavior-cases.json"),
        )
        return candidates.first { it.exists() }
    }
}
