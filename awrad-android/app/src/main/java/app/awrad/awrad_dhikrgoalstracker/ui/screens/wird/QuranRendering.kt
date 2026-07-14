package app.awrad.awrad_dhikrgoalstracker.ui.components.quran

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.awrad_dhikrgoalstracker.data.model.QuranRef
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily

/**
 * Mushaf-style rendering for QURAN segments: an ornamental surah header, an optional bismillah
 * line, and ayah text with end-of-ayah medallions.
 *
 * Authoring conventions for QURAN segments in wird assets:
 *  - Ayah boundaries are marked inline with `(n)` (Latin or Arabic-Indic digits) or with a bare
 *    `۝` / `۝n`. All forms normalize to U+06DD ARABIC END OF AYAH followed by Arabic-Indic
 *    digits, which Noto Naskh renders as the traditional numbered medallion.
 *  - A bismillah on its own first line (before the first `\n`) renders as a centered opening
 *    line. It is never synthesized: whether it appears is a property of the source text.
 */

internal data class SurahName(val arabic: String, val transliteration: String)

/** Names of the 114 surahs; index = surah number - 1. */
internal val QURAN_SURAH_NAMES: List<SurahName> = listOf(
    SurahName("الفاتحة", "Al-Fātiḥah"),
    SurahName("البقرة", "Al-Baqarah"),
    SurahName("آل عمران", "Āl ʿImrān"),
    SurahName("النساء", "An-Nisāʾ"),
    SurahName("المائدة", "Al-Māʾidah"),
    SurahName("الأنعام", "Al-Anʿām"),
    SurahName("الأعراف", "Al-Aʿrāf"),
    SurahName("الأنفال", "Al-Anfāl"),
    SurahName("التوبة", "At-Tawbah"),
    SurahName("يونس", "Yūnus"),
    SurahName("هود", "Hūd"),
    SurahName("يوسف", "Yūsuf"),
    SurahName("الرعد", "Ar-Raʿd"),
    SurahName("إبراهيم", "Ibrāhīm"),
    SurahName("الحجر", "Al-Ḥijr"),
    SurahName("النحل", "An-Naḥl"),
    SurahName("الإسراء", "Al-Isrāʾ"),
    SurahName("الكهف", "Al-Kahf"),
    SurahName("مريم", "Maryam"),
    SurahName("طه", "Ṭā Hā"),
    SurahName("الأنبياء", "Al-Anbiyāʾ"),
    SurahName("الحج", "Al-Ḥajj"),
    SurahName("المؤمنون", "Al-Muʾminūn"),
    SurahName("النور", "An-Nūr"),
    SurahName("الفرقان", "Al-Furqān"),
    SurahName("الشعراء", "Ash-Shuʿarāʾ"),
    SurahName("النمل", "An-Naml"),
    SurahName("القصص", "Al-Qaṣaṣ"),
    SurahName("العنكبوت", "Al-ʿAnkabūt"),
    SurahName("الروم", "Ar-Rūm"),
    SurahName("لقمان", "Luqmān"),
    SurahName("السجدة", "As-Sajdah"),
    SurahName("الأحزاب", "Al-Aḥzāb"),
    SurahName("سبأ", "Sabaʾ"),
    SurahName("فاطر", "Fāṭir"),
    SurahName("يس", "Yā Sīn"),
    SurahName("الصافات", "Aṣ-Ṣāffāt"),
    SurahName("ص", "Ṣād"),
    SurahName("الزمر", "Az-Zumar"),
    SurahName("غافر", "Ghāfir"),
    SurahName("فصلت", "Fuṣṣilat"),
    SurahName("الشورى", "Ash-Shūrā"),
    SurahName("الزخرف", "Az-Zukhruf"),
    SurahName("الدخان", "Ad-Dukhān"),
    SurahName("الجاثية", "Al-Jāthiyah"),
    SurahName("الأحقاف", "Al-Aḥqāf"),
    SurahName("محمد", "Muḥammad"),
    SurahName("الفتح", "Al-Fatḥ"),
    SurahName("الحجرات", "Al-Ḥujurāt"),
    SurahName("ق", "Qāf"),
    SurahName("الذاريات", "Adh-Dhāriyāt"),
    SurahName("الطور", "Aṭ-Ṭūr"),
    SurahName("النجم", "An-Najm"),
    SurahName("القمر", "Al-Qamar"),
    SurahName("الرحمن", "Ar-Raḥmān"),
    SurahName("الواقعة", "Al-Wāqiʿah"),
    SurahName("الحديد", "Al-Ḥadīd"),
    SurahName("المجادلة", "Al-Mujādilah"),
    SurahName("الحشر", "Al-Ḥashr"),
    SurahName("الممتحنة", "Al-Mumtaḥanah"),
    SurahName("الصف", "Aṣ-Ṣaff"),
    SurahName("الجمعة", "Al-Jumuʿah"),
    SurahName("المنافقون", "Al-Munāfiqūn"),
    SurahName("التغابن", "At-Taghābun"),
    SurahName("الطلاق", "Aṭ-Ṭalāq"),
    SurahName("التحريم", "At-Taḥrīm"),
    SurahName("الملك", "Al-Mulk"),
    SurahName("القلم", "Al-Qalam"),
    SurahName("الحاقة", "Al-Ḥāqqah"),
    SurahName("المعارج", "Al-Maʿārij"),
    SurahName("نوح", "Nūḥ"),
    SurahName("الجن", "Al-Jinn"),
    SurahName("المزمل", "Al-Muzzammil"),
    SurahName("المدثر", "Al-Muddaththir"),
    SurahName("القيامة", "Al-Qiyāmah"),
    SurahName("الإنسان", "Al-Insān"),
    SurahName("المرسلات", "Al-Mursalāt"),
    SurahName("النبأ", "An-Nabaʾ"),
    SurahName("النازعات", "An-Nāziʿāt"),
    SurahName("عبس", "ʿAbasa"),
    SurahName("التكوير", "At-Takwīr"),
    SurahName("الانفطار", "Al-Infiṭār"),
    SurahName("المطففين", "Al-Muṭaffifīn"),
    SurahName("الانشقاق", "Al-Inshiqāq"),
    SurahName("البروج", "Al-Burūj"),
    SurahName("الطارق", "Aṭ-Ṭāriq"),
    SurahName("الأعلى", "Al-Aʿlā"),
    SurahName("الغاشية", "Al-Ghāshiyah"),
    SurahName("الفجر", "Al-Fajr"),
    SurahName("البلد", "Al-Balad"),
    SurahName("الشمس", "Ash-Shams"),
    SurahName("الليل", "Al-Layl"),
    SurahName("الضحى", "Aḍ-Ḍuḥā"),
    SurahName("الشرح", "Ash-Sharḥ"),
    SurahName("التين", "At-Tīn"),
    SurahName("العلق", "Al-ʿAlaq"),
    SurahName("القدر", "Al-Qadr"),
    SurahName("البينة", "Al-Bayyinah"),
    SurahName("الزلزلة", "Az-Zalzalah"),
    SurahName("العاديات", "Al-ʿĀdiyāt"),
    SurahName("القارعة", "Al-Qāriʿah"),
    SurahName("التكاثر", "At-Takāthur"),
    SurahName("العصر", "Al-ʿAṣr"),
    SurahName("الهمزة", "Al-Humazah"),
    SurahName("الفيل", "Al-Fīl"),
    SurahName("قريش", "Quraysh"),
    SurahName("الماعون", "Al-Māʿūn"),
    SurahName("الكوثر", "Al-Kawthar"),
    SurahName("الكافرون", "Al-Kāfirūn"),
    SurahName("النصر", "An-Naṣr"),
    SurahName("المسد", "Al-Masad"),
    SurahName("الإخلاص", "Al-Ikhlāṣ"),
    SurahName("الفلق", "Al-Falaq"),
    SurahName("الناس", "An-Nās"),
)

internal fun surahName(number: Int): SurahName? = QURAN_SURAH_NAMES.getOrNull(number - 1)

internal fun toArabicIndicDigits(number: Int): String =
    number.toString().map { ('٠' + (it - '0')) }.joinToString("")

/** The rendered pieces of a QURAN segment's text: plain runs and end-of-ayah medallions. */
internal sealed interface QuranToken {
    data class Body(val text: String) : QuranToken

    /** e.g. "۝١" — U+06DD followed by Arabic-Indic digits, composed by the font. */
    data class AyahMarker(val display: String) : QuranToken
}

private val AYAH_MARKER = Regex("""[(（]\s*([0-9٠-٩]{1,3})\s*[)）]|۝\s*([0-9٠-٩]{1,3})?""")

private fun String.toWesternDigits(): String =
    map { if (it in '٠'..'٩') ('0' + (it - '٠')) else it }.joinToString("")

/**
 * Splits raw ayah text into body runs and normalized ayah-end markers. `(n)`, `（n）`, `۝n`, and a
 * bare `۝` all become markers; surrounding whitespace collapses so the medallion sits inline with
 * a single space on each side.
 */
internal fun tokenizeQuranText(raw: String): List<QuranToken> {
    val tokens = mutableListOf<QuranToken>()
    var cursor = 0
    for (match in AYAH_MARKER.findAll(raw)) {
        val body = raw.substring(cursor, match.range.first).trim()
        if (body.isNotEmpty()) tokens += QuranToken.Body(body)
        val digits = (match.groupValues[1].ifEmpty { match.groupValues[2] }).toWesternDigits()
        val display = "۝" + (digits.toIntOrNull()?.let { toArabicIndicDigits(it) } ?: "")
        tokens += QuranToken.AyahMarker(display)
        cursor = match.range.last + 1
    }
    val tail = raw.substring(cursor).trim()
    if (tail.isNotEmpty()) tokens += QuranToken.Body(tail)
    return tokens
}

private val ARABIC_DECORATIONS = Regex("[\\u064B-\\u0652\\u0670\\u0640\\u06D6-\\u06ED]")

/**
 * If the first newline-delimited line of [raw] is a bismillah, returns it separately from the
 * rest so it renders as its own centered opening line. Diacritics, tatweel, and alef-wasla
 * variants are ignored when matching.
 */
internal fun splitBismillah(raw: String): Pair<String?, String> {
    val newline = raw.indexOf('\n')
    if (newline <= 0) return null to raw
    val first = raw.substring(0, newline).trim()
    val normalized = ARABIC_DECORATIONS.replace(first, "")
        .replace("ٱ", "ا") // alef wasla → alef
        .replace(" ", "")
    return if (normalized == "بسماللهالرحمنالرحيم") {
        first to raw.substring(newline + 1).trim()
    } else {
        null to raw
    }
}

/** Ranges (inclusive) of ornate `﴿…﴾` Quran quotations embedded in du'a/dhikr text. */
internal fun quranQuoteRanges(text: String): List<IntRange> {
    val ranges = mutableListOf<IntRange>()
    var start = -1
    text.forEachIndexed { i, ch ->
        when (ch) {
            '﴿' -> start = i
            '﴾' -> if (start >= 0) {
                ranges += start..i
                start = -1
            }
        }
    }
    return ranges
}

internal fun buildQuranAnnotated(tokens: List<QuranToken>, markerStyle: SpanStyle): AnnotatedString =
    buildAnnotatedString {
        tokens.forEachIndexed { i, token ->
            when (token) {
                is QuranToken.Body -> append(token.text)
                is QuranToken.AyahMarker -> {
                    if (i > 0) append(' ')
                    withStyle(markerStyle) { append(token.display) }
                    append(' ')
                }
            }
        }
    }

@Composable
internal fun SurahHeader(ref: QuranRef, fontScale: Float, modifier: Modifier = Modifier) {
    val info = surahName(ref.surah)
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Surface(
            shape = RoundedCornerShape(50),
            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.08f),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.3f)),
        ) {
            Text(
                text = info?.let { "سُورَةُ ${it.arabic}" } ?: ref.displayText(),
                color = MaterialTheme.colorScheme.primary,
                style = MaterialTheme.typography.titleMedium.copy(
                    fontFamily = NotoNaskhArabicFontFamily,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 17.sp * fontScale,
                ),
                modifier = Modifier.padding(horizontal = 22.dp, vertical = 7.dp),
            )
        }
        if (info != null) {
            Spacer(Modifier.height(5.dp))
            val range = "${ref.surah}:${ref.ayahStart}" + (ref.ayahEnd?.let { "–$it" } ?: "")
            Text(
                text = "Sūrat ${info.transliteration} · $range",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.labelSmall,
            )
        }
    }
}

@Composable
internal fun QuranBodyText(
    arabic: String,
    fontScale: Float,
    lineSpacing: Float = 1f,
    modifier: Modifier = Modifier,
    maxLines: Int = Int.MAX_VALUE,
    overflow: TextOverflow = TextOverflow.Clip,
    onTextLayout: (TextLayoutResult) -> Unit = {},
) {
    val medallion = MaterialTheme.colorScheme.primary
    val annotated = remember(arabic, medallion) {
        buildQuranAnnotated(
            tokenizeQuranText(arabic),
            // Ayah medallions in the accent color, matching the count ring.
            SpanStyle(color = medallion),
        )
    }
    Text(
        text = annotated,
        color = MaterialTheme.colorScheme.onSurface,
        style = MaterialTheme.typography.headlineMedium.copy(
            fontFamily = NotoNaskhArabicFontFamily,
            fontSize = 26.sp * fontScale,
            lineHeight = 54.sp * fontScale * lineSpacing,
        ),
        // Long passages justify like a mushaf page; short ones stay centered.
        textAlign = if (annotated.length > 120) TextAlign.Justify else TextAlign.Center,
        maxLines = maxLines,
        overflow = overflow,
        onTextLayout = onTextLayout,
        modifier = modifier.fillMaxWidth(),
    )
}
