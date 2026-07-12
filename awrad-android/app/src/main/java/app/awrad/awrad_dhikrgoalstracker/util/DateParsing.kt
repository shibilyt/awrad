package app.awrad.awrad_dhikrgoalstracker.util

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

fun String?.toLocalDateOrNull(): LocalDate? =
    this
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?.let { dateText -> runCatching { LocalDate.parse(dateText) }.getOrNull() }

fun String?.toLocalDateOr(fallback: LocalDate): LocalDate =
    toLocalDateOrNull() ?: fallback

fun Long.toLocalDateFromEpochMillis(zoneId: ZoneId = ZoneId.systemDefault()): LocalDate =
    Instant.ofEpochMilli(this).atZone(zoneId).toLocalDate()
