package app.awrad.feature.practice

import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.tooling.preview.PreviewParameter
import androidx.compose.ui.tooling.preview.PreviewParameterProvider
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.hijri.HijriCorrection
import app.awrad.core.domain.hijri.HijriCorrections
import app.awrad.core.domain.hijri.HijriCorrectionsResult
import app.awrad.core.domain.places.City
import app.awrad.core.domain.places.FoundPlace
import app.awrad.core.domain.practice.DayReset
import app.awrad.core.domain.practice.DeviceLocation
import app.awrad.core.domain.practice.LocationSource
import app.awrad.core.domain.practice.PracticePolicy
import java.time.Instant
import java.time.ZoneId

/* The page and the place search in English, Arabic (right to left) and Malayalam, and in English in the dark theme. */

private val Zone = ZoneId.of("Asia/Kolkata")
private val Now = Instant.parse("2026-10-29T10:00:00Z")
private val Kozhikode = DeviceLocation(11.248, 75.7804, "Kozhikode", LocationSource.CITY, 1_265_873)
private val Corrected = PracticePolicy.DEFAULT.copy(
    dayReset = DayReset.MAGHRIB,
    hijriCorrections = (HijriCorrections.create(listOf(HijriCorrection(1448, 4, 1))) as HijriCorrectionsResult.Valid)
        .corrections,
)

private fun loaded(policy: PracticePolicy, location: DeviceLocation?) = PracticeSettingsUiState(
    isLoading = false,
    policy = policy,
    location = location,
    today = PracticeToday.of(policy, location, Now, Zone),
)

private class PracticeStates : PreviewParameterProvider<PracticeSettingsUiState> {
    override val values = sequenceOf(
        loaded(Corrected, Kozhikode),
        loaded(Corrected, null).copy(locationProblem = LocationProblem.PERMISSION_DENIED),
    )
}

private class SearchStates : PreviewParameterProvider<LocationSearchUiState> {
    override val values = sequenceOf(
        LocationSearchUiState(
            query = "koz",
            isLoading = false,
            cities = listOf(
                City(1_265_873, "Kozhikode", "IN", "Kerala", 11.248, 75.7804, 550_440, emptyList()),
                City(306_112, "Kozan", "TR", "Adana", 37.4555, 35.8157, 75_000, emptyList()),
            ),
            places = listOf(FoundPlace("Kozhikode Beach, Kerala, India", 11.26, 75.77)),
            attribution = "City data © GeoNames (geonames.org), CC BY 4.0",
        ),
        LocationSearchUiState(query = "zzz", isLoading = false, attribution = "City data © GeoNames"),
    )
}

@Preview(name = "en", showBackground = true, heightDp = 1800)
@Preview(name = "ar", showBackground = true, heightDp = 1800, locale = "ar")
@Preview(name = "ml", showBackground = true, heightDp = 1800, locale = "ml")
@Preview(name = "en dark", showBackground = true, heightDp = 1800, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun PracticeSettingsPreview(@PreviewParameter(PracticeStates::class) state: PracticeSettingsUiState) {
    AwradTheme {
        PracticeSettingsScreen(state = state, onAction = {}, onBack = {}, onSearch = {}, onUseMyLocation = {})
    }
}

@Preview(name = "en", showBackground = true)
@Preview(name = "ar", showBackground = true, locale = "ar")
@Preview(name = "ml", showBackground = true, locale = "ml")
@Preview(name = "en dark", showBackground = true, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun LocationSearchPreview(@PreviewParameter(SearchStates::class) state: LocationSearchUiState) {
    AwradTheme { LocationSearchScreen(state = state, onAction = {}, onBack = {}) }
}
