package app.awrad.awrad_dhikrgoalstracker.data.model.wird

/**
 * User-facing wird text is stored as a language → value map, e.g. `{ "en": "...", "ar": "..." }`.
 * Supported languages: English (`en`), Arabic (`ar`), Malayalam (`ml`). `ml` is preserved in the
 * data model for iOS asset interop even though the app shell currently only renders `en`/`ar`.
 */
typealias LocalizedString = Map<String, String>

const val LANG_EN = "en"
const val LANG_AR = "ar"

/**
 * Resolution rule (must match iOS exactly):
 * 1. Return the value for [lang] if present and non-blank.
 * 2. Else fall back to English (`en`) if present and non-blank.
 * 3. Else return the first non-blank value in the map (or empty string).
 */
fun LocalizedString.resolve(lang: String): String = resolveOptional(lang) ?: ""

/** Like [resolve] but returns null instead of an empty string when nothing resolves. */
fun LocalizedString.resolveOptional(lang: String): String? {
    this[lang]?.takeIf { it.isNotBlank() }?.let { return it }
    this[LANG_EN]?.takeIf { it.isNotBlank() }?.let { return it }
    return values.firstOrNull { it.isNotBlank() }
}

/**
 * Self-heals legacy data: a removed wird-creation path once stored names URL-encoded
 * (e.g. `"...%D8%B3"`). Decode each value's `%XX` sequences as UTF-8 on read so display is correct
 * regardless of how the value was persisted. Only touches values that look percent-encoded, leaves
 * `+` and other characters untouched, and reverts if decoding yields invalid UTF-8.
 */
fun LocalizedString.decodedFromLegacyEncoding(): LocalizedString =
    if (none { PERCENT_ESCAPE.containsMatchIn(it.value) }) this
    else mapValues { it.value.decodePercentEscapes() }

private val PERCENT_ESCAPE = Regex("%[0-9A-Fa-f]{2}")

private fun String.decodePercentEscapes(): String {
    if (!PERCENT_ESCAPE.containsMatchIn(this)) return this
    return runCatching {
        val bytes = java.io.ByteArrayOutputStream(length)
        var i = 0
        while (i < length) {
            val c = this[i]
            if (c == '%' && i + 2 < length &&
                this[i + 1].isHexDigit() && this[i + 2].isHexDigit()
            ) {
                bytes.write((this[i + 1].hexValue() shl 4) or this[i + 2].hexValue())
                i += 3
            } else {
                bytes.write(c.toString().toByteArray(Charsets.UTF_8))
                i++
            }
        }
        val decoded = bytes.toByteArray().toString(Charsets.UTF_8)
        if (decoded != this && '�' !in decoded) decoded else this
    }.getOrDefault(this)
}

private fun Char.isHexDigit() = this in '0'..'9' || this in 'a'..'f' || this in 'A'..'F'

private fun Char.hexValue() = when (this) {
    in '0'..'9' -> this - '0'
    in 'a'..'f' -> this - 'a' + 10
    else -> this - 'A' + 10
}
