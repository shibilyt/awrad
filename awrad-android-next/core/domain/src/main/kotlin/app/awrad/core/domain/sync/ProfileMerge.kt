package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.UserTag

/** A dhikr's personal record as the merge sees it: its tags, in the user's order. */
public data class PersonalRecord(val dhikrId: AwradId, val tagIds: List<AwradId>)

/** The tags and personal records of one profile, in their stored order. */
public data class ProfileData(val tags: List<UserTag>, val personalRecords: List<PersonalRecord>)

/**
 * The account profile's tags and personal records after a merge, and what to queue as puts: [queued] lists the
 * new tags, then the personal records that are new or changed, each in their listed order.
 */
public data class MergedData(
    val tags: List<UserTag>,
    val personalRecords: List<PersonalRecord>,
    val queued: List<EntityKey>,
)

/**
 * "Add to my account" when the account already has a profile on the phone (fixture `profile_switch`,
 * `merged_data`; contracts/sync/v1/README.md, "Local profiles"). Custom dhikrs are new to the account's profile,
 * so they're copied and queued as they are; this settles the tags and personal records.
 */
public object ProfileMerge {

    /**
     * Merges [anonymous] into [account]:
     * - a tag whose `normalized_name` the account has folds onto the account's tag and isn't queued; any other
     *   tag is added after the account's and queued;
     * - a personal record both have gets the account's tags first, in their order, then the anonymous-only ones,
     *   without repeats after folding and capped at [UserTag.PER_DHIKR] (the account's always kept); it's queued
     *   when that changed it;
     * - a record only the anonymous profile has is added after the account's, its tags folded, and queued.
     */
    public fun merge(anonymous: ProfileData, account: ProfileData): MergedData {
        val byName = account.tags.associateBy { it.normalizedName }
        val newTags = anonymous.tags.filter { it.normalizedName !in byName }
        val folded = anonymous.tags.associate { tag -> tag.id to (byName[tag.normalizedName]?.id ?: tag.id) }
        fun fold(tagIds: List<AwradId>) = tagIds.map { folded[it] ?: it }

        val anonymousRecords = anonymous.personalRecords.associateBy { it.dhikrId }
        val changed = mutableListOf<PersonalRecord>()
        val accountRecords = account.personalRecords.map { record ->
            val extra = anonymousRecords[record.dhikrId] ?: return@map record
            val merged = record.copy(tagIds = (record.tagIds + fold(extra.tagIds)).distinct().take(UserTag.PER_DHIKR))
            merged.also { if (it != record) changed += it }
        }
        val accountDhikrs = account.personalRecords.mapTo(HashSet()) { it.dhikrId }
        val added = anonymous.personalRecords
            .filter { it.dhikrId !in accountDhikrs }
            .map { it.copy(tagIds = fold(it.tagIds).distinct().take(UserTag.PER_DHIKR)) }
        val records = accountRecords + added
        val queuedRecords = records.filter { it in changed || it in added }
        return MergedData(
            tags = account.tags + newTags,
            personalRecords = records,
            queued = newTags.map { EntityKey(EntityType.USER_TAG, it.id) } +
                queuedRecords.map { personalKeyOf(it.dhikrId) },
        )
    }
}
