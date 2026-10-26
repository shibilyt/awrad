package app.awrad.core.domain.hijri

import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.hijriCorrectionList
import app.awrad.core.testing.fixtures.toFixtureName
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.test.Test

class HijriCorrectionsValidityFixtureTest {

    @Test
    fun `every hijri_corrections_validity fixture case passes`() {
        FixtureRunner.runHijriCalendar("hijri_corrections_validity") { given ->
            val errors = when (val result = HijriCorrections.create(given.hijriCorrectionList("corrections"))) {
                is HijriCorrectionsResult.Valid -> emptyList()
                is HijriCorrectionsResult.Invalid -> result.errors.map { it.toFixtureName() }.sorted()
            }
            buildJsonObject {
                put("valid", errors.isEmpty())
                putJsonArray("errors") { errors.forEach { add(it) } }
            }
        }
    }
}
