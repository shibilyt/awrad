package app.awrad.feature.library

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.Reference
import app.awrad.core.domain.dhikr.ReferenceLabel
import app.awrad.core.domain.dhikr.label

/*
 * The app's language and the library's localized bits that come from resources rather than the catalog.
 */

/**
 * The language the app shows (its configuration's first locale the app ships, else English), which picks the
 * catalog text. It follows a change of the app's language.
 */
@Composable
@ReadOnlyComposable
internal fun currentContentLanguage(): ContentLanguage {
    val locales = LocalConfiguration.current.locales
    return ContentLanguage.of(List(locales.size()) { locales[it].language })
}

/** "100 dhikrs", with the plural forms of the app's language. */
@Composable
@ReadOnlyComposable
internal fun dhikrCount(count: Int): String = pluralStringResource(R.plurals.library_dhikr_count, count, count)

/** [reference]'s citation, with "Qur'an" in the app's language. */
@Composable
@ReadOnlyComposable
internal fun referenceLabel(reference: Reference): ReferenceLabel =
    reference.label(stringResource(R.string.library_quran))
