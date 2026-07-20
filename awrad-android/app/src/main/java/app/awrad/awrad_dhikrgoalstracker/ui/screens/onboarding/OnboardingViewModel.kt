package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.BuildConfig
import app.awrad.awrad_dhikrgoalstracker.data.model.CalculationMethodPref
import app.awrad.awrad_dhikrgoalstracker.data.model.CityResult
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.MadhabPref
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.data.repository.AuthRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.AuthResult
import app.awrad.awrad_dhikrgoalstracker.data.repository.VerificationMode
import app.awrad.awrad_dhikrgoalstracker.data.repository.VerificationOrigin
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.PrayerTimeRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CountPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CreateGoalCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CreateGoalResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ReminderPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ScheduleSpec
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimingSpec
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.CreateGoalUseCase
import app.awrad.awrad_dhikrgoalstracker.notification.BatteryOptimizationHelper
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
import app.awrad.awrad_dhikrgoalstracker.ui.components.ReminderReliabilityUiState
import com.batoulapps.adhan.PrayerTimes
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Date
import java.util.Locale
import javax.inject.Inject

data class PrayerPreviewRow(
    val prayer: Prayer,
    val time: String,
)

enum class AuthSheetMode {
    SignIn,
    CreateAccount,
}

data class OnboardingUiState(
    val currentStep: Int = 0,
    // Language
    val languageTag: String = "en",
    // Account
    val isSignedIn: Boolean = false,
    val signedInEmail: String? = null,
    val showAuthSheet: Boolean = false,
    val authMode: AuthSheetMode = AuthSheetMode.SignIn,
    val authEmail: String = "",
    val authPassword: String = "",
    val isAuthenticating: Boolean = false,
    val authError: String? = null,
    val usesReturningUserFlow: Boolean = false,
    // Name
    val userName: String = "",
    // First goal
    val selectedPresetId: String? = FirstGoalPresets.defaultPresetId,
    val firstGoalCount: Int = FirstGoalPresets.byId(FirstGoalPresets.defaultPresetId)?.defaultCount ?: 70,
    val isCreatingFirstGoal: Boolean = false,
    val firstGoalId: AwradId? = null,
    // Audio
    val dhikrsWithAudio: List<Dhikr> = emptyList(),
    val audioSetupStatus: AudioSetupStatus = AudioSetupStatus.Idle,
    val isComplete: Boolean = false,
    // Location
    val locationQuery: String = "",
    val locationSearchResults: List<CityResult> = emptyList(),
    val isSearchingLocation: Boolean = false,
    val selectedCity: CityResult? = null,
    val isGettingGpsLocation: Boolean = false,
    // Prayer calculation
    val calculationMethod: CalculationMethodPref = CalculationMethodPref.KARACHI,
    val madhab: MadhabPref = MadhabPref.SHAFI,
    val prayerPreview: List<PrayerPreviewRow> = emptyList(),
    val showCalcMethodSheet: Boolean = false,
    // Notifications
    val notificationsGranted: Boolean = false,
    val reminderReliability: ReminderReliabilityUiState = ReminderReliabilityUiState(),
    val showOemBatteryDialog: Boolean = false,
    // Reminder presets
    val selectedReminderPresets: Set<OnboardingReminderPreset> = emptySet(),
    val reminderPresetTimes: Map<OnboardingReminderPreset, String> = emptyMap(),
)

enum class AudioSetupStatus {
    Idle,
    Downloading,
    Complete,
    PartialFailure,
    Empty,
}

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val dhikrRepository: DhikrRepository,
    private val userPreferences: UserPreferences,
    private val prayerTimeRepository: PrayerTimeRepository,
    private val reminderScheduler: ReminderScheduler,
    private val batteryOptimizationHelper: BatteryOptimizationHelper,
    private val createGoalUseCase: CreateGoalUseCase,
    private val authRepository: AuthRepository,
    private val savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        OnboardingUiState(
            currentStep = savedStateHandle.get<Int>(KEY_CURRENT_STEP) ?: OPENING_STEP_INDEX,
            languageTag = currentLanguageTag(),
            usesReturningUserFlow = savedStateHandle.get<Boolean>(KEY_RETURNING_USER_FLOW) ?: false,
        ),
    )
    val uiState: StateFlow<OnboardingUiState> = _uiState.asStateFlow()

    /** Full seeded dhikr list, used to resolve the first-goal preset by catalog key. */
    private var allDhikrs: List<Dhikr> = emptyList()
    private var locationSearchJob: Job? = null
    private var awaitingVerificationMode: AuthSheetMode? = null
    private val _verificationNavigationEvents = Channel<Unit>(Channel.BUFFERED)
    val verificationNavigationEvents = _verificationNavigationEvents.receiveAsFlow()

    val downloadProgress: StateFlow<DownloadProgress> =
        dhikrRepository.getLibraryDownloadProgress()
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = DownloadProgress(),
            )

    companion object {
        const val TOTAL_STEPS = 10
        const val OPENING_STEP_INDEX = 0
        const val LANGUAGE_STEP_INDEX = 1
        const val ACCOUNT_STEP_INDEX = 2
        const val NAME_STEP_INDEX = 3
        const val LOCATION_STEP_INDEX = 4
        const val NOTIFICATIONS_STEP_INDEX = 5
        const val REMINDERS_STEP_INDEX = 6
        const val AUDIO_STEP_INDEX = 7
        const val GOAL_INTRO_STEP_INDEX = 8
        const val FIRST_GOAL_STEP_INDEX = 9

        private val RETURNING_USER_STEPS = listOf(
            OPENING_STEP_INDEX,
            LANGUAGE_STEP_INDEX,
            ACCOUNT_STEP_INDEX,
            LOCATION_STEP_INDEX,
            NOTIFICATIONS_STEP_INDEX,
            AUDIO_STEP_INDEX,
        )

        internal fun visibleSteps(returningUser: Boolean): List<Int> =
            if (returningUser) RETURNING_USER_STEPS else (0 until TOTAL_STEPS).toList()

        internal fun nextStepIndex(current: Int, returningUser: Boolean): Int? =
            adjacentStepIndex(current, offset = 1, returningUser = returningUser)

        internal fun previousStepIndex(current: Int, returningUser: Boolean): Int? =
            adjacentStepIndex(current, offset = -1, returningUser = returningUser)

        private fun adjacentStepIndex(current: Int, offset: Int, returningUser: Boolean): Int? {
            val route = visibleSteps(returningUser)
            val currentIndex = route.indexOf(current)
            if (currentIndex == -1) return null
            return route.getOrNull(currentIndex + offset)
        }

        private const val KEY_CURRENT_STEP = "onboarding_current_step"
        private const val KEY_RETURNING_USER_FLOW = "onboarding_returning_user_flow"
        private const val LOCATION_SEARCH_DEBOUNCE_MS = 500L
        private const val MIN_LOCATION_QUERY_LENGTH = 2
    }

    init {
        viewModelScope.launch {
            val name = userPreferences.userName.first()
            if (name.isNotBlank()) {
                _uiState.update { it.copy(userName = name) }
            }
        }
        viewModelScope.launch {
            // Restore any previously chosen prayer configuration (e.g. after
            // process death mid-onboarding, or a returning signed-in user).
            val method = calculationMethodFrom(userPreferences.calculationMethod.first())
            val madhab = madhabFrom(userPreferences.madhab.first())
            val latitude = userPreferences.latitude.first()
            val longitude = userPreferences.longitude.first()
            val cityName = userPreferences.cityName.first()
            _uiState.update { state ->
                state.copy(
                    calculationMethod = method,
                    madhab = madhab,
                    selectedCity = state.selectedCity ?: restoredCityOrNull(latitude, longitude, cityName),
                    locationQuery = state.locationQuery.ifBlank { cityName },
                )
            }
            refreshPrayerPreview()
        }
        viewModelScope.launch {
            authRepository.isLoggedIn.collect { loggedIn ->
                val email = if (loggedIn) authRepository.userEmail.first() else null
                _uiState.update { it.copy(isSignedIn = loggedIn, signedInEmail = email) }
                val completedMode = awaitingVerificationMode
                if (loggedIn && completedMode != null && _uiState.value.currentStep == ACCOUNT_STEP_INDEX) {
                    val returning = completedMode == AuthSheetMode.SignIn
                    awaitingVerificationMode = null
                    savedStateHandle[KEY_RETURNING_USER_FLOW] = returning
                    _uiState.update {
                        it.copy(
                            showAuthSheet = false,
                            authPassword = "",
                            usesReturningUserFlow = returning,
                        )
                    }
                    nextStep()
                }
            }
        }
        viewModelScope.launch {
            authRepository.pendingVerificationContext.collect { context ->
                if (context?.origin == VerificationOrigin.Onboarding) {
                    awaitingVerificationMode = when (context.mode) {
                        VerificationMode.Login -> AuthSheetMode.SignIn
                        VerificationMode.Signup -> AuthSheetMode.CreateAccount
                    }
                    _verificationNavigationEvents.trySend(Unit)
                }
            }
        }
        viewModelScope.launch {
            dhikrRepository.initializeBuiltInDhikrs()
            dhikrRepository.getAllDhikrs().collect { dhikrs ->
                allDhikrs = dhikrs
                val dhikrsWithAudio = dhikrs.filter { it.audioUrl != null }
                _uiState.update { state ->
                    state.copy(
                        dhikrsWithAudio = dhikrsWithAudio,
                        audioSetupStatus = audioStatusFor(
                            dhikrsWithAudio = dhikrsWithAudio,
                            currentStatus = state.audioSetupStatus,
                        ),
                    )
                }
            }
        }
        refreshReminderReliability()
    }

    private fun restoredCityOrNull(latitude: Double?, longitude: Double?, cityName: String): CityResult? {
        if (latitude == null || longitude == null || cityName.isBlank()) return null
        return CityResult(
            name = cityName,
            displayName = cityName,
            latitude = latitude,
            longitude = longitude,
        )
    }

    private fun audioStatusFor(
        dhikrsWithAudio: List<Dhikr>,
        currentStatus: AudioSetupStatus,
    ): AudioSetupStatus {
        if (dhikrsWithAudio.isEmpty()) return AudioSetupStatus.Empty
        if (dhikrsWithAudio.all { it.isDownloaded }) return AudioSetupStatus.Complete

        return when (currentStatus) {
            AudioSetupStatus.Downloading,
            AudioSetupStatus.PartialFailure -> currentStatus
            AudioSetupStatus.Complete,
            AudioSetupStatus.Empty,
            AudioSetupStatus.Idle -> AudioSetupStatus.Idle
        }
    }

    // --- Language Step ---

    fun onLanguageSelected(tag: String) {
        if (tag == _uiState.value.languageTag) return
        _uiState.update { it.copy(languageTag = tag) }
        // Applies immediately; on pre-T devices this recreates the activity.
        // The step index survives in SavedStateHandle and the ViewModel itself
        // outlives the recreation, so the flow resumes on this same scene.
        AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(tag))
    }

    private fun currentLanguageTag(): String {
        val tags = AppCompatDelegate.getApplicationLocales().toLanguageTags()
        return when {
            tags.startsWith("ar") -> "ar"
            tags.startsWith("ml") -> "ml"
            else -> "en"
        }
    }

    // --- Account Step ---

    fun onContinueWithEmail() {
        _uiState.update {
            it.copy(showAuthSheet = true, authError = null)
        }
    }

    fun onDismissAuthSheet() {
        if (_uiState.value.isAuthenticating) return
        _uiState.update { it.copy(showAuthSheet = false, authError = null) }
    }

    fun onAuthModeChanged(mode: AuthSheetMode) {
        _uiState.update { it.copy(authMode = mode, authError = null) }
    }

    fun onAuthEmailChanged(email: String) {
        _uiState.update { it.copy(authEmail = email, authError = null) }
    }

    fun onAuthPasswordChanged(password: String) {
        _uiState.update { it.copy(authPassword = password, authError = null) }
    }

    fun onAuthSubmit() {
        val state = _uiState.value
        if (state.isAuthenticating) return
        val email = state.authEmail.trim()
        val password = state.authPassword
        if (email.isBlank() || !email.contains('@') || password.isBlank()) {
            _uiState.update { it.copy(authError = AUTH_ERROR_FIELDS) }
            return
        }
        _uiState.update { it.copy(isAuthenticating = true, authError = null) }
        viewModelScope.launch {
            val result = when (state.authMode) {
                AuthSheetMode.SignIn -> authRepository.login(email, password, VerificationOrigin.Onboarding)
                AuthSheetMode.CreateAccount -> authRepository.register(email, password, VerificationOrigin.Onboarding)
            }
            when (result) {
                is AuthResult.Success -> {
                    val usesReturningUserFlow = state.authMode == AuthSheetMode.SignIn
                    savedStateHandle[KEY_RETURNING_USER_FLOW] = usesReturningUserFlow
                    _uiState.update {
                        it.copy(
                            isAuthenticating = false,
                            showAuthSheet = false,
                            authPassword = "",
                            usesReturningUserFlow = usesReturningUserFlow,
                        )
                    }
                    if (_uiState.value.currentStep == ACCOUNT_STEP_INDEX) {
                        nextStep()
                    }
                }
                is AuthResult.Error -> {
                    _uiState.update {
                        it.copy(isAuthenticating = false, authError = result.message)
                    }
                }
                is AuthResult.VerificationRequired -> {
                    awaitingVerificationMode = state.authMode
                    _uiState.update {
                        it.copy(
                            isAuthenticating = false,
                            showAuthSheet = false,
                            authPassword = "",
                        )
                    }
                    _verificationNavigationEvents.trySend(Unit)
                }
            }
        }
    }

    fun onContinueAsGuest() {
        savedStateHandle[KEY_RETURNING_USER_FLOW] = false
        _uiState.update { it.copy(showAuthSheet = false, usesReturningUserFlow = false) }
        if (_uiState.value.currentStep == ACCOUNT_STEP_INDEX) {
            nextStep()
        }
    }

    fun onContinueSignedIn() {
        savedStateHandle[KEY_RETURNING_USER_FLOW] = true
        _uiState.update { it.copy(usesReturningUserFlow = true) }
        if (_uiState.value.currentStep == ACCOUNT_STEP_INDEX) {
            nextStep()
        }
    }

    // --- Name Step ---

    fun onNameChanged(name: String) {
        _uiState.update { it.copy(userName = name) }
    }

    fun onFirstGoalCountChanged(count: Int) {
        _uiState.update { it.copy(firstGoalCount = FirstGoalPresets.clampCount(count)) }
    }

    private fun setStep(step: Int) {
        savedStateHandle[KEY_CURRENT_STEP] = step
        _uiState.update { it.copy(currentStep = step) }
    }

    fun nextStep() {
        val state = _uiState.value
        val current = state.currentStep
        if (current == AUDIO_STEP_INDEX && state.audioSetupStatus == AudioSetupStatus.Downloading) return

        if (current == NAME_STEP_INDEX) {
            viewModelScope.launch {
                userPreferences.setUserName(_uiState.value.userName.trim())
            }
        }

        val next = nextStepIndex(current, state.usesReturningUserFlow)
        if (next != null) {
            setStep(next)
        } else if (state.usesReturningUserFlow && current == AUDIO_STEP_INDEX) {
            completeReturningUserOnboarding()
        }
    }

    fun previousStep() {
        val state = _uiState.value
        previousStepIndex(state.currentStep, state.usesReturningUserFlow)?.let(::setStep)
    }

    fun goToStep(step: Int) {
        if (step in 0 until TOTAL_STEPS) {
            setStep(step)
        }
    }

    // --- Audio Step ---

    fun onDownloadAudio() {
        viewModelScope.launch {
            val state = _uiState.value
            if (state.audioSetupStatus == AudioSetupStatus.Downloading) return@launch

            val pendingDhikrs = state.dhikrsWithAudio.filter { !it.isDownloaded }

            when {
                state.dhikrsWithAudio.isEmpty() -> {
                    _uiState.update { it.copy(audioSetupStatus = AudioSetupStatus.Empty) }
                    return@launch
                }
                pendingDhikrs.isEmpty() -> {
                    _uiState.update { it.copy(audioSetupStatus = AudioSetupStatus.Complete) }
                    return@launch
                }
            }

            _uiState.update { it.copy(audioSetupStatus = AudioSetupStatus.Downloading) }
            val success = dhikrRepository.downloadSelectedAudio(pendingDhikrs)
            _uiState.update {
                it.copy(
                    audioSetupStatus = if (success) {
                        AudioSetupStatus.Complete
                    } else {
                        AudioSetupStatus.PartialFailure
                    },
                )
            }
        }
    }

    fun onRetryAudioDownload() {
        onDownloadAudio()
    }

    fun onSkipAudioDownload() {
        nextStep()
    }

    // --- Location Step ---

    fun onLocationQueryChanged(query: String) {
        _uiState.update {
            it.copy(
                locationQuery = query,
                locationSearchResults = emptyList(),
                isSearchingLocation = false,
                selectedCity = null,
            )
        }
        searchCity(query = query, debounce = true)
    }

    fun onSearchCity() {
        _uiState.update { it.copy(selectedCity = null) }
        searchCity(query = _uiState.value.locationQuery, debounce = false)
    }

    private fun searchCity(query: String, debounce: Boolean) {
        val trimmedQuery = query.trim()
        locationSearchJob?.cancel()

        if (trimmedQuery.length < MIN_LOCATION_QUERY_LENGTH) {
            _uiState.update {
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
            val stateBeforeSearch = _uiState.value
            if (stateBeforeSearch.locationQuery.trim() != trimmedQuery || stateBeforeSearch.selectedCity != null) {
                return@launch
            }
            _uiState.update { state ->
                if (state.locationQuery.trim() == trimmedQuery && state.selectedCity == null) {
                    state.copy(isSearchingLocation = true, locationSearchResults = emptyList())
                } else {
                    state
                }
            }
            val results = prayerTimeRepository.searchCity(trimmedQuery)
            _uiState.update { state ->
                if (state.locationQuery.trim() == trimmedQuery && state.selectedCity == null) {
                    state.copy(isSearchingLocation = false, locationSearchResults = results)
                } else {
                    state
                }
            }
        }
    }

    fun onCitySelected(city: CityResult) {
        locationSearchJob?.cancel()
        _uiState.update {
            it.copy(
                selectedCity = city,
                locationSearchResults = emptyList(),
                isSearchingLocation = false,
                locationQuery = city.displayName,
            )
        }
        viewModelScope.launch {
            userPreferences.setLocation(city.latitude, city.longitude, city.displayName)
            refreshPrayerPreview()
        }
    }

    fun onGpsLocationObtained(latitude: Double, longitude: Double) {
        locationSearchJob?.cancel()
        _uiState.update {
            it.copy(
                isGettingGpsLocation = true,
                isSearchingLocation = false,
                locationSearchResults = emptyList(),
            )
        }
        viewModelScope.launch {
            val cityName = prayerTimeRepository.reverseGeocode(latitude, longitude)
                .ifBlank { "Current Location" }
            val city = CityResult(
                name = cityName,
                displayName = cityName,
                latitude = latitude,
                longitude = longitude,
            )
            userPreferences.setLocation(latitude, longitude, cityName)
            _uiState.update {
                it.copy(
                    isGettingGpsLocation = false,
                    selectedCity = city,
                    locationQuery = cityName,
                    locationSearchResults = emptyList(),
                )
            }
            refreshPrayerPreview()
        }
    }

    // --- Prayer Calculation ---

    fun onShowCalcMethodSheet() {
        _uiState.update { it.copy(showCalcMethodSheet = true) }
    }

    fun onDismissCalcMethodSheet() {
        _uiState.update { it.copy(showCalcMethodSheet = false) }
    }

    fun onCalculationMethodSelected(method: CalculationMethodPref) {
        _uiState.update { it.copy(calculationMethod = method) }
        viewModelScope.launch {
            userPreferences.setCalculationMethod(method.name)
            refreshPrayerPreview()
        }
    }

    fun onMadhabSelected(madhab: MadhabPref) {
        _uiState.update { it.copy(madhab = madhab) }
        viewModelScope.launch {
            userPreferences.setMadhab(madhab.name)
            refreshPrayerPreview()
        }
    }

    private fun refreshPrayerPreview() {
        val state = _uiState.value
        val city = state.selectedCity
        val times = city?.let {
            runCatching {
                prayerTimeRepository.getPrayerTimes(
                    latitude = it.latitude,
                    longitude = it.longitude,
                    method = state.calculationMethod,
                    madhab = state.madhab,
                )
            }.getOrNull()
        }
        val formatter = SimpleDateFormat("h:mm a", Locale.getDefault())
        val rows = if (times == null) {
            emptyList()
        } else {
            listOfNotNull(
                times.fajr?.let { PrayerPreviewRow(Prayer.FAJR, formatter.format(it)) },
                times.dhuhr?.let { PrayerPreviewRow(Prayer.DHUHR, formatter.format(it)) },
                times.asr?.let { PrayerPreviewRow(Prayer.ASR, formatter.format(it)) },
                times.maghrib?.let { PrayerPreviewRow(Prayer.MAGHRIB, formatter.format(it)) },
                times.isha?.let { PrayerPreviewRow(Prayer.ISHA, formatter.format(it)) },
            )
        }

        // Resolve the reminder-preset chips too, so the reminder scene can show
        // the concrete time each moment lands on (falls back gracefully when
        // the user skipped location).
        val zone = ZoneId.systemDefault()
        fun Date?.toLocalTime(): LocalTime? = this?.toInstant()?.atZone(zone)?.toLocalTime()
        val fajr = times?.fajr.toLocalTime()
        val asr = times?.asr.toLocalTime()
        val maghrib = times?.maghrib.toLocalTime()
        val timeFormatter = DateTimeFormatter.ofPattern("h:mm a", Locale.getDefault())
        val presetTimes = OnboardingReminderPreset.entries.associateWith { preset ->
            OnboardingReminderTimes.resolve(preset, fajr, asr, maghrib).format(timeFormatter)
        }

        _uiState.update { it.copy(prayerPreview = rows, reminderPresetTimes = presetTimes) }
    }

    // --- Notifications Step ---

    fun onNotificationPermissionResult(granted: Boolean) {
        _uiState.update { it.copy(notificationsGranted = granted) }
    }

    fun refreshReminderReliability() {
        _uiState.update {
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
        _uiState.update { it.copy(showOemBatteryDialog = true) }
    }

    fun onDismissOemBatteryDialog() {
        _uiState.update { it.copy(showOemBatteryDialog = false) }
    }

    // --- Reminder Presets Step ---

    fun onReminderPresetToggled(preset: OnboardingReminderPreset) {
        _uiState.update { state ->
            val selected = state.selectedReminderPresets
            state.copy(
                selectedReminderPresets = if (preset in selected) selected - preset else selected + preset,
            )
        }
    }

    // --- Completion ---

    fun completeOnboarding() {
        if (_uiState.value.isCreatingFirstGoal) return
        _uiState.update { it.copy(isCreatingFirstGoal = true) }
        viewModelScope.launch {
            val state = _uiState.value
            if (state.userName.isNotBlank()) {
                userPreferences.setUserName(state.userName.trim())
            }

            // Create the first goal before flipping the onboarded flag so a crash
            // between the two only re-runs onboarding rather than stranding the
            // user onboarded-but-goalless.
            val firstGoalId = createFirstGoalOrNull(
                presetId = state.selectedPresetId,
                targetCount = state.firstGoalCount,
                reminderPresets = state.selectedReminderPresets,
            )

            userPreferences.setOnboarded(true)
            _uiState.update { it.copy(firstGoalId = firstGoalId, isComplete = true) }
        }
    }

    private fun completeReturningUserOnboarding() {
        if (_uiState.value.isCreatingFirstGoal) return
        _uiState.update { it.copy(isCreatingFirstGoal = true) }
        viewModelScope.launch {
            userPreferences.setOnboarded(true)
            _uiState.update { it.copy(firstGoalId = null, isComplete = true) }
        }
    }

    private suspend fun createFirstGoalOrNull(
        presetId: String?,
        targetCount: Int,
        reminderPresets: Set<OnboardingReminderPreset>,
    ): AwradId? {
        val preset = FirstGoalPresets.byId(presetId) ?: return null
        val dhikrs = allDhikrs.ifEmpty { dhikrRepository.getAllDhikrs().first() }
        val dhikr = dhikrs.firstOrNull { it.catalogKey == preset.builtInCatalogKey } ?: return null
        val command = CreateGoalCommand(
            dhikrId = dhikr.id,
            startDate = LocalDate.now(),
            schedule = ScheduleSpec.Daily,
            timing = TimingSpec.Anytime,
            countPolicy = CountPolicy(targetCount = FirstGoalPresets.clampCount(targetCount)),
            reminders = reminderPolicies(reminderPresets),
        )
        return when (val result = createGoalUseCase(command)) {
            is CreateGoalResult.Created -> {
                val created = result.createdGoal
                if (created.goal.reminders.any { it.enabled }) {
                    runCatching {
                        reminderScheduler.scheduleForGoal(
                            created.goal.copy(
                                reminders = created.goal.reminders.map { it.copy(goalId = created.id) },
                            ),
                        )
                    }
                }
                created.id
            }
            is CreateGoalResult.Invalid -> null
        }
    }

    /**
     * Resolve the chosen reminder presets to concrete fixed-time reminders.
     * Prayer-anchored presets use today's prayer times for the saved location;
     * without a location they fall back to fixed defaults. Reminders remain
     * editable per-goal after onboarding.
     */
    private suspend fun reminderPolicies(
        presets: Set<OnboardingReminderPreset>,
    ): List<ReminderPolicy> {
        if (presets.isEmpty()) return emptyList()
        val times = todayPrayerTimesOrNull()
        val zone = ZoneId.systemDefault()
        fun Date?.toLocalTime(): LocalTime? = this?.toInstant()?.atZone(zone)?.toLocalTime()
        val fajr = times?.fajr.toLocalTime()
        val asr = times?.asr.toLocalTime()
        val maghrib = times?.maghrib.toLocalTime()
        return presets
            .sortedBy { it.ordinal }
            .map { preset ->
                val time = OnboardingReminderTimes.resolve(preset, fajr, asr, maghrib)
                ReminderPolicy.FixedTime(hour = time.hour, minute = time.minute)
            }
    }

    private suspend fun todayPrayerTimesOrNull(): PrayerTimes? {
        val state = _uiState.value
        val latitude = state.selectedCity?.latitude ?: userPreferences.latitude.first() ?: return null
        val longitude = state.selectedCity?.longitude ?: userPreferences.longitude.first() ?: return null
        return runCatching {
            prayerTimeRepository.getPrayerTimes(
                latitude = latitude,
                longitude = longitude,
                method = state.calculationMethod,
                madhab = state.madhab,
            )
        }.getOrNull()
    }

    private fun calculationMethodFrom(raw: String): CalculationMethodPref =
        CalculationMethodPref.entries.firstOrNull { it.name == raw } ?: CalculationMethodPref.KARACHI

    private fun madhabFrom(raw: String): MadhabPref =
        MadhabPref.entries.firstOrNull { it.name == raw } ?: MadhabPref.SHAFI
}

/** Sentinel understood by the account scene: blank-field validation error. */
internal const val AUTH_ERROR_FIELDS = "__fields__"
