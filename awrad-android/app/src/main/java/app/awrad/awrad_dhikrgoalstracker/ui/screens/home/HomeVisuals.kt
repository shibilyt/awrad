package app.awrad.awrad_dhikrgoalstracker.ui.screens.home

import androidx.annotation.DrawableRes
import androidx.compose.ui.graphics.Color
import app.awrad.awrad_dhikrgoalstracker.R
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import kotlin.math.PI
import kotlin.math.sin

private const val DAY_MILLIS = 24L * 60L * 60L * 1000L

enum class HomeDayPeriod {
    Dawn,
    Day,
    Dusk,
    Night,
}

data class HomeCelestialPlacement(
    val isMoon: Boolean,
    val xFraction: Float,
    val yFraction: Float,
    val alpha: Float,
)

data class HomeVisuals(
    val period: HomeDayPeriod,
    val isNight: Boolean,
    val isDarkTheme: Boolean,
    @DrawableRes val featuredImageRes: Int,
    @DrawableRes val goalsImageRes: Int,
    val celestial: HomeCelestialPlacement,
    val screenGradient: List<Color>,
    val cardColor: Color,
    val cardBorderColor: Color,
    val elevatedCardColor: Color,
    val primaryTextColor: Color,
    val secondaryTextColor: Color,
    val accentColor: Color,
    val goalAccentColor: Color,
    val chipColor: Color,
    val chipContentColor: Color,
    val trackColor: Color,
)

fun resolveHomeVisuals(
    now: Instant,
    prayerState: PrayerCardState,
    isDarkTheme: Boolean,
): HomeVisuals {
    val nowMillis = now.toEpochMilli()
    val (sunriseMillis, sunsetMillis) = resolveSolarWindow(now, prayerState)
    val isDaylight = nowMillis in sunriseMillis until sunsetMillis

    val daylightProgress = progressBetween(
        value = nowMillis,
        start = sunriseMillis,
        end = sunsetMillis,
    )
    val period = when {
        !isDaylight -> HomeDayPeriod.Night
        daylightProgress < 0.15f -> HomeDayPeriod.Dawn
        daylightProgress > 0.84f -> HomeDayPeriod.Dusk
        else -> HomeDayPeriod.Day
    }
    val celestial = if (isDaylight) {
        sunPlacement(daylightProgress)
    } else {
        val nightStart = if (nowMillis < sunriseMillis) sunsetMillis - DAY_MILLIS else sunsetMillis
        val nightEnd = if (nowMillis < sunriseMillis) sunriseMillis else sunriseMillis + DAY_MILLIS
        moonPlacement(progressBetween(nowMillis, nightStart, nightEnd))
    }

    return if (isDarkTheme) {
        darkThemeVisuals(
            period = period,
            isNight = !isDaylight,
            celestial = celestial,
        )
    } else {
        when (period) {
            HomeDayPeriod.Dawn -> lightThemeVisuals(
                period = period,
                isNight = false,
                celestial = celestial,
                screenGradient = listOf(
                    Color(0xFFFFFBF2),
                    Color(0xFFF4F6EA),
                    Color(0xFFFFFBF6),
                ),
                cardColor = Color(0xF7FFFDF7),
                accentColor = Color(0xFF4B7C5A),
            )
            HomeDayPeriod.Day -> lightThemeVisuals(
                period = period,
                isNight = false,
                celestial = celestial,
                screenGradient = listOf(
                    Color(0xFFFFFCF5),
                    Color(0xFFF4F8EE),
                    Color(0xFFFEFCF7),
                ),
                cardColor = Color(0xF8FFFDF8),
                accentColor = Color(0xFF4B7C5A),
            )
            HomeDayPeriod.Dusk -> lightThemeVisuals(
                period = period,
                isNight = false,
                celestial = celestial,
                screenGradient = listOf(
                    Color(0xFFFFF6EA),
                    Color(0xFFF3F1E4),
                    Color(0xFFFEF9F1),
                ),
                cardColor = Color(0xF6FFF9F0),
                accentColor = Color(0xFF4B7C5A),
            )
            HomeDayPeriod.Night -> lightThemeVisuals(
                period = period,
                isNight = true,
                celestial = celestial,
                screenGradient = listOf(
                    Color(0xFFF9FBF6),
                    Color(0xFFEFF5EF),
                    Color(0xFFFFFAF4),
                ),
                cardColor = Color(0xF8FEFCF8),
                accentColor = Color(0xFF4B7C5A),
            )
        }
    }
}

private fun lightThemeVisuals(
    period: HomeDayPeriod,
    isNight: Boolean,
    celestial: HomeCelestialPlacement,
    screenGradient: List<Color>,
    cardColor: Color,
    accentColor: Color,
): HomeVisuals = HomeVisuals(
    period = period,
    isNight = isNight,
    isDarkTheme = false,
    featuredImageRes = if (isNight) R.drawable.home_featured_light_night else R.drawable.home_featured_day,
    goalsImageRes = if (isNight) R.drawable.home_goals_light_night else R.drawable.home_goals_day,
    celestial = celestial,
    screenGradient = screenGradient,
    cardColor = cardColor,
    cardBorderColor = Color(0xFFE0E6D6),
    elevatedCardColor = Color(0xFFFFFFFF),
    primaryTextColor = Color(0xFF103C1D),
    secondaryTextColor = Color(0xFF656763),
    accentColor = accentColor,
    goalAccentColor = Color(0xFF4B7C5A),
    chipColor = Color(0xFFD4E8DA),
    chipContentColor = Color(0xFF1A3D26),
    trackColor = Color(0xFFD6E4C7),
)

private fun darkThemeVisuals(
    period: HomeDayPeriod,
    isNight: Boolean,
    celestial: HomeCelestialPlacement,
): HomeVisuals = HomeVisuals(
    period = period,
    isNight = isNight,
    isDarkTheme = true,
    featuredImageRes = if (isNight) R.drawable.home_featured_night else R.drawable.home_featured_dark_day,
    goalsImageRes = if (isNight) R.drawable.home_goals_night else R.drawable.home_goals_dark_day,
    celestial = celestial,
    screenGradient = listOf(
        Color(0xFF010707),
        Color(0xFF061814),
        Color(0xFF010909),
    ),
    cardColor = Color(0xD90B1715),
    cardBorderColor = Color(0xFF1D5E48),
    elevatedCardColor = Color(0xDE101C1E),
    primaryTextColor = Color(0xFFF9FAF4),
    secondaryTextColor = Color(0xFFC5CCC8),
    accentColor = Color(0xFF6B9E7A),
    goalAccentColor = Color(0xFF6B9E7A),
    chipColor = Color(0xFF0D3326),
    chipContentColor = Color(0xFFD4E8DA),
    trackColor = Color(0xFF18523E),
)

private fun resolveSolarWindow(
    now: Instant,
    prayerState: PrayerCardState,
): Pair<Long, Long> {
    val zone = ZoneId.systemDefault()
    val dayStartMillis = now.atZone(zone).toLocalDate()
        .atStartOfDay(zone)
        .toInstant()
        .toEpochMilli()
    val fallbackSunrise = dayStartMillis + Duration.ofHours(6).toMillis()
    val fallbackSunset = dayStartMillis + Duration.ofHours(18).toMillis()
    val sunrise = prayerState.sunriseMillis ?: fallbackSunrise
    val sunset = prayerState.maghribMillis ?: fallbackSunset

    return if (sunset > sunrise) {
        sunrise to sunset
    } else {
        fallbackSunrise to fallbackSunset
    }
}

private fun sunPlacement(progress: Float): HomeCelestialPlacement {
    val clamped = progress.coerceIn(0f, 1f)
    val arc = sin(clamped * PI).toFloat()
    return HomeCelestialPlacement(
        isMoon = false,
        xFraction = 0.13f + 0.74f * clamped,
        yFraction = 0.58f - 0.5f * arc,
        alpha = 0.62f + 0.26f * arc,
    )
}

private fun moonPlacement(progress: Float): HomeCelestialPlacement {
    val clamped = progress.coerceIn(0f, 1f)
    val arc = sin(clamped * PI).toFloat()
    return HomeCelestialPlacement(
        isMoon = true,
        xFraction = 0.12f + 0.76f * clamped,
        yFraction = 0.56f - 0.46f * arc,
        alpha = 0.66f + 0.24f * arc,
    )
}

private fun progressBetween(
    value: Long,
    start: Long,
    end: Long,
): Float {
    if (end <= start) return 0f
    return ((value - start).toFloat() / (end - start).toFloat()).coerceIn(0f, 1f)
}
