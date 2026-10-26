package app.awrad.core.domain.hijri

import java.time.LocalDate

/**
 * The Hijri calendar the rules use (root ADR-2026-10-26): the shared Umm al-Qura table, moved by the
 * account's [corrections]. No platform Hijri library is involved.
 *
 * - A day belongs to the month whose corrected start is on or before it, and before the next month's start.
 * - Outside the corrected table (1400–1500 AH) there's no Hijri date: [monthOf] and [dateOf] return null.
 */
public class HijriCalendar(public val corrections: HijriCorrections) {

    /** Corrected month starts as epoch days; the last element is the corrected end (exclusive). */
    private val starts: LongArray = correctedMonthStarts(corrections.corrections)

    /** The first day with a Hijri date. */
    public val firstDay: LocalDate get() = LocalDate.ofEpochDay(starts.first())

    /** The last day with a Hijri date. */
    public val lastDay: LocalDate get() = LocalDate.ofEpochDay(starts.last() - 1)

    /** The corrected month containing [date], or null outside the table. */
    public fun monthOf(date: LocalDate): HijriMonth? {
        val day = date.toEpochDay()
        if (day < starts.first() || day >= starts.last()) return null
        val found = starts.binarySearch(day)
        val index = if (found >= 0) found else -found - 2
        return HijriMonth(
            year = UmmAlQura.yearOf(index),
            month = UmmAlQura.monthOf(index),
            firstDay = LocalDate.ofEpochDay(starts[index]),
            length = (starts[index + 1] - starts[index]).toInt(),
        )
    }

    /** The Hijri date of [date], or null outside the table. */
    public fun dateOf(date: LocalDate): HijriDate? = monthOf(date)?.dateOf(date)

    override fun equals(other: Any?): Boolean = other is HijriCalendar && other.corrections == corrections

    override fun hashCode(): Int = corrections.hashCode()

    override fun toString(): String = "HijriCalendar(${corrections.corrections})"
}

/**
 * Month starts with [corrections] applied. A correction moves its month's start, and every later month's
 * until the next correction; the table's end moves with the last correction in force. The corrections
 * must be inside the table and one per month.
 */
internal fun correctedMonthStarts(corrections: Collection<HijriCorrection>): LongArray {
    val offsets = corrections.associate { UmmAlQura.indexOf(it.year, it.month) to it.offsetDays }
    val table = UmmAlQura.starts
    var offset = 0
    return LongArray(table.size) { index ->
        offsets[index]?.let { offset = it }
        table[index] + offset
    }
}

/** The bundled table ([UmmAlQuraTable]) as epoch days, indexed by month from 1 Muharram of the first year. */
internal object UmmAlQura {
    const val FIRST_YEAR: Int = UmmAlQuraTable.FIRST_YEAR
    const val LAST_YEAR: Int = UmmAlQuraTable.LAST_YEAR
    private const val MONTHS = HijriDate.MONTHS_PER_YEAR

    /** Every month's start, then the table's end (exclusive). */
    val starts: LongArray by lazy {
        val months = UmmAlQuraTable.MONTH_STARTS.lineSequence()
            .filter { it.isNotBlank() }
            .flatMap { line -> line.trim().split(' ').drop(1) }
            .map { LocalDate.parse(it).toEpochDay() }
            .toList()
        check(months.size == (LAST_YEAR - FIRST_YEAR + 1) * MONTHS) { "Umm al-Qura table is incomplete" }
        (months + LocalDate.parse(UmmAlQuraTable.END_EXCLUSIVE).toEpochDay()).toLongArray()
    }

    fun isInTable(year: Int, month: Int): Boolean = year in FIRST_YEAR..LAST_YEAR && month in 1..MONTHS

    fun indexOf(year: Int, month: Int): Int {
        require(isInTable(year, month)) { "$year-$month is outside the Umm al-Qura table" }
        return (year - FIRST_YEAR) * MONTHS + month - 1
    }

    fun yearOf(index: Int): Int = FIRST_YEAR + index / MONTHS

    fun monthOf(index: Int): Int = index % MONTHS + 1
}
