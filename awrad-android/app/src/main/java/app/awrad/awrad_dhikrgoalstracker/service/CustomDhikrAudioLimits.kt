package app.awrad.awrad_dhikrgoalstracker.service

object CustomDhikrAudioLimits {
    /** Exclusive upper bound: exactly 10_000_000 bytes is rejected. */
    const val MAX_BYTES_EXCLUSIVE = 10_000_000L
    const val MAX_DURATION_MS = 10 * 60 * 1000L

    private val ALLOWED_MIME_TYPES = setOf(
        "audio/mp4",
        "audio/m4a",
        "audio/x-m4a",
        "audio/aac",
        "audio/mpeg",
        "audio/mp3",
        "audio/wav",
        "audio/x-wav",
        "audio/wave",
    )

    fun isByteSizeAllowed(byteSize: Long): Boolean =
        byteSize in 1 until MAX_BYTES_EXCLUSIVE

    fun isDurationAllowed(durationMs: Long): Boolean =
        durationMs in 1..MAX_DURATION_MS

    fun isMimeTypeAllowed(mimeType: String?): Boolean {
        if (mimeType.isNullOrBlank()) return false
        return mimeType.lowercase() in ALLOWED_MIME_TYPES
    }
}
