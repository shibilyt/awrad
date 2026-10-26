package app.awrad.core.domain.practice

import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.string
import app.awrad.core.testing.fixtures.stringOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test

class EffectivePracticeDayFixtureTest {

    @Test
    fun `every effective_practice_day fixture case passes`() {
        FixtureRunner.runGoalModel("effective_practice_day") { given ->
            val day = EffectivePracticeDay.of(
                instant = Instant.parse(given.string("instant")),
                zone = ZoneId.of(given.string("timezone")),
                dayReset = DayReset.valueOf(given.string("day_reset").uppercase()),
                maghrib = given.stringOrNull("maghrib")?.let(Instant::parse),
            )
            buildJsonObject { put("date", day.toString()) }
        }
    }
}
