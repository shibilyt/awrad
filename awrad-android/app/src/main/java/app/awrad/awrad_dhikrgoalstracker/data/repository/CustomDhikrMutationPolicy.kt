package app.awrad.awrad_dhikrgoalstracker.data.repository

object CustomDhikrMutationPolicy {
    const val MAX_TAGS_PER_ACCOUNT = 100
    const val MAX_TAGS_PER_DHIKR = 20

    fun canPersistCustom(dhikr: app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr): Boolean =
        dhikr.isCustom && dhikr.catalogKey == null

    fun canMutateExisting(isCustom: Boolean?): Boolean = isCustom == true

    fun canCreateTag(existingTagCount: Int): Boolean =
        existingTagCount < MAX_TAGS_PER_ACCOUNT

    fun canAssignTag(existingAssignmentsOnDhikr: Int): Boolean =
        existingAssignmentsOnDhikr < MAX_TAGS_PER_DHIKR
}
