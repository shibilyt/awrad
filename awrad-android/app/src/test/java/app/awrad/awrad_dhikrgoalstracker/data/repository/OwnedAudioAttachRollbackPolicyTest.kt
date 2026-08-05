package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.service.CustomDhikrAudioProbe
import app.awrad.awrad_dhikrgoalstracker.service.CustomDhikrAudioProbeResult
import app.awrad.awrad_dhikrgoalstracker.service.CustomDhikrAudioStore
import app.awrad.awrad_dhikrgoalstracker.service.StagedOwnedAudio
import java.io.ByteArrayInputStream
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/**
 * Pure-logic coverage for owned-audio attach rollback ordering without Room.
 */
class OwnedAudioAttachRollbackPolicyTest {

    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun rollbackDeletesOnlyNewFileAndKeepsPreviousReference() {
        val store = CustomDhikrAudioStore(rootDir = temporaryFolder.root)
        val previous = store.commitStaged(stage(store, "keep-me"))
        val staged = stage(store, "new-bytes")
        val promoted = store.commitStaged(staged)

        val recovered = OwnedAudioAttachRollbackPolicy.onDaoFailure(
            store = store,
            previous = previous,
            promoted = promoted,
        )
        assertEquals(previous.relativeFileName, recovered.retainedRelativeFileName)
        assertTrue(File(temporaryFolder.root, "owned/${previous.relativeFileName}").isFile)
        assertFalse(File(temporaryFolder.root, "owned/${promoted.relativeFileName}").exists())
    }

    @Test
    fun successDeletesPreviousOnlyAfterCommitMarker() {
        val store = CustomDhikrAudioStore(rootDir = temporaryFolder.root)
        val previous = store.commitStaged(stage(store, "old"))
        val promoted = store.commitStaged(stage(store, "new"))
        OwnedAudioAttachRollbackPolicy.onDaoSuccess(
            store = store,
            previous = previous,
            promoted = promoted,
        )
        assertFalse(File(temporaryFolder.root, "owned/${previous.relativeFileName}").exists())
        assertTrue(File(temporaryFolder.root, "owned/${promoted.relativeFileName}").isFile)
    }

    @Test
    fun rejectsAttachForBuiltInDhikr() {
        try {
            OwnedAudioAttachRollbackPolicy.requireCustomDhikr(isCustom = false)
            fail("expected guard")
        } catch (error: IllegalArgumentException) {
            assertTrue(error.message!!.contains("custom"))
        }
        OwnedAudioAttachRollbackPolicy.requireCustomDhikr(isCustom = true)
    }

    private fun stage(store: CustomDhikrAudioStore, bytes: String): StagedOwnedAudio =
        store.stageImport(
            input = ByteArrayInputStream(bytes.toByteArray()),
            declaredByteSize = bytes.length.toLong(),
            mimeType = "audio/mpeg",
            durationMs = 500L,
            probe = object : CustomDhikrAudioProbe {
                override fun inspect(file: File) =
                    CustomDhikrAudioProbeResult(mimeType = "audio/mpeg", durationMs = 500L)
            },
        )
}
