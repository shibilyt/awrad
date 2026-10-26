package app.awrad.core.domain.hijri

import kotlin.math.absoluteValue

/**
 * A month-start correction for local moon sighting, before validation (`correction_shape`):
 * [offsetDays] moves the start of Hijri [year]-[month], and every later month until the next
 * correction, from the table (positive = later). Only a valid set becomes [HijriCorrections].
 */
public data class HijriCorrection(val year: Int, val month: Int, val offsetDays: Int)

/** Why a correction set is invalid. The codes are `hijri_corrections_validity.json`'s, in alphabetical order. */
public enum class HijriCorrectionsError {
    /** Two corrections for the same month. */
    DUPLICATE_MONTH,

    /** A corrected month would have fewer than 29 or more than 30 days. Checked only when nothing else fails. */
    MONTH_LENGTH_INVALID,

    /** A correction outside 1400–1500 AH or months 1–12. */
    MONTH_OUT_OF_RANGE,

    /** A correction more than [HijriCorrections.MAX_OFFSET_DAYS] days from the table. */
    OFFSET_OUT_OF_RANGE,
}

/** The outcome of [HijriCorrections.create]: the corrections, or every reason they're invalid. */
public sealed interface HijriCorrectionsResult {
    public data class Valid(val corrections: HijriCorrections) : HijriCorrectionsResult

    public data class Invalid(val errors: Set<HijriCorrectionsError>) : HijriCorrectionsResult {
        init {
            require(errors.isNotEmpty()) { "An invalid correction set has at least one error" }
        }
    }
}

/**
 * The account's Hijri corrections (CONTEXT.md, "Hijri correction"): part of the practice policy.
 *
 * Only valid sets exist: at most one per month, inside the table, at most 2 days from it, and every
 * corrected month still 29 or 30 days. Build one with [create]; order doesn't matter.
 */
@ConsistentCopyVisibility
public data class HijriCorrections private constructor(val corrections: Set<HijriCorrection>) {

    public companion object {
        public const val MAX_OFFSET_DAYS: Int = 2

        /** No corrections: the table as published. */
        public val NONE: HijriCorrections = HijriCorrections(emptySet())

        /** Validates [corrections] (fixture `hijri_corrections_validity`) and builds the set, or says why not. */
        public fun create(corrections: List<HijriCorrection>): HijriCorrectionsResult {
            val errors = buildSet {
                if (corrections.any { it.offsetDays.absoluteValue > MAX_OFFSET_DAYS }) {
                    add(HijriCorrectionsError.OFFSET_OUT_OF_RANGE)
                }
                if (corrections.any { !UmmAlQura.isInTable(it.year, it.month) }) {
                    add(HijriCorrectionsError.MONTH_OUT_OF_RANGE)
                }
                if (corrections.distinctBy { it.year to it.month }.size != corrections.size) {
                    add(HijriCorrectionsError.DUPLICATE_MONTH)
                }
                if (isEmpty() && !hasValidMonthLengths(corrections)) add(HijriCorrectionsError.MONTH_LENGTH_INVALID)
            }
            return if (errors.isEmpty()) {
                HijriCorrectionsResult.Valid(HijriCorrections(corrections.toSet()))
            } else {
                HijriCorrectionsResult.Invalid(errors)
            }
        }

        private fun hasValidMonthLengths(corrections: List<HijriCorrection>): Boolean {
            val starts = correctedMonthStarts(corrections)
            return (0 until starts.lastIndex).all { index ->
                starts[index + 1] - starts[index] in HijriDate.MIN_MONTH_LENGTH..HijriDate.MAX_MONTH_LENGTH
            }
        }
    }
}
