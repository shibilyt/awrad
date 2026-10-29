package app.awrad.core.domain.places

import java.text.Normalizer
import java.util.Locale

/**
 * Search over the bundled cities (fixture `city_search`; contracts/places/v1/README.md, "Search"). Every name's
 * search key is computed once, so each query only compares strings.
 */
public class CitySearch(cities: List<City>) {

    /** Each city with its keys: the name's first, then its aliases'. */
    private val indexed: List<Pair<City, List<String>>> =
        cities.map { city -> city to (listOf(city.name) + city.aliases).map(::key) }

    /**
     * The cities [query] finds, best first, at most [limit]. A name matches exactly, by its start, or by the start
     * of a later word, in that order of strength; an alias matches the same way but ranks just below the name.
     * Then larger cities first, then smaller IDs. A query whose key is empty finds nothing.
     */
    public fun search(query: String, limit: Int = DEFAULT_LIMIT): List<City> {
        val q = key(query)
        if (q.isEmpty()) return emptyList()
        val wordStart = " $q"
        return indexed.mapNotNull { (city, keys) ->
            val tier = keys.withIndex().mapNotNull { (index, name) ->
                val strength = when {
                    name == q -> 0
                    name.startsWith(q) -> 1
                    name.contains(wordStart) -> 2
                    else -> null
                }
                strength?.let { it * 2 + if (index == 0) 0 else 1 }
            }.minOrNull()
            tier?.let { city to it }
        }
            .sortedWith(
                compareBy<Pair<City, Int>> { it.second }
                    .thenByDescending { it.first.population }
                    .thenBy { it.first.id },
            )
            .take(limit)
            .map { it.first }
    }

    public companion object {
        public const val DEFAULT_LIMIT: Int = 20

        private val ACCENTS = Regex("[\\u0300-\\u036f\\u064b-\\u065f\\u0670\\u0640]")
        private val ALEF = Regex("[آأإٱ]")
        private val APOSTROPHES = Regex("['’ʼ`]")
        private val SEPARATORS = Regex("[^\\p{L}\\p{M}\\p{N}]+")

        /**
         * The search key of [text]: NFKD; Latin accents, Arabic harakat and tatweel removed; alef forms to ا, alef
         * maksura to ي, ta marbuta to ه; apostrophes removed; lowercased; every run of characters that aren't
         * letters, marks or digits to one space; trimmed. Other scripts' marks (Malayalam vowel signs) stay.
         */
        public fun key(text: String): String {
            val folded = Normalizer.normalize(text, Normalizer.Form.NFKD)
                .replace(ACCENTS, "")
                .replace(ALEF, "ا")
                .replace('ى', 'ي')
                .replace('ة', 'ه')
                .replace(APOSTROPHES, "")
                .lowercase(Locale.ROOT)
            return folded.replace(SEPARATORS, " ").trim()
        }
    }
}
