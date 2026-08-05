package app.awrad.awrad_dhikrgoalstracker.domain

import java.text.BreakIterator
import java.text.Normalizer

data class NormalizedUserTagName(
    val displayName: String,
    val normalizedName: String,
)

/**
 * Shared tag-name policy matching contracts/behavior-model/v1/fixtures/tag-normalization-contract.json:
 * trim/collapse Unicode White_Space, NFC display, Unicode Default Case Folding + NFC uniqueness,
 * locale-independent extended grapheme cluster length, 128 UTF-8 byte cap.
 */
object UserTagNormalizer {
    const val MAX_GRAPHEME_CLUSTERS = 40
    const val MAX_UTF8_BYTES = 128

    fun normalize(raw: String): NormalizedUserTagName? {
        val collapsed = collapseUnicodeWhitespace(raw)
        if (collapsed.isEmpty()) return null
        val display = Normalizer.normalize(collapsed, Normalizer.Form.NFC)
        if (display.isEmpty()) return null
        if (graphemeClusterCount(display) > MAX_GRAPHEME_CLUSTERS) return null
        if (display.toByteArray(Charsets.UTF_8).size > MAX_UTF8_BYTES) return null
        val folded = Normalizer.normalize(unicodeDefaultCaseFold(display), Normalizer.Form.NFC)
        return NormalizedUserTagName(displayName = display, normalizedName = folded)
    }

    internal fun collapseUnicodeWhitespace(value: String): String {
        val builder = StringBuilder(value.length)
        var pendingSpace = false
        var seenNonSpace = false
        var index = 0
        while (index < value.length) {
            val codePoint = value.codePointAt(index)
            if (isUnicodeWhiteSpace(codePoint)) {
                if (seenNonSpace) pendingSpace = true
            } else {
                if (pendingSpace) {
                    builder.append(' ')
                    pendingSpace = false
                }
                builder.appendCodePoint(codePoint)
                seenNonSpace = true
            }
            index += Character.charCount(codePoint)
        }
        return builder.toString()
    }

    internal fun unicodeDefaultCaseFold(value: String): String = buildString(value.length) {
        var index = 0
        while (index < value.length) {
            val codePoint = value.codePointAt(index)
            val expansion = UnicodeDefaultCaseFoldTable.expansions[codePoint]
            if (expansion != null) {
                expansion.forEach { appendCodePoint(it) }
            } else {
                appendCodePoint(Character.toLowerCase(codePoint))
            }
            index += Character.charCount(codePoint)
        }
    }

    private fun isUnicodeWhiteSpace(codePoint: Int): Boolean {
        // Unicode White_Space property: Zs/Zl/Zp plus the Cc whitespace set.
        val type = Character.getType(codePoint)
        if (type == Character.SPACE_SEPARATOR.toInt() ||
            type == Character.LINE_SEPARATOR.toInt() ||
            type == Character.PARAGRAPH_SEPARATOR.toInt()
        ) {
            return true
        }
        return codePoint == 0x0009 || codePoint == 0x000A || codePoint == 0x000B ||
            codePoint == 0x000C || codePoint == 0x000D || codePoint == 0x0085
    }

    private fun graphemeClusterCount(value: String): Int {
        val breaker = BreakIterator.getCharacterInstance(java.util.Locale.ROOT)
        breaker.setText(value)
        var count = 0
        var end = breaker.next()
        while (end != BreakIterator.DONE) {
            count++
            end = breaker.next()
        }
        return count
    }
}
