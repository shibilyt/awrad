package app.awrad.awrad_dhikrgoalstracker.service

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException

class AudioDownloadSecurityTest {

    @Test
    fun validatesFirstPartyHttpsAudioUrls() {
        assertNotNull(AudioDownloadSecurity.validatedAudioUrl("https://dhikrs.awrad.app/ikhlas.mp3"))
        assertNull(AudioDownloadSecurity.validatedAudioUrl("http://dhikrs.awrad.app/ikhlas.mp3"))
        assertNull(AudioDownloadSecurity.validatedAudioUrl("https://127.0.0.1/ikhlas.mp3"))
        assertNull(AudioDownloadSecurity.validatedAudioUrl("https://example.com/ikhlas.mp3"))
    }

    @Test
    fun resolvesOnlySafeAudioFileNamesInsideAudioDirectory() {
        val audioDir = File("build/tmp/audio-security-test")

        assertEquals(
            File(audioDir, "ikhlas.mp3").canonicalFile,
            AudioDownloadSecurity.resolveOutputFile(audioDir, "ikhlas.mp3"),
        )
        assertNull(AudioDownloadSecurity.resolveOutputFile(audioDir, "../prefs.xml"))
        assertNull(AudioDownloadSecurity.resolveOutputFile(audioDir, "nested/file.mp3"))
        assertNull(AudioDownloadSecurity.resolveOutputFile(audioDir, "bad name.mp3"))
    }

    @Test
    fun validatesAudioResponseMetadata() {
        assertTrue(AudioDownloadSecurity.isAllowedContentLength(1_000L))
        assertTrue(AudioDownloadSecurity.isAllowedContentLength(-1L))
        assertFalse(AudioDownloadSecurity.isAllowedContentLength(AudioDownloadSecurity.MAX_AUDIO_BYTES + 1L))

        assertTrue(AudioDownloadSecurity.isAllowedContentType("audio/mpeg; charset=binary"))
        assertTrue(AudioDownloadSecurity.isAllowedContentType(null))
        assertFalse(AudioDownloadSecurity.isAllowedContentType("text/html"))
    }

    @Test
    fun copyWithLimitCopiesAllowedContent() {
        val bytes = byteArrayOf(1, 2, 3, 4)
        val output = ByteArrayOutputStream()

        val copied = AudioDownloadSecurity.copyWithLimit(
            input = ByteArrayInputStream(bytes),
            output = output,
            maxBytes = 4,
        )

        assertEquals(4, copied)
        assertArrayEquals(bytes, output.toByteArray())
    }

    @Test(expected = IOException::class)
    fun copyWithLimitRejectsOversizedContent() {
        AudioDownloadSecurity.copyWithLimit(
            input = ByteArrayInputStream(byteArrayOf(1, 2, 3, 4)),
            output = ByteArrayOutputStream(),
            maxBytes = 3,
        )
    }
}
