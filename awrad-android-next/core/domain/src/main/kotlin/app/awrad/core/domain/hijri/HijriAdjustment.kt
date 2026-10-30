package app.awrad.core.domain.hijri

import java.time.LocalDate

/**
 * What Settings' "Adjust this month" may offer (contracts/practice-settings/v1/README.md, "Validity"). Every month
 * stays 29 or 30 days, so a month can usually move only one day from the month before, in one direction; only the
 * offsets that keep the set valid are offered.
 */
public object HijriAdjustment {

    /** From this day of a month on, Settings offers the next month too: sightings are announced then. */
    public const val NEXT_MONTH_FROM_DAY: Int = 29

    /** The offset from the table in force for [year]-[month]: its own correction, else the last earlier one, else 0. */
    public fun offsetInForce(corrections: HijriCorrections, year: Int, month: Int): Int =
        offsetInForce(corrections.corrections, year, month)

    private fun offsetInForce(corrections: Collection<HijriCorrection>, year: Int, month: Int): Int =
        corrections
            .filter { it.year < year || it.year == year && it.month <= month }
            .maxWithOrNull(compareBy({ it.year }, { it.month }))
            ?.offsetDays ?: 0

    /** The offsets [year]-[month] may take, from −2 to 2, that leave a valid set. */
    public fun allowedOffsets(corrections: HijriCorrections, year: Int, month: Int): List<Int> =
        (-HijriCorrections.MAX_OFFSET_DAYS..HijriCorrections.MAX_OFFSET_DAYS).filter {
            withOffset(corrections, year, month, it) != null
        }

    /**
     * [corrections] with [year]-[month] moved to [offsetDays] from the table, or null when that isn't valid. An
     * offset equal to the one carried from earlier months needs no correction of its own, so it's removed instead.
     */
    public fun withOffset(corrections: HijriCorrections, year: Int, month: Int, offsetDays: Int): HijriCorrections? {
        val others = corrections.corrections.filterNot { it.year == year && it.month == month }
        val carried = offsetInForce(others, year, month)
        val updated = if (offsetDays == carried) others else others + HijriCorrection(year, month, offsetDays)
        return create(updated)
    }

    /** [corrections] without [correction], or null when the rest isn't a valid set. */
    public fun without(corrections: HijriCorrections, correction: HijriCorrection): HijriCorrections? =
        create(corrections.corrections.filterNot { it == correction })

    /**
     * The months Settings offers to adjust on [today]: its month, and from its day [NEXT_MONTH_FROM_DAY] on the next
     * one too (while it's still in the table).
     */
    public fun adjustableMonths(calendar: HijriCalendar, today: LocalDate): List<HijriMonth> {
        val month = calendar.monthOf(today) ?: return emptyList()
        val day = month.dateOf(today).day
        val next = if (day >= NEXT_MONTH_FROM_DAY) calendar.monthOf(month.lastDay.plusDays(1)) else null
        return listOfNotNull(month, next)
    }

    private fun create(corrections: List<HijriCorrection>): HijriCorrections? =
        (HijriCorrections.create(corrections) as? HijriCorrectionsResult.Valid)?.corrections
}
