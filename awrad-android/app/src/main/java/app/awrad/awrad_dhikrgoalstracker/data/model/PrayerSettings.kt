package app.awrad.awrad_dhikrgoalstracker.data.model

enum class CalculationMethodPref(val displayName: String) {
    KARACHI("University of Karachi"),
    NORTH_AMERICA("North America (ISNA)"),
    MWL("Muslim World League"),
    EGYPT("Egyptian General Authority"),
    UMM_AL_QURA("Umm Al-Qura (Makkah)"),
    MOON_SIGHTING("Moon Sighting Committee"),
    DUBAI("Dubai"),
    KUWAIT("Kuwait"),
    QATAR("Qatar"),
    SINGAPORE("Singapore"),
}

enum class MadhabPref(val displayName: String) {
    SHAFI("Shafi / Maliki / Hanbali"),
    HANAFI("Hanafi"),
}

data class CityResult(
    val name: String,
    val displayName: String,
    val latitude: Double,
    val longitude: Double,
)

enum class DayResetOption {
    MIDNIGHT,
    MAGHRIB,
}

enum class CalendarSystem {
    GREGORIAN,
    HIJRI,
}
