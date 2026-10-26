package app.awrad.core.domain.hijri

import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.date
import app.awrad.core.testing.fixtures.hijriCorrections
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import kotlin.test.Test

class HijriDateFixtureTest {

    @Test
    fun `every hijri_date fixture case passes`() {
        FixtureRunner.runHijriCalendar("hijri_date") { given ->
            val date = given.date("date")
            val month = HijriCalendar(given.hijriCorrections("corrections")).monthOf(date)
            buildJsonObject {
                if (month == null) {
                    put("hijri", JsonNull)
                    put("month_length", JsonNull)
                } else {
                    val hijri = month.dateOf(date)
                    putJsonObject("hijri") {
                        put("year", hijri.year)
                        put("month", hijri.month)
                        put("day", hijri.day)
                    }
                    put("month_length", month.length)
                }
            }
        }
    }
}
