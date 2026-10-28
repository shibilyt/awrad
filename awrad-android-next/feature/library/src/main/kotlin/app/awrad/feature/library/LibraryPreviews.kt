package app.awrad.feature.library

import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.PlaybackState
import app.awrad.core.domain.audio.PlaybackStatus
import app.awrad.core.domain.dhikr.Audio
import app.awrad.core.domain.dhikr.AudioStyle
import app.awrad.core.domain.dhikr.CatalogTag
import app.awrad.core.domain.dhikr.Collection
import app.awrad.core.domain.dhikr.Dhikr
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.dhikr.LocalizedText
import app.awrad.core.domain.dhikr.Reference
import app.awrad.core.domain.dhikr.Transliteration
import app.awrad.core.domain.dhikr.Virtue

/*
 * The library's screens in light and dark, on sample data (preview text isn't user-facing).
 */

private val sampleReference = Reference.Hadith("muslim-408", collection = "Sahih Muslim", number = "408")

private val sampleDhikr = Dhikr(
    id = AwradId("0f3f7d1e-2a4b-4c5d-8e6f-7a8b9c0d1e2f"),
    key = "swalath",
    kind = DhikrKind.SALAWAT,
    arabic = "صَلَّى ٱللَّٰهُ عَلَىٰ مُحَمَّدٍ، صَلَّى ٱللَّٰهُ عَلَيْهِ وَسَلَّمَ",
    title = LocalizedText(en = "Swalath", ar = "الصلاة على النبي", ml = "സ്വലാത്ത്"),
    transliteration = Transliteration(en = "Swallallahu ala Muhammad, swallallahu alayhi wa sallim"),
    translation = LocalizedText(en = "May Allah send blessings upon Muhammad, and blessings and peace upon him."),
    tags = listOf(CatalogTag("debt", LocalizedText(en = "Debt"))),
    audio = Audio(url = "https://dhikrs.awrad.app/swalath.mp3", style = AudioStyle.RECITATION, repetitions = 1),
    references = listOf(sampleReference),
    virtues = listOf(
        Virtue(LocalizedText(en = "Allah sends ten blessings on whoever sends one."), listOf(sampleReference)),
    ),
)

private val sampleCollection = Collection("swalaths", LocalizedText(en = "Swalaths"), listOf(sampleDhikr))

@Preview(name = "light")
@Preview(name = "dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun LibraryScreenPreview() {
    AwradTheme {
        LibraryScreen(
            state = LibraryUiState(
                isLoading = false,
                collections = listOf(sampleCollection),
                dhikrs = listOf(sampleDhikr),
            ),
            onAction = {},
            onNavigate = {},
        )
    }
}

@Preview(name = "light")
@Preview(name = "dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun SearchEmptyPreview() {
    AwradTheme {
        LibraryScreen(
            state = LibraryUiState(isLoading = false, query = "xyzzy", results = emptyList()),
            onAction = {},
            onNavigate = {},
        )
    }
}

@Preview(name = "light")
@Preview(name = "dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun CollectionScreenPreview() {
    AwradTheme {
        CollectionScreen(state = CollectionUiState.Ready(sampleCollection), onOpenDhikr = {}, onBack = {})
    }
}

@Preview(name = "light")
@Preview(name = "dark", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun DhikrDetailPreview() {
    AwradTheme {
        DhikrDetailScreen(
            state = DhikrDetailUiState(
                isLoading = false,
                dhikr = sampleDhikr,
                playback = PlaybackState(PlaybackStatus.PLAYING, positionMs = 4_000, durationMs = 12_000),
            ),
            onAction = {},
            onEdit = {},
            onBack = {},
        )
    }
}
