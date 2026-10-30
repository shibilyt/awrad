package app.awrad.core.domain.practice

import app.awrad.core.domain.hijri.HijriCorrection
import app.awrad.core.domain.hijri.HijriCorrections
import app.awrad.core.domain.hijri.HijriCorrectionsError
import app.awrad.core.domain.hijri.HijriCorrectionsResult
import app.awrad.core.domain.hijri.HijriDate
import app.awrad.core.domain.sync.FieldError
import app.awrad.core.domain.sync.FieldErrorCode
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put
import kotlin.math.absoluteValue

/**
 * The `practice_policy` document (`urn:awrad:practice-settings:1#/$defs/practice_policy_document`) to and from
 * [PracticePolicy], and its validity (fixture `practice_policy_validity`).
 */
public object PracticePolicyJson {

    private const val DAY_RESET = "day_reset"
    private const val METHOD = "calculation_method"
    private const val MADHAB = "madhab"
    private const val WEEK_START = "week_start"
    private const val CORRECTIONS = "hijri_corrections"
    private val MEMBERS = listOf(DAY_RESET, METHOD, MADHAB, WEEK_START, CORRECTIONS)
    private val CORRECTION_MEMBERS = setOf("year", "month", "offset_days")
    private const val FIRST_YEAR = 1400
    private const val LAST_YEAR = 1500

    /** The document of [policy], every member present and the corrections sorted by year, then month. */
    public fun encode(policy: PracticePolicy): JsonObject = buildJsonObject {
        put(DAY_RESET, policy.dayReset.wire)
        put(METHOD, policy.calculationMethod.wire)
        put(MADHAB, policy.madhab.wire)
        put(WEEK_START, policy.weekStart.wire)
        put(
            CORRECTIONS,
            buildJsonArray {
                sorted(policy.hijriCorrections).forEach { correction ->
                    add(
                        buildJsonObject {
                            put("year", correction.year)
                            put("month", correction.month)
                            put("offset_days", correction.offsetDays)
                        },
                    )
                }
            },
        )
    }

    /** [document] as a policy, or null when it isn't a valid one ([errors]). */
    public fun decode(document: JsonObject): PracticePolicy? {
        val corrections = if (errors(document).isEmpty()) validCorrections(document) else null
        return corrections?.let {
            PracticePolicy(
                dayReset = checkNotNull(DayReset.fromWire(document.text(DAY_RESET).orEmpty())),
                calculationMethod = checkNotNull(CalculationMethod.fromWire(document.text(METHOD).orEmpty())),
                madhab = checkNotNull(Madhab.fromWire(document.text(MADHAB).orEmpty())),
                weekStart = checkNotNull(WeekStart.fromWire(document.text(WEEK_START).orEmpty())),
                hijriCorrections = it,
            )
        }
    }

    private fun validCorrections(document: JsonObject): HijriCorrections? =
        (document[CORRECTIONS] as? JsonArray)?.let(::corrections)
            ?.let { HijriCorrections.create(it) as? HijriCorrectionsResult.Valid }
            ?.corrections

    /**
     * Every `{field, code}` error of [document], sorted by field, then code; empty when it's valid. A member
     * outside the policy is `not_allowed`; a missing one `required`; a value that isn't one of the member's
     * `invalid`; a correction that isn't exactly `{year, month, offset_days}` in range `invalid` at its index. Only
     * when every correction is well formed, a repeated month is `duplicate` on each later one; and only without
     * duplicates, a month of neither 29 nor 30 days is `range` on `/hijri_corrections`.
     */
    public fun errors(document: JsonObject): List<FieldError> {
        val errors = mutableListOf<FieldError>()
        document.keys.filterNot { it in MEMBERS }.forEach { errors += FieldError("/$it", FieldErrorCode.NOT_ALLOWED) }
        val enums = mapOf<String, (String) -> Any?>(
            DAY_RESET to DayReset::fromWire,
            METHOD to CalculationMethod::fromWire,
            MADHAB to Madhab::fromWire,
            WEEK_START to WeekStart::fromWire,
        )
        MEMBERS.forEach { member ->
            val value = document[member]
            val parse = enums[member]
            when {
                value == null -> errors += FieldError("/$member", FieldErrorCode.REQUIRED)
                parse != null && document.text(member)?.let(parse) == null ->
                    errors += FieldError("/$member", FieldErrorCode.INVALID)
            }
        }
        document[CORRECTIONS]?.let { errors += correctionErrors(it) }
        return errors.sortedWith(compareBy<FieldError> { it.field }.thenBy { it.code.wire })
    }

    private fun correctionErrors(value: JsonElement): List<FieldError> {
        if (value !is JsonArray) return listOf(FieldError("/$CORRECTIONS", FieldErrorCode.INVALID))
        val shapes = value.map(::correctionOf)
        val bad = shapes.indices.filter { shapes[it] == null }
        val corrections = shapes.filterNotNull()
        val seen = mutableSetOf<Pair<Int, Int>>()
        val duplicates = corrections.indices.filterNot { seen.add(corrections[it].year to corrections[it].month) }
        return when {
            bad.isNotEmpty() -> bad.map { FieldError("/$CORRECTIONS/$it", FieldErrorCode.INVALID) }
            duplicates.isNotEmpty() -> duplicates.map { FieldError("/$CORRECTIONS/$it", FieldErrorCode.DUPLICATE) }
            monthLengthsInvalid(corrections) -> listOf(FieldError("/$CORRECTIONS", FieldErrorCode.RANGE))
            else -> emptyList()
        }
    }

    private fun monthLengthsInvalid(corrections: List<HijriCorrection>): Boolean {
        val result = HijriCorrections.create(corrections)
        return result is HijriCorrectionsResult.Invalid && HijriCorrectionsError.MONTH_LENGTH_INVALID in result.errors
    }

    /** The corrections of a well-formed list, or null when one isn't. */
    private fun corrections(array: JsonArray): List<HijriCorrection>? =
        array.map { correctionOf(it) ?: return null }

    /** [element] as a correction: exactly `{year, month, offset_days}`, integers in range; else null. */
    @Suppress("ReturnCount") // One early return per member that can be wrong.
    private fun correctionOf(element: JsonElement): HijriCorrection? {
        if (element !is JsonObject || element.keys != CORRECTION_MEMBERS) return null
        val year = element.integer("year") ?: return null
        val month = element.integer("month") ?: return null
        val offset = element.integer("offset_days") ?: return null
        val inRange = year in FIRST_YEAR..LAST_YEAR && month in 1..HijriDate.MONTHS_PER_YEAR &&
            offset.absoluteValue <= HijriCorrections.MAX_OFFSET_DAYS
        return HijriCorrection(year, month, offset).takeIf { inRange }
    }

    /** Corrections in the order documents list them: by year, then month. */
    public fun sorted(corrections: HijriCorrections): List<HijriCorrection> =
        corrections.corrections.sortedWith(compareBy({ it.year }, { it.month }))

    /** A string member's text; null for anything else, including JSON null and numbers. */
    private fun JsonObject.text(member: String): String? =
        (this[member] as? JsonPrimitive)?.takeIf { it.isString }?.content

    /** A whole-number member as JSON numbers allow it (`1` or `1.0`); null for strings, fractions and the rest. */
    @Suppress("ReturnCount") // Each JSON number form is its own case.
    private fun JsonObject.integer(member: String): Int? {
        val primitive = this[member] as? JsonPrimitive ?: return null
        if (primitive.isString) return null
        primitive.longOrNull?.let { return it.toInt().takeIf { int -> int.toLong() == it } }
        val double = primitive.doubleOrNull ?: return null
        return double.toInt().takeIf { it.toDouble() == double }
    }
}
