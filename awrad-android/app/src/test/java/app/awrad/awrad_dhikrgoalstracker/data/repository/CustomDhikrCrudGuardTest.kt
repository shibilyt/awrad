package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CustomDhikrCrudGuardTest {

    @Test
    fun builtInRecordsCannotBeMutatedOrDeleted() {
        assertFalse(CustomDhikrMutationPolicy.canMutateExisting(isCustom = false))
        assertTrue(CustomDhikrMutationPolicy.canMutateExisting(isCustom = true))
    }

    @Test
    fun tagAssignmentLimitsMatchContract() {
        assertTrue(CustomDhikrMutationPolicy.canAssignTag(19))
        assertFalse(CustomDhikrMutationPolicy.canAssignTag(20))
        assertTrue(CustomDhikrMutationPolicy.canCreateTag(99))
        assertFalse(CustomDhikrMutationPolicy.canCreateTag(100))
    }

    @Test
    fun ownedAudioAttachRequiresCustomFlag() {
        var rejected = false
        try {
            OwnedAudioAttachRollbackPolicy.requireCustomDhikr(isCustom = false)
        } catch (_: IllegalArgumentException) {
            rejected = true
        }
        assertTrue(rejected)
        OwnedAudioAttachRollbackPolicy.requireCustomDhikr(isCustom = true)
        // keep id generation stable for callers
        assertTrue(newAwradId().toString().isNotBlank())
    }
}
