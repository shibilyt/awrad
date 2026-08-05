package app.awrad.awrad_dhikrgoalstracker.service

import java.io.ByteArrayInputStream
import java.io.File
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class CustomDhikrAudioReplaceSafetyTest {

    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun commitStagedDoesNotDeletePreviousOwnedFile() {
        val store = CustomDhikrAudioStore(rootDir = temporaryFolder.root)
        val previous = store.commitStaged(
            store.stageImport(
                input = ByteArrayInputStream("old-audio".toByteArray()),
                declaredByteSize = 9L,
                mimeType = "audio/mpeg",
                durationMs = 1_000L,
                probe = AcceptingProbe,
            ),
        )
        val staged = store.stageImport(
            input = ByteArrayInputStream("new-audio-file".toByteArray()),
            declaredByteSize = 14L,
            mimeType = "audio/mpeg",
            durationMs = 1_500L,
            probe = AcceptingProbe,
        )
        val committed = store.commitStaged(staged)
        assertTrue(File(temporaryFolder.root, "owned/${previous.relativeFileName}").isFile)
        assertTrue(File(temporaryFolder.root, "owned/${committed.relativeFileName}").isFile)
        assertTrue(previous.relativeFileName != committed.relativeFileName)
    }

    @Test
    fun orphanOwnedCleanupHonorsGracePeriod() {
        val store = CustomDhikrAudioStore(rootDir = temporaryFolder.root)
        val orphanName = "${UUID.randomUUID()}.mp3"
        val orphan = File(temporaryFolder.root, "owned/$orphanName").also { it.writeText("orphan") }
        orphan.setLastModified(System.currentTimeMillis() - 1_000L)

        store.cleanupOrphans(
            referencedRelativeNames = emptySet(),
            ownedGraceMs = 60_000L,
            tempGraceMs = 0L,
            nowMs = System.currentTimeMillis(),
        )
        assertTrue(orphan.isFile)

        store.cleanupOrphans(
            referencedRelativeNames = emptySet(),
            ownedGraceMs = 0L,
            tempGraceMs = 0L,
            nowMs = System.currentTimeMillis(),
        )
        assertFalse(orphan.exists())
    }

    @Test
    fun streamingEnforcementRejectsWhenActualExceedsDeclaredPreflightPass() {
        val store = CustomDhikrAudioStore(rootDir = temporaryFolder.root)
        // Declared under limit, but stream keeps going past exclusive max.
        val oversized = ByteArray(10_000_000)
        try {
            store.stageImport(
                input = ByteArrayInputStream(oversized),
                declaredByteSize = 100L,
                mimeType = "audio/mpeg",
                durationMs = 1_000L,
                probe = AcceptingProbe,
            )
            fail("expected size rejection during streaming")
        } catch (error: CustomDhikrAudioException) {
            assertEquals(CustomDhikrAudioException.Reason.SIZE, error.reason)
        }
        assertTrue(store.listTemporaryFiles().isEmpty())
    }

    private object AcceptingProbe : CustomDhikrAudioProbe {
        override fun inspect(file: File): CustomDhikrAudioProbeResult =
            CustomDhikrAudioProbeResult(mimeType = "audio/mpeg", durationMs = 1_000L)
    }
}
