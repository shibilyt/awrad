package app.awrad.core.domain.personal

import java.text.BreakIterator
import java.text.Normalizer
import java.util.Locale

/** Why a tag name was refused, checked in this order. */
public enum class TagNameProblem(public val wire: String) {
    /** Nothing but White_Space. */
    EMPTY("empty"),

    /** More than 40 extended grapheme clusters. */
    TOO_MANY_GRAPHEMES("too_many_graphemes"),

    /** More than 128 UTF-8 bytes. */
    TOO_MANY_BYTES("too_many_bytes"),
}

/** What the user typed as a tag name, normalized ([TagName.of]). */
public sealed interface TagNameResult {
    public data class Accepted(val name: TagName) : TagNameResult

    public data class Rejected(val problem: TagNameProblem) : TagNameResult
}

/**
 * A tag's names (fixture `tag_name_normalization`): [display] is trimmed of White_Space, with each inner run
 * collapsed to one space, then NFC; [normalized] is the display name's full Unicode case folding, then NFC. Two
 * tags are the same when their [normalized] names are equal. Diacritics, Arabic marks, tatweel and joiners are
 * never stripped.
 */
@ConsistentCopyVisibility
public data class TagName private constructor(val display: String, val normalized: String) {

    public companion object {
        public const val MAX_GRAPHEMES: Int = 40
        public const val MAX_BYTES: Int = 128

        /** The names for [input], or why it can't be a tag name: empty, then too many graphemes, then bytes. */
        public fun of(input: String): TagNameResult {
            val display = Normalizer.normalize(collapseWhiteSpace(input), Normalizer.Form.NFC)
            val problem = when {
                display.isEmpty() -> TagNameProblem.EMPTY
                graphemeCount(display) > MAX_GRAPHEMES -> TagNameProblem.TOO_MANY_GRAPHEMES
                display.toByteArray(Charsets.UTF_8).size > MAX_BYTES -> TagNameProblem.TOO_MANY_BYTES
                else -> null
            }
            return if (problem != null) {
                TagNameResult.Rejected(problem)
            } else {
                TagNameResult.Accepted(
                    TagName(display, Normalizer.normalize(CaseFolding.fold(display), Normalizer.Form.NFC)),
                )
            }
        }

        private fun collapseWhiteSpace(input: String): String = buildString {
            var pendingSpace = false
            var index = 0
            while (index < input.length) {
                val codePoint = input.codePointAt(index)
                index += Character.charCount(codePoint)
                if (isWhiteSpace(codePoint)) {
                    pendingSpace = isNotEmpty()
                } else {
                    if (pendingSpace) append(' ')
                    pendingSpace = false
                    appendCodePoint(codePoint)
                }
            }
        }

        /** Unicode's White_Space property (PropList.txt), which Java's own checks don't match exactly. */
        private val WHITE_SPACE: List<IntRange> = listOf(
            0x0009..0x000D, 0x0020..0x0020, 0x0085..0x0085, 0x00A0..0x00A0, 0x1680..0x1680, 0x2000..0x200A,
            0x2028..0x2029, 0x202F..0x202F, 0x205F..0x205F, 0x3000..0x3000,
        )

        private fun isWhiteSpace(codePoint: Int): Boolean = WHITE_SPACE.any { codePoint in it }

        private fun graphemeCount(text: String): Int {
            val iterator = BreakIterator.getCharacterInstance(Locale.ROOT)
            iterator.setText(text)
            var count = 0
            while (iterator.next() != BreakIterator.DONE) count++
            return count
        }
    }
}

/**
 * Unicode Default Case Folding, full (CaseFolding.txt statuses C and F, not T), without a locale. The JVM has no
 * case-folding API, so each code point is upper-cased then lower-cased until it's stable, which gives the full
 * folding for every letter except where CaseFolding.txt deliberately differs:
 * - Cherokee folds to its capital letters (for stability, since Cherokee's lower case came later), so its
 *   capitals stay as they are;
 * - dotless ı has no folding.
 * Code points are folded one at a time, so lower-casing never applies the final-sigma context.
 */
internal object CaseFolding {

    private const val DOTLESS_I = 0x0131
    private val CHEROKEE_CAPITAL = 0x13A0..0x13F5
    private val CHEROKEE_SMALL = 0xAB70..0xABBF
    private const val CHEROKEE_SMALL_TO_CAPITAL = 0x13A0 - 0xAB70
    private val CHEROKEE_SMALL_EXTRA = 0x13F8..0x13FD
    private const val CHEROKEE_EXTRA_TO_CAPITAL = 0x13F0 - 0x13F8
    private const val MAX_ROUNDS = 3

    fun fold(text: String): String = buildString {
        var index = 0
        while (index < text.length) {
            val codePoint = text.codePointAt(index)
            index += Character.charCount(codePoint)
            append(foldCodePoint(codePoint))
        }
    }

    private fun foldCodePoint(codePoint: Int): String = when (codePoint) {
        DOTLESS_I, in CHEROKEE_CAPITAL -> String(Character.toChars(codePoint))
        in CHEROKEE_SMALL -> String(Character.toChars(codePoint + CHEROKEE_SMALL_TO_CAPITAL))
        in CHEROKEE_SMALL_EXTRA -> String(Character.toChars(codePoint + CHEROKEE_EXTRA_TO_CAPITAL))
        else -> {
            var folded = String(Character.toChars(codePoint))
            repeat(MAX_ROUNDS) { folded = folded.uppercase(Locale.ROOT).lowercase(Locale.ROOT) }
            folded
        }
    }
}
