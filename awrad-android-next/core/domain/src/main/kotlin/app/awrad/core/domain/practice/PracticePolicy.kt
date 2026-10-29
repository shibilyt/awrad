package app.awrad.core.domain.practice

import app.awrad.core.domain.hijri.HijriCorrections
import java.time.DayOfWeek

/*
 * The account practice policy (CONTEXT.md, "Account practice policy"; contracts/practice-settings/v1). Each enum's
 * [wire] is its value in the `practice_policy` document.
 */

/** The account practice policy's day-end rule (CONTEXT.md, "Effective practice day"). */
public enum class DayReset(public val wire: String) {
    MIDNIGHT("midnight"),
    MAGHRIB("maghrib"),
    ;

    public companion object {
        public fun fromWire(wire: String): DayReset? = entries.firstOrNull { it.wire == wire }
    }
}

/** The account practice policy's first day of the week. Every week-based rule takes it as an input. */
public enum class WeekStart(public val firstDay: DayOfWeek, public val wire: String) {
    SATURDAY(DayOfWeek.SATURDAY, "saturday"),
    SUNDAY(DayOfWeek.SUNDAY, "sunday"),
    MONDAY(DayOfWeek.MONDAY, "monday"),
    ;

    public companion object {
        public val DEFAULT: WeekStart = MONDAY

        public fun fromWire(wire: String): WeekStart? = entries.firstOrNull { it.wire == wire }
    }
}

/**
 * The prayer-time calculation method, by the adhan library's names for the frozen apps' ten. Only [DUBAI] and
 * [MOONSIGHTING_COMMITTEE] move Maghrib (3 minutes after sunset).
 */
public enum class CalculationMethod(public val wire: String) {
    KARACHI("karachi"),
    NORTH_AMERICA("north_america"),
    MUSLIM_WORLD_LEAGUE("muslim_world_league"),
    EGYPTIAN("egyptian"),
    UMM_AL_QURA("umm_al_qura"),
    MOONSIGHTING_COMMITTEE("moonsighting_committee"),
    DUBAI("dubai"),
    KUWAIT("kuwait"),
    QATAR("qatar"),
    SINGAPORE("singapore"),
    ;

    public companion object {
        public fun fromWire(wire: String): CalculationMethod? = entries.firstOrNull { it.wire == wire }
    }
}

/** The Asr shadow rule: [SHAFI] (Shafi'i, Maliki, Hanbali: shadow length 1) or [HANAFI] (2). Only Asr uses it. */
public enum class Madhab(public val wire: String) {
    SHAFI("shafi"),
    HANAFI("hanafi"),
    ;

    public companion object {
        public fun fromWire(wire: String): Madhab? = entries.firstOrNull { it.wire == wire }
    }
}

/**
 * One account practice policy: a valid `practice_policy` document ([PracticePolicyJson]). Each local profile has
 * one, including the anonymous profile; a new one starts as [DEFAULT].
 */
public data class PracticePolicy(
    val dayReset: DayReset,
    val calculationMethod: CalculationMethod,
    val madhab: Madhab,
    val weekStart: WeekStart,
    val hijriCorrections: HijriCorrections,
) {
    public companion object {
        /** The frozen apps' defaults (`$defs/default_policy`): midnight, Karachi, Shafi'i, Monday, no corrections. */
        public val DEFAULT: PracticePolicy = PracticePolicy(
            dayReset = DayReset.MIDNIGHT,
            calculationMethod = CalculationMethod.KARACHI,
            madhab = Madhab.SHAFI,
            weekStart = WeekStart.DEFAULT,
            hijriCorrections = HijriCorrections.NONE,
        )
    }
}
