package app.awrad.core.domain.dhikr

import java.text.Normalizer
import java.util.Locale

/**
 * How text is normalized before dhikr search compares it (fixture `dhikr_search_normalization`): harakat,
 * Qur'anic marks and tatweel go; alef forms, ta marbuta and alef maqsura are unified; Latin diacritics,
 * apostrophes and ZWNJ/ZWJ go; punctuation separates words; lower case; whitespace collapsed and trimmed.
 */
public object DhikrSearchText {

    /** Harakat and marks U+064B–U+065F, superscript alef, Qur'anic marks U+06D6–U+06ED and tatweel. */
    private val ARABIC_MARKS = '\u064B'..'\u065F'
    private const val SUPERSCRIPT_ALEF = '\u0670'
    private val QURANIC_MARKS = '\u06D6'..'\u06ED'
    private const val TATWEEL = '\u0640'

    /** Malayalam signs are letters here, not removable marks. */
    private val MALAYALAM = '\u0D00'..'\u0D7F'

    /** أ إ آ ٱ → ا, ة → ه, ى → ي. */
    private val UNIFIED = mapOf(
        '\u0623' to '\u0627',
        '\u0625' to '\u0627',
        '\u0622' to '\u0627',
        '\u0671' to '\u0627',
        '\u0629' to '\u0647',
        '\u0649' to '\u064A',
    )

    /** ZWNJ, ZWJ. */
    private val JOINERS = setOf('\u200C', '\u200D')

    /** ' ’ ʼ ʿ ʾ ` */
    private val APOSTROPHES = setOf('\'', '\u2019', '\u02BC', '\u02BF', '\u02BE', '`')

    /** - _ . , ، : ; ! ? ( ) " “ ” */
    private val SEPARATORS =
        setOf('-', '_', '.', ',', '\u060C', ':', ';', '!', '?', '(', ')', '"', '\u201C', '\u201D')
    private val MARK_TYPES = setOf(
        Character.NON_SPACING_MARK.toInt(),
        Character.COMBINING_SPACING_MARK.toInt(),
        Character.ENCLOSING_MARK.toInt(),
    )

    /** [text] normalized for comparison. */
    public fun normalize(text: String): String {
        val withoutMarks = buildString {
            Normalizer.normalize(text, Normalizer.Form.NFKD).forEach { char ->
                if (!isRemovableMark(char)) append(char)
            }
        }
        val words = buildString {
            Normalizer.normalize(withoutMarks, Normalizer.Form.NFC).forEach { char ->
                when {
                    char in JOINERS || char in APOSTROPHES -> Unit
                    char in SEPARATORS -> append(' ')
                    else -> append(UNIFIED[char] ?: char)
                }
            }
        }.lowercase(Locale.ROOT)
        return words.map { if (isSpace(it)) ' ' else it }
            .joinToString("")
            .split(' ')
            .filter { it.isNotEmpty() }
            .joinToString(" ")
    }

    /** [normalize]d, then without spaces: search compares these. */
    public fun compact(text: String): String = normalize(text).replace(" ", "")

    private fun isRemovableMark(char: Char): Boolean = when (char) {
        in ARABIC_MARKS, SUPERSCRIPT_ALEF, in QURANIC_MARKS, TATWEEL -> true
        in MALAYALAM -> false
        else -> Character.getType(char) in MARK_TYPES
    }

    private fun isSpace(char: Char): Boolean = char.isWhitespace() || Character.isSpaceChar(char)
}

/**
 * Searching [dhikrs] (fixture `dhikr_search`). Names are every title and every alias; the other fields are the
 * Arabic, every transliteration, and the translation in the app's language and in English. Query and fields are
 * compared [DhikrSearchText.compact]: a dhikr matches when the query is inside any of them. Dhikrs with a name
 * that starts with the query come first, then the rest, each in catalog order. A blank query lists every dhikr.
 */
public class DhikrSearch(private val dhikrs: List<Dhikr>) {

    private class Entry(val dhikr: Dhikr, val names: List<String>, val fields: List<String>)

    private val entries: Map<ContentLanguage, List<Entry>> by lazy {
        ContentLanguage.entries.associateWith { language ->
            dhikrs.map { dhikr ->
                val names = dhikr.title.all + dhikr.aliases.values.flatten()
                val fields = listOf(dhikr.arabic) + dhikr.transliteration.all +
                    listOfNotNull(dhikr.translation[language], dhikr.translation.en)
                Entry(dhikr, names.map(DhikrSearchText::compact), fields.map(DhikrSearchText::compact))
            }
        }
    }

    /** The dhikrs matching [query] for an app showing [language], best first. */
    public fun search(query: String, language: ContentLanguage): List<Dhikr> {
        val compact = DhikrSearchText.compact(query)
        if (compact.isEmpty()) return dhikrs
        val (startsWithName, others) = entries.getValue(language)
            .filter { entry -> (entry.names + entry.fields).any { compact in it } }
            .partition { entry -> entry.names.any { it.startsWith(compact) } }
        return (startsWithName + others).map { it.dhikr }
    }
}
