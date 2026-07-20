package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.network.CommunityDailyCountDto
import app.awrad.awrad_dhikrgoalstracker.data.network.CommunityStatsDto
import java.io.IOException
import java.math.BigInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class CommunityStatsMappingTest {
    @Test
    fun `maps decimal strings without losing large integer precision`() {
        val hugeCount = "99999999999999999999999999999999999999"

        val result = dto(
            total = hugeCount,
            days = listOf(
                CommunityDailyCountDto("2026-07-19", hugeCount),
                CommunityDailyCountDto("2026-07-18", "1200"),
            ),
        ).toDomain()

        assertEquals(BigInteger(hugeCount), result.approximateTotalCounts)
        assertEquals(BigInteger("1200"), result.dailyCounts.first().approximateCount)
        assertEquals("2026-07-18", result.dailyCounts.first().date.toString())
        assertEquals("9.6", result.approximateDhikrHours.toPlainString())
    }

    @Test
    fun `rejects malformed or negative count strings as invalid responses`() {
        assertThrows(IOException::class.java) { dto(total = "12.5").toDomain() }
        assertThrows(IOException::class.java) { dto(total = "-1").toDomain() }
    }

    private fun dto(
        total: String,
        days: List<CommunityDailyCountDto> = emptyList(),
    ) = CommunityStatsDto(
        asOf = "2026-07-19T16:00:00Z",
        countSemantics = "current_canonical_net",
        totalTrackedGoals = 12,
        approximateTotalCounts = total,
        approximateDhikrHours = 9.6,
        secondsPerCount = 1,
        dailyCounts = days,
    )
}
