package app.awrad.awrad_dhikrgoalstracker.ui.screens.home

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.CalculationMethodPref
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.MadhabPref
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.NextPrayer
import app.awrad.awrad_dhikrgoalstracker.data.repository.PrayerTimeRepository
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.ProgressSummary
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdPart
import app.awrad.awrad_dhikrgoalstracker.data.repository.WirdLibraryRepository
import app.awrad.awrad_dhikrgoalstracker.data.wird.WirdEngine
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressUseCase
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.notification.WirdReminderScheduler
import kotlinx.coroutines.flow.first
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.DateUtils
import app.awrad.awrad_dhikrgoalstracker.util.GoalDayActivity
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOr
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

data class HomeUiState(
    val greeting: String = "",
    val primaryDate: String = "",
    val secondaryDate: String = "",
    val userName: String = "",
    val overallProgress: Float = 0f,
    val activeGoals: List<GoalWithProgress> = emptyList(),
    val suggestedGoal: GoalWithProgress? = null,
    val categoryDhikrCounts: Map<DhikrCategory, Int> = emptyMap(),
    val effectiveDate: LocalDate = LocalDate.now(),
    val isLoading: Boolean = true,
)

data class PrayerCardState(
    val isVisible: Boolean = false,
    val nextPrayer: NextPrayer? = null,
    val cityName: String = "",
    val prayers: List<PrayerTimePoint> = emptyList(),
    val fajrMillis: Long? = null,
    val sunriseMillis: Long? = null,
    val maghribMillis: Long? = null,
    val ishaMillis: Long? = null,
)

data class PrayerTimePoint(
    val name: String,
    val timeFormatted: String,
    val isComplete: Boolean = false,
    val isNext: Boolean = false,
)

data class GoalWithProgress(
    val goal: Goal,
    val dhikrArabic: String = "",
    val dhikrTransliteration: String = "",
    val dhikrTranslation: String = "",
    val dhikrCategory: DhikrCategory = DhikrCategory.GENERAL,
    val todayCount: Long = 0,
    val dailyTarget: Int = 0,
    val dailyProgress: Float = 0f,
    val recentDays: List<GoalDayActivity> = emptyList(),
    /** Consecutive scheduled days meeting the streak threshold, ending today or yesterday. */
    val streakDays: Int = 0,
    val slots: List<GoalSlotProgress> = emptyList(),
)

/** Today's progress for one of a goal's slots (e.g. "After Fajr 45 / 100"). */
data class GoalSlotProgress(
    val slot: GoalSlot,
    val count: Long,
) {
    val target: Int get() = slot.targetCount ?: 0
    val progress: Float get() = if (target > 0) (count.toFloat() / target).coerceIn(0f, 1f) else 0f
    val isComplete: Boolean get() = target > 0 && count >= target
}

/**
 * A single wird shown in the Home "Wirds" section. [part] is the portion the "Read" action opens
 * (today's active part when scheduled, otherwise the collection's first part so featured wirds are
 * always openable).
 */
data class WirdHomeCard(
    val wird: Wird,
    val part: WirdPart?,
    val occasion: WirdOccasion?,
    val progress: ProgressSummary,
    val week: List<WirdEngine.DayActivity>,
    val isActiveToday: Boolean,
)

/** State for the Home "Wirds" section: scheduled-today list + curated featured list. */
data class WirdHomeUi(
    val today: List<WirdHomeCard> = emptyList(),
    val featured: List<WirdHomeCard> = emptyList(),
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class HomeViewModel @Inject constructor(
    private val goalRepository: GoalRepository,
    private val dhikrRepository: DhikrRepository,
    private val userPreferences: UserPreferences,
    private val prayerTimeRepository: PrayerTimeRepository,
    private val dateProvider: DateProvider,
    private val wirdLibraryRepository: WirdLibraryRepository,
    private val wirdReminderScheduler: WirdReminderScheduler,
    private val wirdEngine: WirdEngine,
    private val goalProgressUseCase: GoalProgressUseCase,
    private val reminderScheduler: ReminderScheduler,
    @ApplicationContext private val context: Context,
) : ViewModel() {

    /**
     * Persists a GPS-detected location so the Home prayer card can appear. Mirrors the Settings
     * location flow: reverse-geocode a city label, save it, then reschedule prayer-anchored reminders.
     */
    fun onLocationDetected(latitude: Double, longitude: Double) {
        viewModelScope.launch {
            val cityName = prayerTimeRepository.reverseGeocode(latitude, longitude)
                .ifBlank { "Current Location" }
            userPreferences.setLocation(latitude, longitude, cityName)
            reminderScheduler.rescheduleAll()
        }
    }

    val uiState: StateFlow<HomeUiState> = combine(
        dateProvider.effectiveToday,
        userPreferences.calendarSystem,
    ) { today, calSystemStr ->
        today to calSystemStr
    }.flatMapLatest { (today, calSystemStr) ->
        val calSystem = try {
            CalendarSystem.valueOf(calSystemStr)
        } catch (e: IllegalArgumentException) {
            CalendarSystem.GREGORIAN
        }
        val effectiveDate = today.toLocalDateOr(LocalDate.now())
        combine(
            userPreferences.userName,
            goalRepository.getActiveGoals(),
            dhikrRepository.getAllDhikrs(),
            goalRepository.getDailyCountsByGoal(),
            goalRepository.getDailySlotCountsByGoal(),
        ) { userName, activeGoals, allDhikrs, dailyCountsByGoal, dailySlotCountsByGoal ->

            val goalsWithProgress = activeGoals
                .filter { goalProgressUseCase.isDueOn(it, effectiveDate) }
                .map { goal ->
                    val dhikr = allDhikrs.find { it.id == goal.dhikrId }
                    val dailyCounts = dailyCountsByGoal[goal.id].orEmpty()
                    val dailySlotCounts = dailySlotCountsByGoal[goal.id].orEmpty()
                    val progressSummary = goalProgressUseCase.summarize(goal, dailyCounts, effectiveDate)
                    GoalWithProgress(
                        goal = goal,
                        dhikrArabic = dhikr?.arabic ?: "",
                        dhikrTransliteration = dhikr?.transliteration ?: "",
                        dhikrTranslation = dhikr?.title ?: "",
                        dhikrCategory = dhikr?.category ?: DhikrCategory.GENERAL,
                        todayCount = progressSummary.progressCount,
                        dailyTarget = progressSummary.targetCount,
                        dailyProgress = progressSummary.progress,
                        recentDays = GoalProgressCalculator.recentActivity(
                            goal = goal,
                            dailyCounts = dailyCounts,
                            today = effectiveDate,
                            dailySlotCounts = dailySlotCounts,
                        ),
                        streakDays = GoalProgressCalculator.calculateStreakWithCounts(
                            dailyCounts = dailyCounts,
                            today = effectiveDate,
                            dailyTarget = GoalProgressCalculator.getTargetCount(goal),
                            minimumStreakCount = goal.minimumStreakCount,
                            goal = goal,
                        ).currentStreak,
                        slots = goal.slots
                            .filter { it.isActive }
                            .sortedBy { it.sortOrder }
                            .map { slot ->
                                val slotCount = dailySlotCounts[effectiveDate]?.get(slot.id) ?: 0L
                                GoalSlotProgress(slot = slot, count = slotCount)
                            },
                    )
                }

            val overallProgress = if (goalsWithProgress.isEmpty()) 0f
            else goalsWithProgress.map { it.dailyProgress }.average().toFloat()

            val categoryCounts = allDhikrs.groupBy { it.category }
                .mapValues { it.value.size }

            val suggested = goalsWithProgress.firstOrNull { it.dailyProgress < 1f }
            // Surface the suggested goal first so it leads Today's Goals and the hero button.
            val orderedGoals = if (suggested != null) {
                listOf(suggested) + goalsWithProgress.filter { it !== suggested }
            } else {
                goalsWithProgress
            }

            HomeUiState(
                greeting = DateUtils.getGreetingForTimeOfDay(context),
                primaryDate = DateUtils.getPrimaryDate(calSystem, effectiveDate),
                secondaryDate = DateUtils.getSecondaryDate(calSystem, effectiveDate),
                userName = userName,
                overallProgress = overallProgress,
                activeGoals = orderedGoals,
                suggestedGoal = suggested,
                categoryDhikrCounts = categoryCounts,
                effectiveDate = effectiveDate,
                isLoading = false,
            )
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = HomeUiState(),
    )

    val prayerCardState: StateFlow<PrayerCardState> = combine(
        userPreferences.latitude,
        userPreferences.longitude,
        userPreferences.cityName,
        userPreferences.calculationMethod,
        userPreferences.madhab,
    ) { lat, lng, cityName, methodStr, madhabStr ->
        if (lat == null || lng == null) return@combine PrayerCardState()
        val method = try {
            CalculationMethodPref.valueOf(methodStr)
        } catch (e: IllegalArgumentException) {
            CalculationMethodPref.KARACHI
        }
        val madhab = try {
            MadhabPref.valueOf(madhabStr)
        } catch (e: IllegalArgumentException) {
            MadhabPref.SHAFI
        }
        val prayerTimes = prayerTimeRepository.getPrayerTimes(lat, lng, method, madhab)
        val next = prayerTimeRepository.getNextPrayer(prayerTimes)
        val prayers = prayerTimeRepository.getAllPrayerTimes(prayerTimes)
            .filterNot { (name, _) -> name == "Sunrise" }
        val nextIndex = prayers.indexOfFirst { (name, _) -> name == next?.name }
        PrayerCardState(
            isVisible = true,
            nextPrayer = next,
            cityName = cityName,
            fajrMillis = prayerTimes.fajr?.time,
            sunriseMillis = prayerTimes.sunrise?.time,
            maghribMillis = prayerTimes.maghrib?.time,
            ishaMillis = prayerTimes.isha?.time,
            prayers = prayers.mapIndexed { index, (name, timeFormatted) ->
                PrayerTimePoint(
                    name = name,
                    timeFormatted = timeFormatted,
                    isComplete = next == null || (nextIndex >= 0 && index < nextIndex),
                    isNext = name == next?.name,
                )
            },
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = PrayerCardState(),
    )

    /** Bundled catalog slugs (loaded once from assets) — identifies the "featured" collections. */
    private val bundledSlugs: StateFlow<Set<String>> = flow {
        emit(wirdLibraryRepository.bundledLibrarySlugs())
    }.stateIn(viewModelScope, SharingStarted.Eagerly, emptySet())

    /** Wirds for the Home section: scheduled-today (incomplete first) + curated featured library. */
    val wirdHome: StateFlow<WirdHomeUi> = dateProvider.effectiveToday.flatMapLatest { today ->
        val date = WirdEngine.parseDateKeyOrNull(today) ?: LocalDate.now()
        combine(
            wirdLibraryRepository.observeWirds(),
            wirdLibraryRepository.observeSessionsOnDate(today),
            bundledSlugs,
        ) { wirds, sessions, catalogSlugs ->
            val cards = wirds.map { wird ->
                val active = wirdEngine.activeParts(wird, date)
                fun sessionFor(part: WirdPart) = sessions.firstOrNull {
                    it.wirdID == wird.id &&
                        it.partID == part.id &&
                        it.occasionKey == wird.occasionFor(part).key
                }
                val part = active.firstOrNull { sessionFor(it)?.isComplete != true }
                    ?: active.firstOrNull()
                    ?: wird.parts.firstOrNull()
                val progress = wirdEngine.aggregateProgress(wird, date) { p ->
                    sessionFor(p)
                }
                WirdHomeCard(
                    wird = wird,
                    part = part,
                    occasion = part?.let { wird.occasionFor(it) },
                    progress = progress,
                    week = wirdLibraryRepository.weekActivity(wird, today),
                    isActiveToday = active.isNotEmpty(),
                )
            }
            // Featured = the bundled catalog (by slug, so a reminder-flipped isCustom built-in still
            // qualifies); fall back to any non-custom wird if the catalog hasn't loaded yet.
            val featured = cards
                .filter {
                    if (catalogSlugs.isEmpty()) !it.wird.isCustom else it.wird.slug in catalogSlugs
                }
                .sortedBy { it.wird.sortOrder }
            WirdHomeUi(
                today = cards
                    .filter { it.isActiveToday }
                    .sortedBy { it.progress.progress >= 1f },
                featured = featured,
            )
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = WirdHomeUi(),
    )

    init {
        viewModelScope.launch {
            dhikrRepository.initializeBuiltInDhikrs()
            wirdLibraryRepository.seedLibraryWirds()
            // Re-arm wird reminders (alarms are cleared on reboot / process death).
            wirdLibraryRepository.observeWirds().first().forEach { wird ->
                if (wird.reminders.any { it.enabled }) wirdReminderScheduler.schedule(wird)
            }
        }
    }
}
