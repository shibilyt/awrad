package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model

import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CapBehavior
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.PrayerTiming

data class PrayerSlotTargetKey(
    val prayer: Prayer,
    val relation: PrayerRelation,
)

sealed class TargetDraft {
    data object None : TargetDraft()
    data class Fixed(val count: String = "33") : TargetDraft()
    data class PrayerBased(
        val timing: PrayerTiming = PrayerTiming.AFTER,
        val selectedPrayers: Set<Prayer> = Prayer.entries.toSet(),
        val uniform: Boolean = true,
        val uniformCount: String = "33",
        val perPrayerCounts: Map<Prayer, String> = emptyMap(),
        val perPrayerRelationCounts: Map<PrayerSlotTargetKey, String> = emptyMap(),
        val perPrayerMinimumCounts: Map<Prayer, String> = emptyMap(),
        val perPrayerRelationMinimumCounts: Map<PrayerSlotTargetKey, String> = emptyMap(),
        val perPrayerMaximumCounts: Map<Prayer, String> = emptyMap(),
        val perPrayerRelationMaximumCounts: Map<PrayerSlotTargetKey, String> = emptyMap(),
        val perPrayerCapBehaviors: Map<Prayer, CapBehavior> = emptyMap(),
        val perPrayerRelationCapBehaviors: Map<PrayerSlotTargetKey, CapBehavior> = emptyMap(),
        val beforePrayerLeadOverrides: Map<Prayer, String> = emptyMap(),
    ) : TargetDraft() {
        fun countFor(prayer: Prayer): String = perPrayerCounts[prayer] ?: uniformCount

        fun countFor(prayer: Prayer, relation: PrayerRelation): String =
            perPrayerRelationCounts[PrayerSlotTargetKey(prayer, relation)]
                ?: perPrayerCounts[prayer]
                ?: uniformCount

        fun minimumFor(prayer: Prayer, fallback: String): String =
            perPrayerMinimumCounts[prayer] ?: fallback

        fun minimumFor(prayer: Prayer, relation: PrayerRelation, fallback: String): String =
            perPrayerRelationMinimumCounts[PrayerSlotTargetKey(prayer, relation)]
                ?: perPrayerMinimumCounts[prayer]
                ?: fallback

        fun maximumFor(prayer: Prayer, fallback: String): String =
            perPrayerMaximumCounts[prayer] ?: fallback

        fun maximumFor(prayer: Prayer, relation: PrayerRelation, fallback: String): String =
            perPrayerRelationMaximumCounts[PrayerSlotTargetKey(prayer, relation)]
                ?: perPrayerMaximumCounts[prayer]
                ?: fallback

        fun capBehaviorFor(prayer: Prayer, relation: PrayerRelation, fallback: CapBehavior): CapBehavior =
            perPrayerRelationCapBehaviors[PrayerSlotTargetKey(prayer, relation)]
                ?: perPrayerCapBehaviors[prayer]
                ?: fallback

        fun withCountFor(prayer: Prayer, count: String): PrayerBased =
            copy(
                uniform = false,
                perPrayerCounts = perPrayerCounts + (prayer to count),
            )

        fun withCountFor(prayer: Prayer, relation: PrayerRelation, count: String): PrayerBased =
            copy(
                uniform = false,
                perPrayerRelationCounts = perPrayerRelationCounts + (PrayerSlotTargetKey(prayer, relation) to count),
            )

        fun withMinimumFor(prayer: Prayer, relation: PrayerRelation, count: String): PrayerBased =
            copy(
                uniform = false,
                perPrayerRelationMinimumCounts = perPrayerRelationMinimumCounts + (PrayerSlotTargetKey(prayer, relation) to count),
            )

        fun withMaximumFor(prayer: Prayer, relation: PrayerRelation, count: String): PrayerBased =
            copy(
                uniform = false,
                perPrayerRelationMaximumCounts = perPrayerRelationMaximumCounts + (PrayerSlotTargetKey(prayer, relation) to count),
            )

        fun withCapBehaviorFor(prayer: Prayer, relation: PrayerRelation, behavior: CapBehavior): PrayerBased =
            copy(
                uniform = false,
                perPrayerRelationCapBehaviors = perPrayerRelationCapBehaviors + (PrayerSlotTargetKey(prayer, relation) to behavior),
            )
    }
}
