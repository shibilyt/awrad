package app.awrad.feature.practice

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.hijri.HijriAdjustment
import app.awrad.core.domain.hijri.HijriCorrection
import app.awrad.core.domain.places.CurrentLocation
import app.awrad.core.domain.places.LocationReading
import app.awrad.core.domain.practice.CalculationMethod
import app.awrad.core.domain.practice.DayReset
import app.awrad.core.domain.practice.DeviceContextStore
import app.awrad.core.domain.practice.DeviceLocation
import app.awrad.core.domain.practice.LocationSource
import app.awrad.core.domain.practice.Madhab
import app.awrad.core.domain.practice.PracticePolicy
import app.awrad.core.domain.practice.PracticeSettingsRepository
import app.awrad.core.domain.practice.WeekStart
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.temporal.ChronoUnit
import javax.inject.Inject

/** The page's state. [today] is null until the policy and location are known. */
internal data class PracticeSettingsUiState(
    val isLoading: Boolean = true,
    val policy: PracticePolicy = PracticePolicy.DEFAULT,
    val location: DeviceLocation? = null,
    val today: PracticeToday? = null,
    val sheet: PracticeSheet? = null,
    val isLocating: Boolean = false,
    val locationProblem: LocationProblem? = null,
)

/** The bottom sheet open over the page. */
internal sealed interface PracticeSheet {
    data object Method : PracticeSheet

    data class Adjust(val year: Int, val month: Int) : PracticeSheet
}

/** Why "Use my location" found nothing. */
internal enum class LocationProblem { PERMISSION_DENIED, UNAVAILABLE }

internal sealed interface PracticeSettingsAction {
    data class SetDayReset(val dayReset: DayReset) : PracticeSettingsAction

    data class SetMethod(val method: CalculationMethod) : PracticeSettingsAction

    data class SetMadhab(val madhab: Madhab) : PracticeSettingsAction

    data class SetWeekStart(val weekStart: WeekStart) : PracticeSettingsAction

    /** Moves [year]-[month] to [offsetDays] from the table. */
    data class Adjust(val year: Int, val month: Int, val offsetDays: Int) : PracticeSettingsAction

    data class RemoveCorrection(val correction: HijriCorrection) : PracticeSettingsAction

    data class OpenSheet(val sheet: PracticeSheet) : PracticeSettingsAction

    data object CloseSheet : PracticeSettingsAction

    /** The coarse-location permission is granted: take one reading. */
    data object UseMyLocation : PracticeSettingsAction

    data object LocationPermissionDenied : PracticeSettingsAction

    data object ClearLocation : PracticeSettingsAction
}

/**
 * Practice settings: the active profile's policy (each change saved at once, and queued for the account in its
 * profile) and this phone's location (never sent anywhere). Today's Hijri date and Maghrib follow the clock, minute
 * by minute, in the system's time zone.
 */
@HiltViewModel
internal class PracticeSettingsViewModel @Inject constructor(
    private val settings: PracticeSettingsRepository,
    private val deviceContext: DeviceContextStore,
    private val currentLocation: CurrentLocation,
    private val clock: Clock,
) : ViewModel() {

    private val mutableState = MutableStateFlow(PracticeSettingsUiState())
    val state: StateFlow<PracticeSettingsUiState> = mutableState.asStateFlow()

    private val now = MutableStateFlow(clock.instant())

    init {
        viewModelScope.launch {
            while (true) {
                val next = now.value.truncatedTo(ChronoUnit.MINUTES).plus(1, ChronoUnit.MINUTES)
                delay(maxOf(next.toEpochMilli() - clock.millis(), MIN_TICK_MS))
                now.value = clock.instant()
            }
        }
        viewModelScope.launch {
            combine(settings.policy, deviceContext.location, now) { policy, location, instant ->
                Triple(policy, location, PracticeToday.of(policy, location, instant, clock.zone))
            }.collect { (policy, location, today) ->
                mutableState.update {
                    it.copy(isLoading = false, policy = policy, location = location, today = today)
                }
            }
        }
    }

    fun onAction(action: PracticeSettingsAction) {
        when (action) {
            is PracticeSettingsAction.SetDayReset -> update { it.copy(dayReset = action.dayReset) }
            is PracticeSettingsAction.SetMethod -> {
                mutableState.update { it.copy(sheet = null) }
                update { it.copy(calculationMethod = action.method) }
            }
            is PracticeSettingsAction.SetMadhab -> update { it.copy(madhab = action.madhab) }
            is PracticeSettingsAction.SetWeekStart -> update { it.copy(weekStart = action.weekStart) }
            is PracticeSettingsAction.Adjust -> {
                mutableState.update { it.copy(sheet = null) }
                update { policy ->
                    val corrections = HijriAdjustment.withOffset(
                        policy.hijriCorrections,
                        action.year,
                        action.month,
                        action.offsetDays,
                    )
                    corrections?.let { policy.copy(hijriCorrections = it) } ?: policy
                }
            }
            is PracticeSettingsAction.RemoveCorrection -> update { policy ->
                HijriAdjustment.without(policy.hijriCorrections, action.correction)
                    ?.let { policy.copy(hijriCorrections = it) } ?: policy
            }
            is PracticeSettingsAction.OpenSheet -> mutableState.update { it.copy(sheet = action.sheet) }
            PracticeSettingsAction.CloseSheet -> mutableState.update { it.copy(sheet = null) }
            PracticeSettingsAction.UseMyLocation -> readLocation()
            PracticeSettingsAction.LocationPermissionDenied ->
                mutableState.update { it.copy(locationProblem = LocationProblem.PERMISSION_DENIED) }
            PracticeSettingsAction.ClearLocation -> viewModelScope.launch {
                mutableState.update { it.copy(locationProblem = null) }
                deviceContext.setLocation(null)
            }
        }
    }

    private fun update(change: (PracticePolicy) -> PracticePolicy) {
        viewModelScope.launch { settings.update(change) }
    }

    private fun readLocation() {
        if (mutableState.value.isLocating) return
        mutableState.update { it.copy(isLocating = true, locationProblem = null) }
        viewModelScope.launch {
            val problem = when (val reading = currentLocation.read()) {
                is LocationReading.Found -> {
                    deviceContext.setLocation(
                        DeviceLocation(reading.latitude, reading.longitude, null, LocationSource.GPS),
                    )
                    null
                }
                LocationReading.NoPermission -> LocationProblem.PERMISSION_DENIED
                LocationReading.Unavailable -> LocationProblem.UNAVAILABLE
            }
            mutableState.update { it.copy(isLocating = false, locationProblem = problem) }
        }
    }

    private companion object {
        const val MIN_TICK_MS = 1_000L
    }
}
