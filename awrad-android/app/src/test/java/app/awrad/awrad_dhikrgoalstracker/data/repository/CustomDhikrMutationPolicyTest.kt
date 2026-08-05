package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrAudioAsset
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.UserTag
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import app.awrad.awrad_dhikrgoalstracker.domain.UserTagNormalizer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pure policy coverage for custom dhikr mutation guards used by [DhikrRepositoryImpl].
 */
class CustomDhikrMutationPolicyTest {

    @Test
    fun createRequiresCustomFlagAndNullCatalog() {
        val valid = Dhikr(
            title = "Mine",
            arabic = "ن",
            transliteration = "n",
            translation = "n",
            audioUrl = null,
            audioFileName = null,
            category = DhikrCategory.GENERAL,
            isCustom = true,
            catalogKey = null,
        )
        assertTrue(CustomDhikrMutationPolicy.canPersistCustom(valid))
        assertFalse(CustomDhikrMutationPolicy.canPersistCustom(valid.copy(isCustom = false)))
        assertFalse(CustomDhikrMutationPolicy.canPersistCustom(valid.copy(catalogKey = "builtin")))
    }

    @Test
    fun updateAndDeleteRequireExistingCustomRow() {
        assertTrue(CustomDhikrMutationPolicy.canMutateExisting(isCustom = true))
        assertFalse(CustomDhikrMutationPolicy.canMutateExisting(isCustom = false))
        assertFalse(CustomDhikrMutationPolicy.canMutateExisting(isCustom = null))
    }

    @Test
    fun tagLimitsRejectOverCapacity() {
        assertTrue(CustomDhikrMutationPolicy.canCreateTag(existingTagCount = 99))
        assertFalse(CustomDhikrMutationPolicy.canCreateTag(existingTagCount = 100))
        assertTrue(CustomDhikrMutationPolicy.canAssignTag(existingAssignmentsOnDhikr = 19))
        assertFalse(CustomDhikrMutationPolicy.canAssignTag(existingAssignmentsOnDhikr = 20))
    }

    @Test
    fun renameUsesNormalizedUniqueness() {
        val existing = UserTag(
            id = newAwradId(),
            name = "Before Sleep",
            normalizedName = "before sleep",
        )
        val duplicate = UserTagNormalizer.normalize("  before   SLEEP ")
        assertEquals(existing.normalizedName, duplicate!!.normalizedName)
        assertNull(UserTagNormalizer.normalize("   "))
    }

    @Test
    fun audioAssetKeepsRelativeNameOnly() {
        val asset = DhikrAudioAsset(
            dhikrId = newAwradId(),
            relativeFileName = "abc.m4a",
            mimeType = "audio/mp4",
            byteSize = 100,
            durationMs = 1000,
            sha256 = "deadbeef",
        )
        assertFalse(asset.relativeFileName.contains('/'))
        assertEquals("import", asset.source)
    }
}
