package app.awrad.awrad_dhikrgoalstracker.data.network

import com.google.gson.annotations.SerializedName

data class CommunityStatsDto(
    @SerializedName("as_of") val asOf: String,
    @SerializedName("count_semantics") val countSemantics: String,
    @SerializedName("total_tracked_goals") val totalTrackedGoals: Long,
    @SerializedName("approximate_total_counts") val approximateTotalCounts: String,
    @SerializedName("approximate_dhikr_hours") val approximateDhikrHours: Double,
    @SerializedName("seconds_per_count") val secondsPerCount: Int,
    @SerializedName("daily_counts") val dailyCounts: List<CommunityDailyCountDto>,
)

data class CommunityDailyCountDto(
    @SerializedName("date") val date: String,
    @SerializedName("approximate_count") val approximateCount: String,
)
