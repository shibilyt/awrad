package app.awrad.core.data.audio

import androidx.core.net.toUri
import app.awrad.core.data.profile.ProfileTransfers
import app.awrad.core.data.sync.FakeSyncServer.Companion.CUSTOM
import app.awrad.core.data.sync.SyncOutcome
import app.awrad.core.data.sync.SyncStack
import app.awrad.core.data.sync.SyncStack.Companion.DURATION_MS
import app.awrad.core.data.sync.SyncStack.Companion.dhikr
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.AudioContentType
import app.awrad.core.domain.personal.AudioStorage
import app.awrad.core.domain.personal.AudioUploadNotice
import app.awrad.core.domain.personal.AudioUploadProblem
import app.awrad.core.domain.personal.CustomAudio
import app.awrad.core.domain.personal.CustomAudioJson
import app.awrad.core.domain.personal.RecordingPlayback
import app.awrad.core.domain.personal.RecordingUpload
import app.awrad.core.domain.personal.UploadedAudio
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.RejectionCode
import app.awrad.core.domain.sync.SyncNotice
import app.awrad.core.network.api.ApiFailure
import app.awrad.core.network.api.Problem
import app.awrad.core.network.http.TransferResult
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File
import java.security.MessageDigest
import java.util.Base64
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The upload worker (a step of each sync run) against a fake audio server and fake object storage, through the real
 * Room profile: success and the put it queues, every error the brief names, retries, and where uploads come from.
 */
@RunWith(RobolectricTestRunner::class)
class AudioUploaderTest {

    private val dhikrId = AwradId("0192f0d0-0000-7000-8000-000000000001")
    private val key = EntityKey(EntityType.CUSTOM_DHIKR, dhikrId)
    private val bytes = ByteArray(BYTES) { (it % 251).toByte() }

    @Test
    fun `a recording saved while signed in uploads, and its put names the asset in the same run`() = runTest {
        val stack = signedInStack()
        val file = stack.saveWithRecording()
        assertEquals(RecordingUpload.QUEUED, stack.audio.upload(dhikrId).first())

        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        val asset = stack.audioServer.ready.keys.single()
        assertEquals(listOf("create $asset", "complete $asset"), stack.audioServer.calls)
        val sha = MessageDigest.getInstance("SHA-256").digest(bytes)
        assertEquals(
            mapOf("content-type" to "audio/mpeg", "x-amz-checksum-sha256" to Base64.getEncoder().encodeToString(sha)),
            stack.objects.puts.single().second,
        )
        val expected = UploadedAudio(AwradId(asset), BYTES.toLong(), AudioContentType.MPEG, DURATION_MS)
        assertEquals(expected, CustomAudioJson.uploaded(stack.localDocument()["audio"]))
        assertEquals(expected, CustomAudioJson.uploaded(stack.server.document()["audio"]))
        assertTrue(stack.outbox().isEmpty())
        assertEquals(RecordingUpload.NONE, stack.audio.upload(dhikrId).first())
        // The file stays the dhikr's recording, so it plays without a download.
        assertEquals(RecordingPlayback.Ready(file.toUri().toString()), stack.audio.playable(dhikrId))
        assertTrue(stack.objects.gets.isEmpty())
    }

    @Test
    fun `the server's 413, 415 and invalid_size keep the recording local with a notice, and the dhikr still syncs`() {
        val answers = mapOf(
            AudioUploadProblem.FILE_TOO_LARGE to problem(413, "file_too_large"),
            AudioUploadProblem.UNSUPPORTED_TYPE to problem(415, "unsupported_audio_type"),
            AudioUploadProblem.INVALID_SIZE to problem(422, "invalid_size"),
        )
        answers.forEach { (expected, answer) ->
            runTest {
                val stack = signedInStack()
                stack.saveWithRecording()
                stack.audioServer.createFailures += answer

                assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

                assertEquals(listOf(AudioUploadNotice(dhikrId, expected)), stack.audio.uploadNotices.first())
                assertEquals(RecordingUpload.FAILED, stack.audio.upload(dhikrId).first())
                assertTrue(stack.objects.puts.isEmpty())
                assertEquals(CustomAudioJson.LOCAL_ONLY, stack.localDocument()["audio"])
                val synced = stack.server.entities.getValue(CUSTOM to dhikrId.value).document!!
                assertEquals(CustomAudioJson.LOCAL_ONLY, synced["audio"])
            }
        }
    }

    @Test
    fun `files the rules refuse aren't sent at all`() = runTest {
        val empty = signedInStack()
        empty.saveWithRecording(content = ByteArray(0))
        val raw = signedInStack()
        raw.saveWithRecording(name = "raw.aac")

        empty.engine.syncOnce()
        raw.engine.syncOnce()

        assertEquals(AudioUploadProblem.INVALID_SIZE, empty.audio.uploadNotices.first().single().problem)
        assertEquals(AudioUploadProblem.UNSUPPORTED_TYPE, raw.audio.uploadNotices.first().single().problem)
        assertTrue(empty.audioServer.calls.isEmpty() && raw.audioServer.calls.isEmpty())
    }

    @Test
    fun `storage_full keeps it local, with the account's use and limit, until dismissed`() = runTest {
        val stack = signedInStack()
        stack.audioServer.otherUsedBytes = USED_NEARLY_ALL
        stack.saveWithRecording()

        stack.engine.syncOnce()

        val notice = stack.audio.uploadNotices.first().single()
        assertEquals(AudioUploadProblem.STORAGE_FULL, notice.problem)
        assertEquals(AudioStorage(USED_NEARLY_ALL, 500_000_000), notice.storage)
        stack.audio.dismissUploadNotice(notice)
        assertTrue(stack.audio.uploadNotices.first().isEmpty())
        assertEquals(RecordingUpload.NONE, stack.audio.upload(dhikrId).first())
    }

    @Test
    fun `a storage_full failure uploads on a later sync once the usage shows room for it`() = runTest {
        val stack = signedInStack()
        stack.audioServer.otherUsedBytes = USED_NEARLY_ALL
        stack.saveWithRecording()
        stack.engine.syncOnce()
        assertEquals(RecordingUpload.FAILED, stack.audio.upload(dhikrId).first())

        // Still full: the usage is read, and nothing is reserved.
        stack.audioServer.calls.clear()
        stack.engine.syncOnce()
        assertEquals(listOf("usage"), stack.audioServer.calls)
        assertEquals(AudioUploadProblem.STORAGE_FULL, stack.audio.uploadNotices.first().single().problem)

        // Exactly enough room: it goes, in the same run.
        stack.audioServer.otherUsedBytes = 500_000_000L - BYTES
        stack.audioServer.calls.clear()
        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        val asset = stack.audioServer.ready.keys.single()
        assertEquals(listOf("usage", "create $asset", "complete $asset"), stack.audioServer.calls)
        assertTrue(stack.audio.uploadNotices.first().isEmpty())
        assertEquals(asset, CustomAudioJson.uploaded(stack.server.document()["audio"])?.assetId?.value)
    }

    @Test
    fun `without a storage_full failure the usage isn't read`() = runTest {
        val stack = signedInStack()
        stack.saveWithRecording()
        stack.audioServer.createFailures += problem(413, "file_too_large")

        stack.engine.syncOnce()
        stack.engine.syncOnce()

        assertTrue("usage" !in stack.audioServer.calls)
        assertEquals(AudioUploadProblem.FILE_TOO_LARGE, stack.audio.uploadNotices.first().single().problem)
    }

    @Test
    fun `replacing or removing a recording clears its storage_full failure`() = runTest {
        val stack = signedInStack()
        stack.audioServer.otherUsedBytes = USED_NEARLY_ALL
        stack.saveWithRecording()
        stack.engine.syncOnce()
        assertEquals(RecordingUpload.FAILED, stack.audio.upload(dhikrId).first())

        stack.saveWithRecording(name = "replacement.m4a")
        assertTrue(stack.audio.uploadNotices.first().isEmpty())
        assertEquals(RecordingUpload.QUEUED, stack.audio.upload(dhikrId).first())

        stack.engine.syncOnce()
        assertEquals(RecordingUpload.FAILED, stack.audio.upload(dhikrId).first())
        val saved = checkNotNull(stack.dhikrs.dhikr(dhikrId).first())
        stack.dhikrs.save(saved.copy(audio = null))
        assertTrue(stack.audio.uploadNotices.first().isEmpty())
        assertEquals(RecordingUpload.NONE, stack.audio.upload(dhikrId).first())
    }

    @Test
    fun `upload_incomplete PUTs again and confirms`() = runTest {
        val stack = signedInStack()
        stack.saveWithRecording()
        stack.objects.dropPuts = 1

        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        val asset = stack.audioServer.ready.keys.single()
        assertEquals(
            listOf("create $asset", "complete $asset", "create $asset", "complete $asset"),
            stack.audioServer.calls,
        )
        assertEquals(2, stack.objects.puts.size)
        assertEquals(asset, CustomAudioJson.uploaded(stack.localDocument()["audio"])?.assetId?.value)
    }

    @Test
    fun `upload_mismatch starts over under a new asset ID`() = runTest {
        val stack = signedInStack()
        stack.saveWithRecording()
        stack.objects.corruptPuts = 1

        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        val (first, second) = stack.audioServer.calls.filter { it.startsWith("create") }.map { it.substringAfter(' ') }
        assertTrue(first != second)
        assertEquals(setOf(second), stack.audioServer.ready.keys)
        assertEquals(second, CustomAudioJson.uploaded(stack.localDocument()["audio"])?.assetId?.value)
    }

    @Test
    fun `a second mismatch in a row keeps the recording local with a notice, after one retry`() = runTest {
        val stack = signedInStack()
        stack.saveWithRecording()
        stack.objects.corruptPuts = 2

        stack.engine.syncOnce()

        assertEquals(AudioUploadProblem.UPLOAD_MISMATCH, stack.audio.uploadNotices.first().single().problem)
        assertTrue(stack.audioServer.ready.isEmpty())
        val creates = stack.audioServer.calls.filter { it.startsWith("create") }.map { it.substringAfter(' ') }
        assertEquals(2, creates.toSet().size)

        // It stays local: later runs don't try it again.
        stack.audioServer.calls.clear()
        stack.engine.syncOnce()
        assertTrue(stack.audioServer.calls.isEmpty())
    }

    @Test
    fun `a dropped connection keeps the upload for the next run, under the same asset ID`() = runTest {
        val stack = signedInStack()
        stack.saveWithRecording()
        stack.objects.putResults += TransferResult.NoConnection

        assertEquals(SyncOutcome.Failed(null), stack.engine.syncOnce())
        // The text synced anyway, with the recording still local.
        assertEquals(
            CustomAudioJson.LOCAL_ONLY,
            stack.server.entities.getValue(CUSTOM to dhikrId.value).document!!["audio"],
        )
        assertEquals(RecordingUpload.QUEUED, stack.audio.upload(dhikrId).first())

        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        val asset = stack.audioServer.ready.keys.single()
        assertEquals(listOf("create $asset", "create $asset", "complete $asset"), stack.audioServer.calls)
        val synced = stack.server.entities.getValue(CUSTOM to dhikrId.value).document!!
        assertEquals(asset, CustomAudioJson.uploaded(synced["audio"])?.assetId?.value)
    }

    @Test
    fun `server faults stop the uploads for a retry, and an expired link waits for the next run`() = runTest {
        val stack = signedInStack()
        stack.saveWithRecording()
        stack.audioServer.createFailures += ApiFailure.ProblemResponse(Problem(status = 503, code = "unavailable"), 30)

        assertEquals(SyncOutcome.Failed(java.time.Duration.ofSeconds(30)), stack.engine.syncOnce())
        // A recording left to retry doesn't hold back the queue.
        assertEquals(CustomAudioJson.LOCAL_ONLY, stack.server.document()["audio"])

        stack.objects.putResults += TransferResult.Refused(403)
        assertEquals(SyncOutcome.Failed(null), stack.engine.syncOnce())
        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())
        assertEquals(1, stack.audioServer.ready.size)
    }

    @Test
    fun `an asset cleaned up before its put landed is uploaded again under a new ID in the same run`() = runTest {
        val stack = signedInStack()
        stack.saveWithRecording()
        stack.engine.syncOnce()
        val first = stack.audioServer.ready.keys.single()
        // An edit names the asset while offline; the server cleans the asset up meanwhile.
        val edited = checkNotNull(stack.dhikrs.dhikr(dhikrId).first())
        stack.dhikrs.save(edited.copy(title = edited.title.copy(en = "Edited")))
        stack.audioServer.cleanUp(first)
        stack.server.readyAssets.remove(first)

        stack.engine.syncOnce()

        assertEquals(
            listOf(SyncNotice(RejectionCode.AUDIO_NOT_FOUND, key)),
            stack.sync.notices.first(),
        )
        assertEquals(JsonPrimitive("Edited"), (stack.server.document()["title"] as JsonObject)["en"])
        assertEquals(RecordingUpload.NONE, stack.audio.upload(dhikrId).first())

        val second = stack.audioServer.ready.keys.single()
        assertTrue(second != first)
        assertEquals(second, CustomAudioJson.uploaded(stack.server.document()["audio"])?.assetId?.value)
    }

    @Test
    fun `signed out, recordings wait and nothing is uploaded`() = runTest {
        val stack = SyncStack(this, signedIn = null)
        stack.ownActiveProfile()
        stack.saveWithRecording()

        assertEquals(SyncOutcome.Skipped, stack.engine.syncOnce())

        assertTrue(stack.audioServer.calls.isEmpty() && stack.objects.puts.isEmpty())
        assertEquals(RecordingUpload.QUEUED, stack.audio.upload(dhikrId).first())
    }

    @Test
    fun `the anonymous profile queues no upload, and Add to my account queues every local recording`() = runTest {
        val stack = SyncStack(this)
        stack.saveWithRecording()
        assertEquals(RecordingUpload.NONE, stack.audio.upload(dhikrId).first())

        val profileId = stack.databases.current().profileId
        ProfileTransfers(stack.databases, stack.profiles.clock, stack.profiles.ids::next).queueAll(profileId)
        stack.ownActiveProfile()
        stack.engine.syncOnce()

        val asset = stack.audioServer.ready.keys.single()
        assertEquals(asset, CustomAudioJson.uploaded(stack.server.document()["audio"])?.assetId?.value)
    }

    @Test
    fun `replacing or removing a recording before it uploads drops its upload`() = runTest {
        val stack = signedInStack()
        stack.saveWithRecording()
        val saved = checkNotNull(stack.dhikrs.dhikr(dhikrId).first())

        stack.dhikrs.save(saved.copy(audio = null))

        assertEquals(RecordingUpload.NONE, stack.audio.upload(dhikrId).first())
        stack.engine.syncOnce()
        assertTrue(stack.audioServer.calls.isEmpty())
    }

    private suspend fun TestScope.signedInStack(): SyncStack = SyncStack(this).also { it.ownActiveProfile() }

    /** Saves the dhikr with a recording file in the profile's private files, as an import leaves it. */
    private suspend fun SyncStack.saveWithRecording(name: String = "recording.mp3", content: ByteArray = bytes): File {
        val folder = File(databases.current().filesDir, "audio").apply { mkdirs() }
        val file = File(folder, name).apply { writeBytes(content) }
        dhikrs.save(dhikr(dhikrId).copy(audio = CustomAudio(file.toUri().toString())))
        return file
    }

    private suspend fun SyncStack.localDocument(): JsonObject = entities().first { it.key == key }.document

    private fun app.awrad.core.data.sync.FakeSyncServer.document(): JsonObject =
        entities.getValue(CUSTOM to dhikrId.value).document!!

    private fun problem(status: Int, code: String) =
        ApiFailure.ProblemResponse(Problem(status = status, code = code), null)

    private companion object {
        const val BYTES = 2_000
        const val USED_NEARLY_ALL = 499_999_000L
    }
}
