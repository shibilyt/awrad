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

class CustomDhikrAudioStoreTest {

    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun stageRejectsExactlyTenMillionBytes() {
        val store = CustomDhikrAudioStore(rootDir = temporaryFolder.root)
        val bytes = ByteArray(10_000_000)
        try {
            store.stageImport(
                input = ByteArrayInputStream(bytes),
                declaredByteSize = bytes.size.toLong(),
                mimeType = "audio/mpeg",
                durationMs = 1_000L,
                probe = AcceptingProbe,
            )
            fail("expected size rejection")
        } catch (error: CustomDhikrAudioException) {
            assertEquals(CustomDhikrAudioException.Reason.SIZE, error.reason)
        }
        assertTrue(store.listTemporaryFiles().isEmpty())
    }

    @Test
    fun stageRejectsUnsupportedMimeAndCleansTemp() {
        val store = CustomDhikrAudioStore(rootDir = temporaryFolder.root)
        try {
            store.stageImport(
                input = ByteArrayInputStream(ByteArray(128)),
                declaredByteSize = 128L,
                mimeType = "audio/ogg",
                durationMs = 1_000L,
                probe = AcceptingProbe,
            )
            fail("expected mime rejection")
        } catch (error: CustomDhikrAudioException) {
            assertEquals(CustomDhikrAudioException.Reason.MIME, error.reason)
        }
        assertTrue(store.listTemporaryFiles().isEmpty())
    }

    @Test
    fun commitReplaceKeepsPreviousUntilCallerDeletes() {
        val store = CustomDhikrAudioStore(rootDir = temporaryFolder.root)
        val first = store.stageImport(
            input = ByteArrayInputStream("old-audio".toByteArray()),
            declaredByteSize = 9L,
            mimeType = "audio/mpeg",
            durationMs = 1_000L,
            probe = AcceptingProbe,
        )
        val firstOwned = store.commitStaged(first)
        assertTrue(File(temporaryFolder.root, "owned/${firstOwned.relativeFileName}").isFile)

        val second = store.stageImport(
            input = ByteArrayInputStream("new-audio-file".toByteArray()),
            declaredByteSize = 14L,
            mimeType = "audio/mpeg",
            durationMs = 1_500L,
            probe = AcceptingProbe,
        )
        val secondOwned = store.commitStaged(second)
        assertTrue(File(temporaryFolder.root, "owned/${firstOwned.relativeFileName}").isFile)
        assertTrue(File(temporaryFolder.root, "owned/${secondOwned.relativeFileName}").isFile)
        store.deleteOwned(firstOwned.relativeFileName)
        assertFalse(File(temporaryFolder.root, "owned/${firstOwned.relativeFileName}").exists())
        assertTrue(File(temporaryFolder.root, "owned/${secondOwned.relativeFileName}").isFile)
    }

    @Test
    fun rollbackStagedLeavesPreviousOwnedIntact() {
        val store = CustomDhikrAudioStore(rootDir = temporaryFolder.root)
        val first = store.commitStaged(
            store.stageImport(
                input = ByteArrayInputStream("keep-me".toByteArray()),
                declaredByteSize = 7L,
                mimeType = "audio/wav",
                durationMs = 800L,
                probe = AcceptingProbe,
            ),
        )
        val staged = store.stageImport(
            input = ByteArrayInputStream("discard".toByteArray()),
            declaredByteSize = 7L,
            mimeType = "audio/wav",
            durationMs = 800L,
            probe = AcceptingProbe,
        )
        store.discardStaged(staged)
        assertTrue(File(temporaryFolder.root, "owned/${first.relativeFileName}").isFile)
        assertTrue(store.listTemporaryFiles().isEmpty())
    }

    @Test
    fun orphanCleanupRemovesUnreferencedOwnedAndStaleTemp() {
        val store = CustomDhikrAudioStore(rootDir = temporaryFolder.root)
        val kept = store.commitStaged(
            store.stageImport(
                input = ByteArrayInputStream("keep".toByteArray()),
                declaredByteSize = 4L,
                mimeType = "audio/mpeg",
                durationMs = 500L,
                probe = AcceptingProbe,
            ),
        )
        val orphanName = "${UUID.randomUUID()}.bin"
        File(temporaryFolder.root, "owned/$orphanName").writeText("orphan")
        File(temporaryFolder.root, "tmp/stale.bin").writeText("temp")

        store.cleanupOrphans(
            referencedRelativeNames = setOf(kept.relativeFileName),
            ownedGraceMs = 0L,
            tempGraceMs = 0L,
            nowMs = System.currentTimeMillis(),
        )

        assertTrue(File(temporaryFolder.root, "owned/${kept.relativeFileName}").isFile)
        assertFalse(File(temporaryFolder.root, "owned/$orphanName").exists())
        assertFalse(File(temporaryFolder.root, "tmp/stale.bin").exists())
    }

    @Test
    fun resolveReportsMissingWhenOwnedFileAbsent() {
        val store = CustomDhikrAudioStore(rootDir = temporaryFolder.root)
        val relative = "${UUID.randomUUID()}.m4a"
        val status = store.resolveAvailability(relative)
        assertEquals(OwnedAudioAvailability.MISSING, status)
    }

    private object AcceptingProbe : CustomDhikrAudioProbe {
        override fun inspect(file: File): CustomDhikrAudioProbeResult =
            CustomDhikrAudioProbeResult(
                mimeType = "audio/mpeg",
                durationMs = 1_000L,
            )
    }
}
