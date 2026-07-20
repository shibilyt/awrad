package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.network.AwradApiService
import app.awrad.awrad_dhikrgoalstracker.data.network.CommunityStatsDto
import java.io.IOException
import java.math.BigDecimal
import java.math.BigInteger
import java.time.Instant
import java.time.LocalDate
import javax.inject.Inject

data class CommunityStats(
    val asOf: Instant,
    val countSemantics: String,
    val totalTrackedGoals: Long,
    val approximateTotalCounts: BigInteger,
    val approximateDhikrHours: BigDecimal,
    val secondsPerCount: Int,
    val dailyCounts: List<CommunityDailyCount>,
)

data class CommunityDailyCount(
    val date: LocalDate,
    val approximateCount: BigInteger,
)

interface CommunityStatsRepository {
    suspend fun getStats(forceRefresh: Boolean = false): CommunityStats
}

class CommunityStatsRepositoryImpl @Inject constructor(
    private val apiService: AwradApiService,
) : CommunityStatsRepository {
    override suspend fun getStats(forceRefresh: Boolean): CommunityStats {
        val response = apiService.communityStats(cacheControl = if (forceRefresh) "no-cache" else null)
        if (!response.isSuccessful) throw IOException("Community stats request failed (${response.code()})")
        return response.body()?.toDomain() ?: throw IOException("Community stats response was empty")
    }
}

internal fun CommunityStatsDto.toDomain(): CommunityStats = try {
    CommunityStats(
        asOf = Instant.parse(asOf),
        countSemantics = countSemantics,
        totalTrackedGoals = totalTrackedGoals.also { require(it >= 0) },
        approximateTotalCounts = approximateTotalCounts.toNonNegativeInteger(),
        approximateDhikrHours = BigDecimal.valueOf(approximateDhikrHours).also { require(it.signum() >= 0) },
        secondsPerCount = secondsPerCount.also { require(it > 0) },
        dailyCounts = dailyCounts.map { daily ->
            CommunityDailyCount(
                date = LocalDate.parse(daily.date),
                approximateCount = daily.approximateCount.toNonNegativeInteger(),
            )
        }.sortedBy { it.date },
    )
} catch (error: Exception) {
    throw IOException("Community stats response was invalid", error)
}

private fun String.toNonNegativeInteger(): BigInteger =
    BigInteger(this).also { require(it.signum() >= 0) }
