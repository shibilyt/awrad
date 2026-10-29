package app.awrad.feature.sync

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.pluralStringResource
import app.awrad.core.domain.personal.AudioStorage
import java.math.RoundingMode
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.roundToInt

/**
 * The account's audio storage in decimal megabytes, as the limits are written (contracts/audio/v1, "Storage
 * used"): [used] with at most one fraction digit, [limit] with none, both in the locale's digits, and
 * [limitMegabytes] to pick the sentence's plural form.
 */
internal data class StorageFigures(val used: String, val limit: String, val limitMegabytes: Int)

internal fun storageFigures(storage: AudioStorage, locale: Locale): StorageFigures {
    val limitMegabytes = (storage.limitBytes.toDouble() / BYTES_PER_MEGABYTE).roundToInt()
    return StorageFigures(
        used = megabytes(locale, fractionDigits = 1).format(storage.usedBytes.toDouble() / BYTES_PER_MEGABYTE),
        limit = megabytes(locale, fractionDigits = 0).format(limitMegabytes),
        limitMegabytes = limitMegabytes,
    )
}

private fun megabytes(locale: Locale, fractionDigits: Int): NumberFormat =
    NumberFormat.getNumberInstance(locale).apply {
        minimumFractionDigits = 0
        maximumFractionDigits = fractionDigits
        roundingMode = RoundingMode.HALF_UP
    }

/** "Audio storage: 120.5 of 500 MB", in the app's language. */
@Composable
internal fun audioStorageText(storage: AudioStorage): String {
    val figures = storageFigures(storage, LocalConfiguration.current.locales[0])
    return pluralStringResource(R.plurals.sync_audio_storage, figures.limitMegabytes, figures.used, figures.limit)
}

/** "120.5 of 500 MB used", for the storage-full notice. */
@Composable
internal fun storageUsedText(storage: AudioStorage): String {
    val figures = storageFigures(storage, LocalConfiguration.current.locales[0])
    return pluralStringResource(R.plurals.sync_audio_storage_used, figures.limitMegabytes, figures.used, figures.limit)
}

private const val BYTES_PER_MEGABYTE = 1_000_000.0
