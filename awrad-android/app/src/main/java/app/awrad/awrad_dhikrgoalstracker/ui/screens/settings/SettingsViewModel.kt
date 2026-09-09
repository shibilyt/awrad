package app.awrad.awrad_dhikrgoalstracker.ui.screens.settings

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.BuildConfig
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.CalculationMethodPref
import app.awrad.awrad_dhikrgoalstracker.data.model.CityResult
import app.awrad.awrad_dhikrgoalstracker.data.model.DayResetOption
import app.awrad.awrad_dhikrgoalstracker.data.model.MadhabPref
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.PrayerTimeRepository
import app.awrad.awrad_dhikrgoalstracker.notification.BatteryOptimizationHelper
import app.awrad.awrad_dhikrgoalstracker.notification.DailyRemembranceScheduler
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
import app.awrad.awrad_dhikrgoalstracker.data.sync.ProgressSyncRepository
import app.awrad.awrad_dhikrgoalstracker.data.sync.ProgressSyncScheduler
import app.awrad.awrad_dhikrgoalstracker.ui.components.ReminderReliabilityUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SettingsUiState(
    val userName: String = "",
    val darkMode: Boolean? = null,
    val vibrateOnCount: Boolean = false,
    val keepScreenOn: Boolean = false,
    val soundOnCount: Boolean = false,
    val dailyReminderEnabled: Boolean = false,
    val dailyRemembranceEnabled: Boolean = false,
    val urgencyRemindersEnabled: Boolean = true,
    val reminderHour: Int = 8,
    val reminderMinute: Int = 0,
    val prayerSlotDefaultLeadMinutes: Int = 30,
    val downloadableCount: Int = 0,
    val isEditingName: Boolean = false,
    val editedName: String = "",
    val showResetProgressDialog: Boolean = false,
    val showDeleteGoalsDialog: Boolean = false,
    // Prayer settings
    val locationName: String = "",
    val calculationMethod: CalculationMethodPref = CalculationMethodPref.KARACHI,
    val madhab: MadhabPref = MadhabPref.SHAFI,
    val showLocationSearchDialog: Boolean = false,
    val locationQuery: String = "",
    val locationSearchResults: List<CityResult> = emptyList(),
    val isSearchingLocation: Boolean = false,
    // Date & Calendar
    val dayResetOption: DayResetOption = DayResetOption.MIDNIGHT,
    val calendarSystem: CalendarSystem = CalendarSystem.GREGORIAN,
    val reminderReliability: ReminderReliabilityUiState = ReminderReliabilityUiState(),
    val showOemBatteryDialog: Boolean = false,
    val syncPendingCommands: Int = 0,
    val syncConflicts: Int = 0,
    val syncFailedCommands: Int = 0,
    val syncLastError: String? = null,
    val syncLastSyncAt: Long? = null,
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val userPreferences: UserPreferences,
    private val dhikrRepository: DhikrRepository,
    private val goalRepository: GoalRepository,
    private val prayerTimeRepository: PrayerTimeRepository,
    private val reminderScheduler: ReminderScheduler,
    private val dailyRemembranceScheduler: DailyRemembranceScheduler,
    private val batteryOptimizationHelper: BatteryOptimizationHelper,
    private val progressSyncRepository: ProgressSyncRepository,
    private val progressSyncScheduler: ProgressSyncScheduler,
) : ViewModel() {

    private val _localState = MutableStateFlow(SettingsLocalState())
    private var locationSearchJob: Job? = null

    val uiState: StateFlow<SettingsUiState> = combine(
        combine(
            userPreferences.userName,
            userPreferences.darkMode,
            userPreferences.vibrateOnCount,
            userPreferences.keepScreenOn,
            userPreferences.soundOnCount,
        ) { userName, darkMode, vibrate, keepScreen, sound ->
            PrefsGroup(userName, darkMode, vibrate, keepScreen, sound)
        },
        combine(
            combine(
                userPreferences.dailyReminderEnabled,
                userPreferences.reminderHour,
                userPreferences.reminderMinute,
                userPreferences.cityName,
                userPreferences.calculationMethod,
            ) { reminderEnabled, reminderHour, reminderMinute, cityName, methodStr ->
                NotifGroup(reminderEnabled, reminderHour, reminderMinute, cityName, methodStr, 30, false, true)
            },
            userPreferences.prayerSlotDefaultLeadMinutes,
            userPreferences.dailyRemembranceEnabled,
            userPreferences.urgencyRemindersEnabled,
        ) { notifs, leadMinutes, remembranceEnabled, urgencyEnabled ->
            notifs.copy(
                prayerSlotDefaultLeadMinutes = leadMinutes,
                dailyRemembranceEnabled = remembranceEnabled,
                urgencyRemindersEnabled = urgencyEnabled,
            )
        },
        combine(
            userPreferences.madhab,
            userPreferences.dayResetTime,
            userPreferences.calendarSystem,
            _localState,
        ) { madhabStr, dayReset, calSystem, local ->
            PrayerGroup(madhabStr, dayReset, calSystem, local)
        },
    ) { prefs, notifs, prayer ->
        val method = try {
            CalculationMethodPref.valueOf(notifs.methodStr)
        } catch (e: IllegalArgumentException) {
            CalculationMethodPref.KARACHI
        }
        val madhab = try {
            MadhabPref.valueOf(prayer.madhabStr)
        } catch (e: IllegalArgumentException) {
            MadhabPref.SHAFI
        }
        val dayReset = try {
            DayResetOption.valueOf(prayer.dayResetStr)
        } catch (e: IllegalArgumentException) {
            DayResetOption.MIDNIGHT
        }
        val calSystem = try {
            CalendarSystem.valueOf(prayer.calSystemStr)
        } catch (e: IllegalArgumentException) {
            CalendarSystem.GREGORIAN
        }
        SettingsUiState(
            userName = prefs.userName,
            darkMode = prefs.darkMode,
            vibrateOnCount = prefs.vibrate,
            keepScreenOn = prefs.keepScreen,
            soundOnCount = prefs.sound,
            dailyReminderEnabled = notifs.reminderEnabled,
            dailyRemembranceEnabled = notifs.dailyRemembranceEnabled,
            urgencyRemindersEnabled = notifs.urgencyRemindersEnabled,
            reminderHour = notifs.reminderHour,
            reminderMinute = notifs.reminderMinute,
            prayerSlotDefaultLeadMinutes = notifs.prayerSlotDefaultLeadMinutes,
            downloadableCount = prayer.local.downloadableCount,
            isEditingName = prayer.local.isEditingName,
            editedName = prayer.local.editedName,
            showResetProgressDialog = prayer.local.showResetProgressDialog,
            showDeleteGoalsDialog = prayer.local.showDeleteGoalsDialog,
            locationName = notifs.cityName,
            calculationMethod = method,
            madhab = madhab,
            showLocationSearchDialog = prayer.local.showLocationSearchDialog,
            locationQuery = prayer.local.locationQuery,
            locationSearchResults = prayer.local.locationSearchResults,
            isSearchingLocation = prayer.local.isSearchingLocation,
            dayResetOption = dayReset,
            calendarSystem = calSystem,
            reminderReliability = prayer.local.reminderReliability,
            showOemBatteryDialog = prayer.local.showOemBatteryDialog,
            syncPendingCommands = prayer.local.syncPendingCommands,
            syncConflicts = prayer.local.syncConflicts,
            syncFailedCommands = prayer.local.syncFailedCommands,
            syncLastError = prayer.local.syncLastError,
            syncLastSyncAt = prayer.local.syncLastSyncAt,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = SettingsUiState(),
    )

    val downloadProgress: StateFlow<DownloadProgress> =
        dhikrRepository.getLibraryDownloadProgress()
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = DownloadProgress(),
            )

    init {
        viewModelScope.launch {
            refreshDownloadableCount()
            refreshSyncHealth()
        }
        refreshReminderReliability()
    }

    private suspend fun refreshDownloadableCount() {
        val count = dhikrRepository.getDownloadableDhikrs().size
        _localState.update { it.copy(downloadableCount = count) }
    }

    private suspend fun refreshSyncHealth() {
        val health = progressSyncRepository.health()
        _localState.update {
            it.copy(
                syncPendingCommands = health.pendingCommands,
                syncConflicts = health.conflicts,
                syncFailedCommands = health.failedCommands,
                syncLastError = health.lastError,
                syncLastSyncAt = health.lastSyncAt,
            )
        }
    }

    fun syncNow() {
        progressSyncScheduler.enqueue()
        viewModelScope.launch {
            delay(1_000)
            refreshSyncHealth()
        }
    }

    fun onStartEditName() {
        _localState.update {
            it.copy(isEditingName = true, editedName = uiState.value.userName)
        }
    }

    fun onEditedNameChanged(name: String) {
        _localState.update { it.copy(editedName = name) }
    }

    fun onSaveName() {
        val name = _localState.value.editedName.trim()
        if (name.isNotBlank()) {
            viewModelScope.launch {
                userPreferences.setUserName(name)
            }
        }
        _localState.update { it.copy(isEditingName = false) }
    }

    fun onCancelEditName() {
        _localState.update { it.copy(isEditingName = false) }
    }

    fun onSetDarkMode(mode: Boolean?) {
        viewModelScope.launch { userPreferences.setDarkMode(mode) }
    }

    fun onToggleVibrate(enabled: Boolean) {
        viewModelScope.launch { userPreferences.setVibrateOnCount(enabled) }
    }

    fun onToggleKeepScreenOn(enabled: Boolean) {
        viewModelScope.launch { userPreferences.setKeepScreenOn(enabled) }
    }

    fun onToggleSoundOnCount(enabled: Boolean) {
        viewModelScope.launch { userPreferences.setSoundOnCount(enabled) }
    }

    fun onToggleDailyReminder(enabled: Boolean) {
        viewModelScope.launch {
            userPreferences.setDailyReminderEnabled(enabled)
            reminderScheduler.rescheduleAll()
        }
    }

    fun onToggleDailyRemembrance(enabled: Boolean) {
        viewModelScope.launch {
            userPreferences.setDailyRemembranceEnabled(enabled)
            if (enabled) {
                dailyRemembranceScheduler.schedule()
            } else {
                dailyRemembranceScheduler.cancel()
            }
        }
    }

    fun onUrgencyRemindersChanged(enabled: Boolean) {
        viewModelScope.launch {
            userPreferences.setUrgencyRemindersEnabled(enabled)
        }
    }

    fun onReminderTimeChanged(hour: Int, minute: Int) {
        viewModelScope.launch {
            userPreferences.setReminderHour(hour)
            userPreferences.setReminderMinute(minute)
            reminderScheduler.rescheduleAll()
        }
    }

    fun onPrayerSlotDefaultLeadMinutesChanged(minutes: Int) {
        viewModelScope.launch {
            userPreferences.setPrayerSlotDefaultLeadMinutes(minutes)
        }
    }

    fun onDownloadLibrary() {
        viewModelScope.launch {
            dhikrRepository.downloadAllAudio()
            refreshDownloadableCount()
        }
    }

    fun onShowResetProgressDialog() {
        _localState.update { it.copy(showResetProgressDialog = true) }
    }

    fun onDismissResetProgressDialog() {
        _localState.update { it.copy(showResetProgressDialog = false) }
    }

    fun onConfirmResetProgress() {
        viewModelScope.launch {
            goalRepository.deleteAllProgress()
            _localState.update { it.copy(showResetProgressDialog = false) }
        }
    }

    fun onShowDeleteGoalsDialog() {
        _localState.update { it.copy(showDeleteGoalsDialog = true) }
    }

    fun onDismissDeleteGoalsDialog() {
        _localState.update { it.copy(showDeleteGoalsDialog = false) }
    }

    fun setAppLanguage(languageTag: String) {
        val locales = if (languageTag.isEmpty()) {
            LocaleListCompat.getEmptyLocaleList()
        } else {
            LocaleListCompat.forLanguageTags(languageTag)
        }
        AppCompatDelegate.setApplicationLocales(locales)
    }

    fun currentLanguageTag(): String =
        AppCompatDelegate.getApplicationLocales().toLanguageTags()
            .split(",").firstOrNull()?.trim() ?: ""

    fun onConfirmDeleteGoals() {
        viewModelScope.launch {
            goalRepository.deleteAllGoalsAndProgress()
            _localState.update { it.copy(showDeleteGoalsDialog = false) }
        }
    }

    // --- Prayer Settings ---

    fun onShowLocationSearch() {
        locationSearchJob?.cancel()
        _localState.update {
            it.copy(
                showLocationSearchDialog = true,
                locationQuery = "",
                locationSearchResults = emptyList(),
                isSearchingLocation = false,
            )
        }
    }

    fun onDismissLocationSearch() {
        locationSearchJob?.cancel()
        _localState.update {
            it.copy(
                showLocationSearchDialog = false,
                isSearchingLocation = false,
                locationSearchResults = emptyList(),
            )
        }
    }

    fun onLocationQueryChanged(query: String) {
        _localState.update {
            it.copy(
                locationQuery = query,
                locationSearchResults = emptyList(),
                isSearchingLocation = false,
            )
        }
        searchCity(query = query, debounce = true)
    }

    fun onSearchCity() {
        searchCity(query = _localState.value.locationQuery, debounce = false)
    }

    private fun searchCity(query: String, debounce: Boolean) {
        val trimmedQuery = query.trim()
        locationSearchJob?.cancel()

        if (trimmedQuery.length < MIN_LOCATION_QUERY_LENGTH) {
            _localState.update {
                it.copy(
                    isSearchingLocation = false,
                    locationSearchResults = emptyList(),
                )
            }
            return
        }

        locationSearchJob = viewModelScope.launch {
            if (debounce) {
                delay(LOCATION_SEARCH_DEBOUNCE_MS)
            }
            val stateBeforeSearch = _localState.value
            if (!stateBeforeSearch.showLocationSearchDialog || stateBeforeSearch.locationQuery.trim() != trimmedQuery) {
                return@launch
            }
            _localState.update { state ->
                if (state.showLocationSearchDialog && state.locationQuery.trim() == trimmedQuery) {
                    state.copy(isSearchingLocation = true, locationSearchResults = emptyList())
                } else {
                    state
                }
            }
            val results = prayerTimeRepository.searchCity(trimmedQuery)
            _localState.update { state ->
                if (state.showLocationSearchDialog && state.locationQuery.trim() == trimmedQuery) {
                    state.copy(isSearchingLocation = false, locationSearchResults = results)
                } else {
                    state
                }
            }
        }
    }

    fun onCitySelected(city: CityResult) {
        locationSearchJob?.cancel()
        viewModelScope.launch {
            userPreferences.setLocation(city.latitude, city.longitude, city.displayName)
            _localState.update {
                it.copy(
                    showLocationSearchDialog = false,
                    isSearchingLocation = false,
                    locationSearchResults = emptyList(),
                )
            }
            progressSyncScheduler.enqueue()
            reminderScheduler.rescheduleAll()
        }
    }

    fun onGpsLocationObtained(latitude: Double, longitude: Double) {
        locationSearchJob?.cancel()
        viewModelScope.launch {
            val cityName = prayerTimeRepository.reverseGeocode(latitude, longitude).ifBlank { "Current Location" }
            userPreferences.setLocation(latitude, longitude, cityName)
            _localState.update {
                it.copy(
                    showLocationSearchDialog = false,
                    isSearchingLocation = false,
                    locationSearchResults = emptyList(),
                )
            }
            progressSyncScheduler.enqueue()
            reminderScheduler.rescheduleAll()
        }
    }

    fun onCalculationMethodChanged(method: CalculationMethodPref) {
        viewModelScope.launch {
            userPreferences.setCalculationMethod(method.name)
            progressSyncScheduler.enqueue()
            reminderScheduler.rescheduleAll()
        }
    }

    fun onMadhabChanged(madhab: MadhabPref) {
        viewModelScope.launch {
            userPreferences.setMadhab(madhab.name)
            progressSyncScheduler.enqueue()
            reminderScheduler.rescheduleAll()
        }
    }

    fun onDayResetChanged(option: DayResetOption) {
        viewModelScope.launch {
            userPreferences.setDayResetTime(option.name)
            progressSyncScheduler.enqueue()
        }
    }

    fun onCalendarSystemChanged(system: CalendarSystem) {
        viewModelScope.launch { userPreferences.setCalendarSystem(system.name) }
    }

    fun refreshReminderReliability() {
        _localState.update {
            it.copy(
                reminderReliability = ReminderReliabilityUiState(
                    canScheduleExactAlarms = reminderScheduler.canScheduleExactAlarms(),
                    isIgnoringBatteryOptimizations = batteryOptimizationHelper.isIgnoringBatteryOptimizations(),
                    oemBatteryInfo = batteryOptimizationHelper.getOemBatteryInfo(),
                ),
            )
        }
    }

    fun exactAlarmSettingsIntent(): Intent? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !reminderScheduler.canScheduleExactAlarms()) {
            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:${BuildConfig.APPLICATION_ID}")
            }
        } else {
            null
        }

    fun batteryOptimizationIntent(): Intent =
        batteryOptimizationHelper.createBatteryOptimizationIntent()

    fun appBatterySettingsIntent(): Intent =
        batteryOptimizationHelper.createAppBatterySettingsIntent()

    fun onShowOemBatteryDialog() {
        _localState.update { it.copy(showOemBatteryDialog = true) }
    }

    fun onDismissOemBatteryDialog() {
        _localState.update { it.copy(showOemBatteryDialog = false) }
    }

    private companion object {
        const val LOCATION_SEARCH_DEBOUNCE_MS = 500L
        const val MIN_LOCATION_QUERY_LENGTH = 2
    }

    private data class SettingsLocalState(
        val downloadableCount: Int = 0,
        val isEditingName: Boolean = false,
        val editedName: String = "",
        val showResetProgressDialog: Boolean = false,
        val showDeleteGoalsDialog: Boolean = false,
        val showLocationSearchDialog: Boolean = false,
        val locationQuery: String = "",
        val locationSearchResults: List<CityResult> = emptyList(),
        val isSearchingLocation: Boolean = false,
        val reminderReliability: ReminderReliabilityUiState = ReminderReliabilityUiState(),
        val showOemBatteryDialog: Boolean = false,
        val syncPendingCommands: Int = 0,
        val syncConflicts: Int = 0,
        val syncFailedCommands: Int = 0,
        val syncLastError: String? = null,
        val syncLastSyncAt: Long? = null,
    )

    private data class PrefsGroup(
        val userName: String,
        val darkMode: Boolean?,
        val vibrate: Boolean,
        val keepScreen: Boolean,
        val sound: Boolean,
    )

    private data class NotifGroup(
        val reminderEnabled: Boolean,
        val reminderHour: Int,
        val reminderMinute: Int,
        val cityName: String,
        val methodStr: String,
        val prayerSlotDefaultLeadMinutes: Int,
        val dailyRemembranceEnabled: Boolean,
        val urgencyRemindersEnabled: Boolean,
    )

    private data class PrayerGroup(
        val madhabStr: String,
        val dayResetStr: String,
        val calSystemStr: String,
        val local: SettingsLocalState,
    )
}
