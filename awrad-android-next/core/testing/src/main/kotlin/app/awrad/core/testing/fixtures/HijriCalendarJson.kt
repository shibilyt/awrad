package app.awrad.core.testing.fixtures

import app.awrad.core.domain.hijri.HijriCorrection
import app.awrad.core.domain.hijri.HijriCorrections
import app.awrad.core.domain.hijri.HijriCorrectionsResult
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject

/*
 * Decoders from the hijri-calendar fixture JSON (contracts/hijri-calendar/v1/hijri-calendar.schema.json).
 */

/** A `corrections_shape` array, unvalidated, for `hijri_corrections_validity`. */
public fun JsonObject.hijriCorrectionList(key: String): List<HijriCorrection> =
    getValue(key).jsonArray.map {
        val correction = it.jsonObject
        HijriCorrection(
            year = correction.int("year"),
            month = correction.int("month"),
            offsetDays = correction.int("offset_days"),
        )
    }

/**
 * A valid `corrections` array, as every rule fixture holds; fails the case when the domain rejects it.
 * [key] may be absent, which means no corrections (the goal-model fixtures' optional `hijri_corrections`).
 */
public fun JsonObject.hijriCorrections(key: String = "hijri_corrections"): HijriCorrections {
    if (key !in this) return HijriCorrections.NONE
    return when (val result = HijriCorrections.create(hijriCorrectionList(key))) {
        is HijriCorrectionsResult.Valid -> result.corrections
        is HijriCorrectionsResult.Invalid -> error("Fixture Hijri corrections are invalid: ${result.errors}")
    }
}
