package app.awrad.core.data.personal

import android.content.Context
import androidx.core.net.toUri
import androidx.test.core.app.ApplicationProvider
import app.awrad.core.domain.personal.AudioImport
import app.awrad.core.domain.personal.AudioImportError
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Imports accept only an `.mp3` or `.m4a` (contracts/audio/v1/README.md, "Phones"). */
@RunWith(RobolectricTestRunner::class)
class AudioFilesTest {

    @get:Rule
    val folder = TemporaryFolder()

    private val files = AudioFiles(ApplicationProvider.getApplicationContext<Context>().contentResolver)

    @Test
    fun `an mp3 or m4a is kept under its own extension, whatever the case`() {
        assertEquals("mp3", AudioFiles.importExtension(type = null, name = "Morning.MP3"))
        assertEquals("m4a", AudioFiles.importExtension(type = "audio/mp4", name = "recording.m4a"))
        assertEquals("m4a", AudioFiles.importExtension(type = "application/octet-stream", name = "voice.M4a"))
    }

    @Test
    fun `without an extension the system type decides, and audio x-m4a is M4A`() {
        assertEquals("mp3", AudioFiles.importExtension(type = "audio/mpeg", name = "audio:1234"))
        assertEquals("m4a", AudioFiles.importExtension(type = "audio/mp4", name = null))
        assertEquals("m4a", AudioFiles.importExtension(type = "AUDIO/X-M4A", name = "Recording"))
    }

    @Test
    fun `everything else is refused, a raw aac stream included`() {
        listOf(
            "audio/aac" to "raw.aac",
            "audio/mp4" to "raw.aac",
            "audio/wav" to "clip.wav",
            "audio/ogg" to "clip.ogg",
            "video/mp4" to "clip.mp4",
            "audio/aac" to "audio:1234",
            "audio/mp3" to "Recording",
            null to "Recording",
            null to null,
        ).forEach { (type, name) -> assertNull(AudioFiles.importExtension(type, name), "$type $name") }
    }

    @Test
    fun `importing a raw aac file fails as an unsupported type and leaves nothing behind`() {
        val source = folder.newFile("raw.aac").apply { writeBytes(ByteArray(SIZE)) }
        val profile = folder.newFolder("profile")

        val result = files.import(source.toUri().toString(), profile, "0192f0d0-0000-7000-8000-0000000000a1")

        assertEquals(AudioImport.Failed(AudioImportError.UNSUPPORTED_TYPE), result)
        assertTrue(File(profile, "audio").listFiles().orEmpty().isEmpty())
    }

    @Test
    fun `importing an m4a copies it into the profile's audio folder`() {
        val source = folder.newFile("recording.m4a").apply { writeBytes(ByteArray(SIZE) { it.toByte() }) }
        val profile = folder.newFolder("profile")

        val result = files.import(source.toUri().toString(), profile, "0192f0d0-0000-7000-8000-0000000000a1")

        val copy = File(profile, "audio/0192f0d0-0000-7000-8000-0000000000a1.m4a")
        assertEquals(AudioImport.Imported(copy.toUri().toString()), result)
        assertTrue(copy.readBytes().contentEquals(source.readBytes()))
    }

    private companion object {
        const val SIZE = 1_024
    }
}
