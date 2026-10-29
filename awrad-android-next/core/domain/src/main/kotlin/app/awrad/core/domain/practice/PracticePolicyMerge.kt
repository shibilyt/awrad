package app.awrad.core.domain.practice

import app.awrad.core.domain.hijri.HijriCorrection
import app.awrad.core.domain.hijri.HijriCorrections
import app.awrad.core.domain.hijri.HijriCorrectionsResult

/**
 * The result of [PracticePolicyMerge.merge]: the merged [policy]; whether it differs from the server's and must be
 * sent ([requeue]); and whether this phone's Hijri corrections were dropped because the merge made them invalid
 * ([correctionsReplaced], the notice `hijri_corrections_replaced`).
 */
public data class PolicyMerge(val policy: PracticePolicy, val requeue: Boolean, val correctionsReplaced: Boolean)

/**
 * Merge by setting (fixture `practice_policy_merge`; contracts/practice-settings/v1/README.md, "Syncing the
 * policy"): what a phone does when its policy put conflicts, instead of asking.
 */
public object PracticePolicyMerge {

    /**
     * Every setting where [mine] differs from [base] keeps mine, the rest is [theirs]. Hijri corrections merge
     * month by month the same way: a month added, changed or removed in [mine] relative to [base] wins, and the
     * server's other months stay. Merged corrections that aren't a valid set fall back to theirs.
     */
    public fun merge(base: PracticePolicy, mine: PracticePolicy, theirs: PracticePolicy): PolicyMerge {
        fun <T> pick(of: PracticePolicy.() -> T): T = if (mine.of() != base.of()) mine.of() else theirs.of()
        val merged = mergeCorrections(base.hijriCorrections, mine.hijriCorrections, theirs.hijriCorrections)
        val policy = PracticePolicy(
            dayReset = pick { dayReset },
            calculationMethod = pick { calculationMethod },
            madhab = pick { madhab },
            weekStart = pick { weekStart },
            hijriCorrections = merged ?: theirs.hijriCorrections,
        )
        return PolicyMerge(policy = policy, requeue = policy != theirs, correctionsReplaced = merged == null)
    }

    /** The month-by-month merge, or null when the result isn't a valid set. */
    private fun mergeCorrections(
        base: HijriCorrections,
        mine: HijriCorrections,
        theirs: HijriCorrections,
    ): HijriCorrections? {
        val b = base.byMonth()
        val m = mine.byMonth()
        val result = theirs.byMonth().toMutableMap()
        (b.keys + m.keys).forEach { month ->
            val local = m[month]
            when {
                local == b[month] -> Unit
                local != null -> result[month] = local
                else -> result.remove(month)
            }
        }
        return (HijriCorrections.create(result.values.toList()) as? HijriCorrectionsResult.Valid)?.corrections
    }

    private fun HijriCorrections.byMonth(): Map<Pair<Int, Int>, HijriCorrection> =
        corrections.associateBy { it.year to it.month }
}
