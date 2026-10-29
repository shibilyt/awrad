package app.awrad.core.data.audio

import androidx.core.net.toUri
import app.awrad.core.data.sync.FakeSyncServer.Companion.CUSTOM
import app.awrad.core.data.sync.SyncStack
import app.awrad.core.data.sync.SyncStack.Companion.dhikr
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.AudioContentType
import app.awrad.core.domain.personal.AudioStorage
import app.awrad.core.domain.personal.AudioUsage
import app.awrad.core.domain.personal.CustomAudio
import app.awrad.core.domain.personal.CustomDhikrJson
import app.awrad.core.domain.personal.RecordingDownloadError
import app.awrad.core.domain.personal.RecordingPlayback
import app.awrad.core.domain.personal.UploadedAudio
import app.awrad.core.network.api.ApiFailure
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

/**
 * Playing a recording uploaded from another device: downloaded once into the profile's files on its first play,
 * played from there afterwards (offline too), and removed with the dhikr's recording. And storage used.
 */
@RunWith(RobolectricTestRunner::class)
class RecordingCacheTest {

    private val dhikrId = AwradId("0192f0d0-0000-7000-8000-000000000001")
    private val firstAsset = AwradId("0192f0e0-0000-7000-8000-000000000001")
    private val secondAsset = AwradId("0192f0e0-0000-7000-8000-000000000002")

    @Test
    fun `the first play downloads the recording into the profile, and later plays use it offline`() = runTest {
        val stack = stackWithRecordingFromElsewhere()

        val first = assertIs<RecordingPlayback.Ready>(stack.audio.playable(dhikrId))

        val file = File(checkNotNull(first.localUri.toUri().path))
        assertEquals(File(stack.databases.current().filesDir, "audio/${firstAsset.value}.mp3"), file)
        assertTrue(file.readBytes().contentEquals(BYTES))
        assertEquals(listOf("download ${firstAsset.value}"), stack.audioServer.calls)
        assertEquals(first.localUri, stack.dhikrs.dhikr(dhikrId).first()?.audio?.localUri)

        stack.objects.offline = true
        assertEquals(first, stack.audio.playable(dhikrId))
        assertEquals(1, stack.objects.gets.size)
        assertEquals(1, stack.audioServer.calls.size)
    }

    @Test
    fun `the cached file goes when the dhikr's recording changes, and when the dhikr is deleted`() = runTest {
        val stack = stackWithRecordingFromElsewhere()
        val first = stack.playedFile()

        stack.recordElsewhere(secondAsset)
        stack.engine.syncOnce()

        assertTrue(!first.exists())
        assertEquals(null, stack.dhikrs.dhikr(dhikrId).first()?.audio?.localUri)
        val second = stack.playedFile()
        assertTrue(second.isFile)

        stack.dhikrs.delete(dhikrId)

        assertTrue(!second.exists())
    }

    @Test
    fun `removing the recording in the editor deletes the cached file`() = runTest {
        val stack = stackWithRecordingFromElsewhere()
        val cached = stack.playedFile()

        val dhikr = checkNotNull(stack.dhikrs.dhikr(dhikrId).first())
        stack.dhikrs.save(dhikr.copy(audio = null))

        assertTrue(!cached.exists())
    }

    @Test
    fun `a download that can't happen says why`() = runTest {
        val offline = stackWithRecordingFromElsewhere()
        offline.audioServer.downloadFailures += ApiFailure.NoConnection
        assertEquals(RecordingPlayback.Failed(RecordingDownloadError.OFFLINE), offline.audio.playable(dhikrId))
        offline.objects.offline = true
        assertEquals(RecordingPlayback.Failed(RecordingDownloadError.OFFLINE), offline.audio.playable(dhikrId))

        val cleanedUp = stackWithRecordingFromElsewhere()
        cleanedUp.audioServer.cleanUp(firstAsset.value)
        assertEquals(RecordingPlayback.Failed(RecordingDownloadError.NOT_FOUND), cleanedUp.audio.playable(dhikrId))

        val signedOut = stackWithRecordingFromElsewhere()
        signedOut.accounts.signOut()
        assertEquals(RecordingPlayback.Failed(RecordingDownloadError.NOT_SIGNED_IN), signedOut.audio.playable(dhikrId))
        assertEquals(
            RecordingPlayback.Failed(RecordingDownloadError.NOT_FOUND),
            signedOut.audio.playable(AwradId("0192f0d0-0000-7000-8000-0000000000ff")),
        )
    }

    @Test
    fun `a recording on this phone plays from its file without asking the server`() = runTest {
        val stack = SyncStack(this)
        val folder = File(stack.databases.current().filesDir, "audio").apply { mkdirs() }
        val file = File(folder, "local.mp3").apply { writeBytes(BYTES) }
        stack.dhikrs.save(dhikr(dhikrId).copy(audio = CustomAudio(file.toUri().toString())))

        assertEquals(RecordingPlayback.Ready(file.toUri().toString()), stack.audio.playable(dhikrId))
        assertTrue(stack.audioServer.calls.isEmpty())
    }

    @Test
    fun `storage used is the account's, and only asked while signed in as the profile's account`() = runTest {
        val stack = stackWithRecordingFromElsewhere()

        assertEquals(
            AudioUsage.Known(AudioStorage(BYTES.size.toLong(), 500_000_000)),
            stack.audio.usage(),
        )

        stack.accounts.signOut()
        assertEquals(AudioUsage.NotSignedIn, stack.audio.usage())
        assertEquals(listOf("usage"), stack.audioServer.calls)
    }

    /** Signed in as the profile's account, with a dhikr whose recording was uploaded from another device. */
    private suspend fun TestScope.stackWithRecordingFromElsewhere(): SyncStack {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        stack.recordElsewhere(firstAsset)
        stack.engine.syncOnce()
        return stack
    }

    /** Plays the dhikr's recording; the file it played from. */
    private suspend fun SyncStack.playedFile(): File =
        File(checkNotNull(assertIs<RecordingPlayback.Ready>(audio.playable(dhikrId)).localUri.toUri().path))

    private fun SyncStack.recordElsewhere(asset: AwradId) {
        objects.objects[asset.value] = FakeObjectStore.Stored(BYTES, mapOf("content-type" to "audio/mpeg"))
        audioServer.ready[asset.value] = BYTES.size.toLong() to "audio/mpeg"
        val uploaded = UploadedAudio(asset, BYTES.size.toLong(), AudioContentType.MPEG, durationMs = null)
        val document = CustomDhikrJson.encode(dhikr(dhikrId).copy(audio = CustomAudio(null, uploaded)))
        server.putFromElsewhere(CUSTOM, dhikrId, document)
    }

    private companion object {
        val BYTES = ByteArray(1_500) { (it % 127).toByte() }
    }
}
