package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import android.Manifest
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.CalculationMethodPref
import app.awrad.awrad_dhikrgoalstracker.data.model.CityResult
import app.awrad.awrad_dhikrgoalstracker.data.model.MadhabPref
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer

// ─── Location + Prayer Calculation Scene ─────────────────────────────────────

@Composable
internal fun LocationScene(
    query: String,
    searchResults: List<CityResult>,
    isSearching: Boolean,
    isGettingGps: Boolean,
    selectedCity: CityResult?,
    prayerPreview: List<PrayerPreviewRow>,
    calculationMethod: CalculationMethodPref,
    madhab: MadhabPref,
    showCalcMethodSheet: Boolean,
    onQueryChanged: (String) -> Unit,
    onSearch: () -> Unit,
    onCitySelected: (CityResult) -> Unit,
    onGpsLocationObtained: (Double, Double) -> Unit,
    onShowCalcMethodSheet: () -> Unit,
    onDismissCalcMethodSheet: () -> Unit,
    onCalculationMethodSelected: (CalculationMethodPref) -> Unit,
    onMadhabSelected: (MadhabPref) -> Unit,
) {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current

    val locationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            val locationManager = context.getSystemService(android.content.Context.LOCATION_SERVICE) as LocationManager
            val location = try {
                locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                    ?: locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            } catch (e: SecurityException) {
                null
            }
            if (location != null) {
                onGpsLocationObtained(location.latitude, location.longitude)
            }
        }
    }

    OnboardingScene(
        icon = {
            PrayerTimeGlyph(modifier = Modifier.size(116.dp))
        },
        title = stringResource(R.string.onboarding_location_title),
        subtitle = stringResource(R.string.onboarding_location_subtitle),
    ) {
        Button(
            onClick = {
                val hasPermission = ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ) == PackageManager.PERMISSION_GRANTED
                if (hasPermission) {
                    val locationManager = context.getSystemService(android.content.Context.LOCATION_SERVICE) as LocationManager
                    val location = try {
                        locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                            ?: locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                    } catch (e: SecurityException) {
                        null
                    }
                    if (location != null) {
                        onGpsLocationObtained(location.latitude, location.longitude)
                    }
                } else {
                    locationPermissionLauncher.launch(Manifest.permission.ACCESS_COARSE_LOCATION)
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            enabled = !isGettingGps,
            shape = RoundedCornerShape(20.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = greenContainerColor(),
                contentColor = onGreenContainerColor(),
            ),
        ) {
            if (isGettingGps) {
                CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
            } else {
                Icon(
                    imageVector = Icons.Filled.MyLocation,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                )
            }
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = stringResource(R.string.onboarding_location_gps),
                style = MaterialTheme.typography.titleSmall,
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            HorizontalDivider(modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.outlineVariant)
            Text(
                text = stringResource(R.string.onboarding_location_or),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 12.dp),
            )
            HorizontalDivider(modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.outlineVariant)
        }

        Spacer(modifier = Modifier.height(12.dp))

        OutlinedTextField(
            value = query,
            onValueChange = onQueryChanged,
            label = { Text(stringResource(R.string.onboarding_location_search)) },
            singleLine = true,
            trailingIcon = {
                IconButton(onClick = {
                    focusManager.clearFocus()
                    onSearch()
                }) {
                    Icon(
                        imageVector = Icons.Filled.Search,
                        contentDescription = stringResource(R.string.onboarding_location_search),
                    )
                }
            },
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = {
                focusManager.clearFocus()
                onSearch()
            }),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(22.dp),
        )

        Spacer(modifier = Modifier.height(12.dp))

        if (isSearching) {
            CircularProgressIndicator(modifier = Modifier.size(32.dp))
            Spacer(modifier = Modifier.height(8.dp))
        }

        searchResults.forEach { city ->
            Card(
                onClick = { onCitySelected(city) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 3.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                ),
                shape = RoundedCornerShape(20.dp),
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.Filled.LocationOn,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = city.displayName,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }

        if (selectedCity != null && searchResults.isEmpty()) {
            LocationSetCard(cityName = selectedCity.displayName)

            Spacer(modifier = Modifier.height(14.dp))

            PrayerCalculationCard(
                prayerPreview = prayerPreview,
                calculationMethod = calculationMethod,
                madhab = madhab,
                onAdjust = onShowCalcMethodSheet,
            )
        }

        Spacer(modifier = Modifier.height(16.dp))
    }

    if (showCalcMethodSheet) {
        CalcMethodSheet(
            calculationMethod = calculationMethod,
            madhab = madhab,
            onCalculationMethodSelected = onCalculationMethodSelected,
            onMadhabSelected = onMadhabSelected,
            onDismiss = onDismissCalcMethodSheet,
        )
    }
}

@Composable
private fun LocationSetCard(cityName: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
        ),
        shape = RoundedCornerShape(22.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Filled.Check,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onPrimaryContainer,
                modifier = Modifier.size(20.dp),
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                Text(
                    text = stringResource(R.string.onboarding_location_set),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f),
                )
                Text(
                    text = cityName,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
        }
    }
}

/** Real prayer times for today plus the calculation settings that produced them. */
@Composable
private fun PrayerCalculationCard(
    prayerPreview: List<PrayerPreviewRow>,
    calculationMethod: CalculationMethodPref,
    madhab: MadhabPref,
    onAdjust: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.28f)),
    ) {
        Column(modifier = Modifier.padding(18.dp)) {
            Text(
                text = stringResource(R.string.onboarding_prayer_preview_title),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(modifier = Modifier.height(12.dp))

            prayerPreview.forEach { row ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = prayerLabel(row.prayer),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = row.time,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = calculationMethod.displayName,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = stringResource(madhabDescRes(madhab)),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                TextButton(onClick = onAdjust) {
                    Icon(
                        imageVector = Icons.Outlined.Tune,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = greenAccent(),
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = stringResource(R.string.onboarding_prayer_adjust),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = greenAccent(),
                    )
                }
            }
        }
    }
}

// ─── Calculation method sheet ────────────────────────────────────────────────

@Composable
internal fun prayerLabel(prayer: Prayer): String = stringResource(
    when (prayer) {
        Prayer.FAJR -> R.string.prayer_fajr
        Prayer.DHUHR -> R.string.prayer_dhuhr
        Prayer.ASR -> R.string.prayer_asr
        Prayer.MAGHRIB -> R.string.prayer_maghrib
        Prayer.ISHA -> R.string.prayer_isha
    },
)

private fun methodDescRes(method: CalculationMethodPref): Int = when (method) {
    CalculationMethodPref.KARACHI -> R.string.onboarding_method_desc_karachi
    CalculationMethodPref.NORTH_AMERICA -> R.string.onboarding_method_desc_north_america
    CalculationMethodPref.MWL -> R.string.onboarding_method_desc_mwl
    CalculationMethodPref.EGYPT -> R.string.onboarding_method_desc_egypt
    CalculationMethodPref.UMM_AL_QURA -> R.string.onboarding_method_desc_umm_al_qura
    CalculationMethodPref.MOON_SIGHTING -> R.string.onboarding_method_desc_moon_sighting
    CalculationMethodPref.DUBAI -> R.string.onboarding_method_desc_dubai
    CalculationMethodPref.KUWAIT -> R.string.onboarding_method_desc_kuwait
    CalculationMethodPref.QATAR -> R.string.onboarding_method_desc_qatar
    CalculationMethodPref.SINGAPORE -> R.string.onboarding_method_desc_singapore
}

private fun madhabDescRes(madhab: MadhabPref): Int = when (madhab) {
    MadhabPref.SHAFI -> R.string.onboarding_madhab_shafi_desc
    MadhabPref.HANAFI -> R.string.onboarding_madhab_hanafi_desc
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CalcMethodSheet(
    calculationMethod: CalculationMethodPref,
    madhab: MadhabPref,
    onCalculationMethodSelected: (CalculationMethodPref) -> Unit,
    onMadhabSelected: (MadhabPref) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 28.dp),
        ) {
            item {
                Text(
                    text = stringResource(R.string.onboarding_prayer_config_title),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = stringResource(R.string.onboarding_prayer_config_hint),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.height(18.dp))

                Text(
                    text = stringResource(R.string.onboarding_prayer_config_madhab),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    MadhabPref.entries.forEach { option ->
                        val selected = option == madhab
                        Surface(
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(18.dp),
                            color = if (selected) greenContainerColor() else MaterialTheme.colorScheme.surfaceContainerLow,
                            border = BorderStroke(
                                if (selected) 2.dp else 1.dp,
                                if (selected) greenAccent() else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.36f),
                            ),
                            onClick = { onMadhabSelected(option) },
                        ) {
                            Column(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 12.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                            ) {
                                Text(
                                    text = option.displayName,
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    textAlign = TextAlign.Center,
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = stringResource(madhabDescRes(option)),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    textAlign = TextAlign.Center,
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                Text(
                    text = stringResource(R.string.onboarding_prayer_config_method),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(10.dp))
            }

            items(CalculationMethodPref.entries) { method ->
                val selected = method == calculationMethod
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 5.dp),
                    shape = RoundedCornerShape(18.dp),
                    color = if (selected) greenContainerColor() else MaterialTheme.colorScheme.surfaceContainerLow,
                    border = BorderStroke(
                        if (selected) 2.dp else 1.dp,
                        if (selected) greenAccent() else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.36f),
                    ),
                    onClick = { onCalculationMethodSelected(method) },
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        OnboardingSelectionDot(selected = selected)
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = method.displayName,
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            Text(
                                text = stringResource(methodDescRes(method)),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }

            item {
                Spacer(modifier = Modifier.height(16.dp))
                Button(
                    onClick = onDismiss,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    shape = RoundedCornerShape(20.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = greenAccent(),
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                    ),
                ) {
                    Text(
                        text = stringResource(R.string.onboarding_prayer_config_done),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
    }
}
