package app.awrad.awrad_dhikrgoalstracker.domain

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class UserTagNormalizerContractTest {

    @Test
    fun sharedTagNormalizationContract_eszettSsDottedIAndUnicodeWhitespace() {
        val document = Json.parseToJsonElement(contractFixture().readText()).jsonObject
        assertEquals(1, document.getValue("version").jsonPrimitive.content.toInt())
        val algorithm = document.getValue("algorithm").jsonObject
        assertEquals(
            "trim_collapse_unicode_whitespace_then_nfc",
            algorithm.getValue("display").jsonPrimitive.content,
        )
        assertEquals(
            "unicode_default_casefold_then_nfc",
            algorithm.getValue("normalized").jsonPrimitive.content,
        )
        assertEquals(
            "unicode_white_space_property",
            algorithm.getValue("whitespace").jsonPrimitive.content,
        )

        val byId = document.getValue("cases").jsonArray
            .map { it.jsonObject }
            .associateBy { it.getValue("id").jsonPrimitive.content }

        val eszett = byId.getValue("eszett_ss_full_casefold")
        val a = UserTagNormalizer.normalize(eszett.getValue("input_a").jsonPrimitive.content)
        val b = UserTagNormalizer.normalize(eszett.getValue("input_b").jsonPrimitive.content)
        assertNotNull(a)
        assertNotNull(b)
        assertEquals(eszett.getValue("expected_display_a").jsonPrimitive.content, a!!.displayName)
        assertEquals(eszett.getValue("expected_display_b").jsonPrimitive.content, b!!.displayName)
        assertEquals(eszett.getValue("expected_normalized").jsonPrimitive.content, a.normalizedName)
        assertEquals(eszett.getValue("expected_normalized").jsonPrimitive.content, b.normalizedName)

        val dotted = byId.getValue("dotted_capital_i_full_casefold")
        val istanbul = UserTagNormalizer.normalize(dotted.getValue("input").jsonPrimitive.content)
        assertNotNull(istanbul)
        assertEquals(dotted.getValue("expected_display").jsonPrimitive.content, istanbul!!.displayName)
        assertEquals(
            dotted.getValue("expected_normalized").jsonPrimitive.content,
            istanbul.normalizedName,
        )

        val spaces = byId.getValue("nnbsp_and_figure_space_collapse")
        val spaced = UserTagNormalizer.normalize(spaces.getValue("input").jsonPrimitive.content)
        assertNotNull(spaced)
        assertEquals(spaces.getValue("expected_display").jsonPrimitive.content, spaced!!.displayName)
        assertEquals(
            spaces.getValue("expected_normalized").jsonPrimitive.content,
            spaced.normalizedName,
        )
    }

    @Test
    fun tabAndNewlineAreUnicodeWhitespaceAndCollapse() {
        val result = UserTagNormalizer.normalize("Before\t\nSleep")
        assertNotNull(result)
        assertEquals("Before Sleep", result!!.displayName)
        assertEquals("before sleep", result.normalizedName)
    }

    @Test
    fun localeMustNotAffectTurkishIFolding() {
        val previous = java.util.Locale.getDefault()
        try {
            java.util.Locale.setDefault(java.util.Locale("tr", "TR"))
            val result = UserTagNormalizer.normalize("TITLE")
            assertNotNull(result)
            assertEquals("title", result!!.normalizedName)
        } finally {
            java.util.Locale.setDefault(previous)
        }
    }

    @Test
    fun rejectsNullAfterWhitespaceOnlyNnBsp() {
        assertNull(UserTagNormalizer.normalize("\u202F\u2007"))
    }

    private fun contractFixture(): File {
        val candidates = listOf(
            File("../contracts/behavior-model/v1/fixtures/tag-normalization-contract.json"),
            File("../../contracts/behavior-model/v1/fixtures/tag-normalization-contract.json"),
            File("contracts/behavior-model/v1/fixtures/tag-normalization-contract.json"),
        )
        return candidates.first { it.exists() }
    }
}
