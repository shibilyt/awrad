package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import java.time.LocalDate
import java.util.UUID

import app.awrad.awrad_dhikrgoalstracker.testId

import androidx.lifecycle.SavedStateHandle
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.CountEntry
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.UserTag
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ValidatedGoal
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ValidatedGoalUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressUseCase
import app.awrad.awrad_dhikrgoalstracker.notification.GoalReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
import app.awrad.awrad_dhikrgoalstracker.service.OwnedAudioAvailability
import app.awrad.awrad_dhikrgoalstracker.service.StagedOwnedAudio
import app.awrad.awrad_dhikrgoalstracker.util.EffectiveTodayProvider
import app.awrad.awrad_dhikrgoalstracker.util.StreakDayStatus
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class GoalDetailViewModelTest {

    private val dispatcher = StandardTestDispatcher()
    private val today = LocalDate.parse("2026-05-27")

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `exposes today count and current streak from daily counts`() = runTest(dispatcher) {
        val viewModel = viewModel(
            goal = dailyGoal(),
            dailyCounts = mapOf(
                today to 120L,
                today.minusDays(1) to 120L,
                today.minusDays(2) to 120L,
            ),
        )
        val state = collectState(viewModel)

        assertEquals(120L, state.todayCount)
        assertEquals(3, state.streakInfo?.currentStreak)
    }

    @Test
    fun `today count below target stays raw and does not extend the streak`() = runTest(dispatcher) {
        val viewModel = viewModel(
            goal = dailyGoal(),
            dailyCounts = mapOf(
                today to 22L,
                today.minusDays(1) to 120L,
                today.minusDays(2) to 120L,
            ),
        )
        val state = collectState(viewModel)

        // todayCount is the raw count for today, not the target-scoped progress.
        assertEquals(22L, state.todayCount)
        // 22 is below the 100-count daily target, so the streak is broken today.
        assertEquals(0, state.streakInfo?.currentStreak)
    }

    @Test
    fun `recent activity spans the 42 day strip with today last`() = runTest(dispatcher) {
        val viewModel = viewModel(
            goal = dailyGoal(),
            dailyCounts = mapOf(today to 22L),
        )
        val state = collectState(viewModel)

        assertEquals(42, state.recentDays.size)
        assertEquals(today.minusDays(41), state.recentDays.first().date)
        assertEquals(today, state.recentDays.last().date)
        assertTrue(state.recentDays.last().isToday)
        // A day with some activity below target is PARTIAL, not complete or inactive.
        assertEquals(StreakDayStatus.PARTIAL, state.recentDays.last().status)
    }

    @Test
    fun `archive pauses the goal and cancels reminders`() = runTest(dispatcher) {
        val scheduler = FakeGoalReminderScheduler()
        val repository = GoalDetailFakeGoalRepository(dailyGoal())
        val viewModel = viewModel(repository = repository, scheduler = scheduler)
        collectState(viewModel)

        viewModel.archiveGoal(dailyGoal())
        advanceUntilIdle()

        assertEquals(1, repository.lifecycleUpdates.size)
        assertFalse(repository.lifecycleUpdates.single().goal.isActive)
        assertEquals(listOf(testId(1)), scheduler.cancelledGoalIds)
        assertTrue(scheduler.scheduledGoals.isEmpty())
    }

    @Test
    fun `restore reactivates the goal and reschedules reminders`() = runTest(dispatcher) {
        val scheduler = FakeGoalReminderScheduler()
        val repository = GoalDetailFakeGoalRepository(pausedGoal())
        val viewModel = viewModel(repository = repository, scheduler = scheduler)
        collectState(viewModel)

        viewModel.restoreGoal(pausedGoal())
        advanceUntilIdle()

        assertEquals(1, repository.lifecycleUpdates.size)
        assertTrue(repository.lifecycleUpdates.single().goal.isActive)
        assertEquals(listOf(testId(1)), scheduler.scheduledGoals.map { it.id })
        assertTrue(scheduler.cancelledGoalIds.isEmpty())
    }

    @Test
    fun `delete removes the goal and cancels reminders`() = runTest(dispatcher) {
        val scheduler = FakeGoalReminderScheduler()
        val repository = GoalDetailFakeGoalRepository(dailyGoal())
        val viewModel = viewModel(repository = repository, scheduler = scheduler)
        collectState(viewModel)

        viewModel.deleteGoal()
        advanceUntilIdle()

        assertEquals(listOf(testId(1)), repository.deletedIds)
        assertEquals(listOf(testId(1)), scheduler.cancelledGoalIds)
    }

    private suspend fun TestScope.collectState(viewModel: GoalDetailViewModel): GoalDetailUiState {
        val collected = mutableListOf<GoalDetailUiState>()
        val job = launch { viewModel.uiState.collect { collected += it } }
        advanceUntilIdle()
        val state = collected.last()
        job.cancel()
        return state
    }

    private fun viewModel(
        goal: Goal = dailyGoal(),
        dailyCounts: Map<LocalDate, Long> = emptyMap(),
        dailySlotCounts: Map<LocalDate, Map<AwradId, Long>> = emptyMap(),
        repository: GoalDetailFakeGoalRepository = GoalDetailFakeGoalRepository(goal, dailyCounts, dailySlotCounts),
        scheduler: FakeGoalReminderScheduler = FakeGoalReminderScheduler(),
    ) = GoalDetailViewModel(
        savedStateHandle = SavedStateHandle(mapOf("goalId" to testId(1).toString())),
        goalRepository = repository,
        dhikrRepository = GoalDetailFakeDhikrRepository(),
        dateProvider = object : EffectiveTodayProvider {
            override val effectiveToday: Flow<String> = flowOf(today.toString())
        },
        goalProgressUseCase = GoalProgressUseCase(),
        scheduler = scheduler,
    )

    private fun dailyGoal() = Goal(
        id = testId(1),
        dhikrId = testId(1),
        slots = listOf(
            GoalSlot(
                id = testId(10),
                goalId = testId(1),
                slotType = GoalSlotType.ANYTIME,
                targetCount = 100,
            ),
        ),
        startDate = today.minusDays(30),
    )

    private fun pausedGoal() = dailyGoal().copy(isActive = false)
}

internal class FakeGoalReminderScheduler : GoalReminderScheduler {
    val scheduledGoals = mutableListOf<Goal>()
    val cancelledGoalIds = mutableListOf<AwradId>()

    override fun scheduleForGoal(goal: Goal) {
        scheduledGoals += goal
    }

    override fun cancelForGoal(goalId: AwradId) {
        cancelledGoalIds += goalId
    }
}

internal class GoalDetailFakeGoalRepository(
    private val goal: Goal,
    private val dailyCounts: Map<LocalDate, Long> = emptyMap(),
    private val dailySlotCounts: Map<LocalDate, Map<AwradId, Long>> = emptyMap(),
) : GoalRepository {
    val lifecycleUpdates = mutableListOf<ValidatedGoalUpdate>()
    val deletedIds = mutableListOf<AwradId>()

    override fun getActiveGoals(): Flow<List<Goal>> = flowOf(listOf(goal))
    override fun getCompletedGoals(): Flow<List<Goal>> = flowOf(emptyList())
    override fun getAllGoals(): Flow<List<Goal>> = flowOf(listOf(goal))
    override fun getGoalByIdFlow(id: AwradId): Flow<Goal?> = flowOf(goal.takeIf { it.id == id })
    override suspend fun getGoalById(id: AwradId): Goal? = goal.takeIf { it.id == id }
    override suspend fun createGoal(validatedGoal: ValidatedGoal): AwradId = unsupported()
    override suspend fun updateGoal(goal: Goal) = Unit
    override suspend fun updateGoal(validatedGoalUpdate: ValidatedGoalUpdate): Goal =
        validatedGoalUpdate.goal
    override suspend fun updateGoalLifecycle(validatedGoalUpdate: ValidatedGoalUpdate): Goal {
        lifecycleUpdates += validatedGoalUpdate
        return validatedGoalUpdate.goal
    }
    override suspend fun updateGoalSchedule(validatedGoalUpdate: ValidatedGoalUpdate): Goal =
        validatedGoalUpdate.goal
    override suspend fun updateGoalReminders(validatedGoalUpdate: ValidatedGoalUpdate): Goal =
        validatedGoalUpdate.goal
    override suspend fun deleteGoal(id: AwradId) {
        deletedIds += id
    }
    override suspend fun addCount(
        goalId: AwradId,
        slotId: AwradId?,
        count: Long,
        date: String?,
    ): Long = unsupported()
    override fun getTotalCountForDate(goalId: AwradId, date: String): Flow<Long?> = flowOf(0)
    override fun getTotalCount(goalId: AwradId): Flow<Long?> = flowOf(0)
    override suspend fun getCountForSlotAndDate(goalId: AwradId, slotId: AwradId, date: String): Long = 0
    override fun getProgressMapForDate(date: String): Flow<Map<AwradId, Long>> = flowOf(emptyMap())
    override fun getHistoryForGoal(goalId: AwradId): Flow<List<CountEntry>> = flowOf(emptyList())
    override fun getDailyCountsByGoal(): Flow<Map<AwradId, Map<LocalDate, Long>>> =
        flowOf(mapOf(goal.id to dailyCounts))
    override fun getDailySlotCountsByGoal(): Flow<Map<AwradId, Map<LocalDate, Map<AwradId, Long>>>> =
        flowOf(emptyMap())
    override fun getDailySlotCountsForGoal(goalId: AwradId): Flow<Map<LocalDate, Map<AwradId, Long>>> =
        flowOf(dailySlotCounts)
    override suspend fun getDailyCountsForGoalsInRange(
        goalIds: List<AwradId>,
        startDate: LocalDate,
        endDate: LocalDate,
    ): Map<AwradId, Map<LocalDate, Long>> = emptyMap()
    override suspend fun getDailySlotCountsForGoalsInRange(
        goalIds: List<AwradId>,
        startDate: LocalDate,
        endDate: LocalDate,
    ): Map<AwradId, Map<LocalDate, Map<AwradId, Long>>> = emptyMap()
    override suspend fun getTotalCountsForGoals(goalIds: List<AwradId>): Map<AwradId, Long> = emptyMap()
    override suspend fun getSlotCountsForGoalAndDate(goalId: AwradId, date: String): Map<AwradId, Long> =
        emptyMap()
    override suspend fun getTotalCountBetween(goalId: AwradId, startDate: String, endDate: String): Long = 0
    override suspend fun getActiveGoalsWithNotifications(): List<Goal> =
        listOf(goal).filter { it.notificationEnabled }
    override suspend fun deleteAllProgress() = unsupported()
    override suspend fun deleteAllGoalsAndProgress() = unsupported()
    override fun getActiveGoalsByDhikrId(dhikrId: AwradId): Flow<List<Goal>> =
        flowOf(listOf(goal).filter { it.dhikrId == dhikrId })
    override fun getDailyCountsForGoal(goalId: AwradId): Flow<Map<LocalDate, Long>> =
        flowOf(dailyCounts)

    private fun unsupported(): Nothing = error("Not needed for GoalDetailViewModelTest")
}

internal class GoalDetailFakeDhikrRepository : DhikrRepository {
    private val dhikr = Dhikr(
        id = testId(1),
        title = "Istighfar",
        arabic = "Astaghfirullah",
        transliteration = "Istighfar",
        translation = "Forgiveness",
        audioUrl = null,
        audioFileName = null,
        category = DhikrCategory.FORGIVENESS,
    )
    private val progress = MutableStateFlow(DownloadProgress())

    override fun getAllDhikrs(): Flow<List<Dhikr>> = flowOf(listOf(dhikr))
    override fun getDhikrsByCategory(category: DhikrCategory): Flow<List<Dhikr>> =
        flowOf(listOf(dhikr).filter { it.category == category })
    override fun searchDhikrs(query: String): Flow<List<Dhikr>> = flowOf(listOf(dhikr))
    override suspend fun getDhikrById(id: UUID): Dhikr? = dhikr.takeIf { it.id == id }
    override suspend fun initializeBuiltInDhikrs() = Unit
    override suspend fun getDownloadableDhikrs(): List<Dhikr> = emptyList()
    override suspend fun markAsDownloaded(dhikrId: UUID, audioFileName: String) = Unit
    override suspend fun downloadAllAudio(): Boolean = true
    override suspend fun downloadSelectedAudio(dhikrs: List<Dhikr>): Boolean = true
    override suspend fun downloadDhikrAudio(dhikr: Dhikr): Boolean = true
    override fun getLibraryDownloadProgress(): StateFlow<DownloadProgress> = progress
    override suspend fun createDhikr(dhikr: Dhikr): UUID = dhikr.id
    override fun getCustomDhikrs(): Flow<List<Dhikr>> = flowOf(emptyList())
    override suspend fun updateCustomDhikr(dhikr: Dhikr): Boolean = false
    override suspend fun deleteCustomDhikr(id: UUID): Boolean = false
    override fun observeUserTags(): Flow<List<UserTag>> = flowOf(emptyList())
    override suspend fun createUserTag(rawName: String) = null
    override suspend fun renameUserTag(id: UUID, rawName: String) = null
    override suspend fun deleteUserTag(id: UUID): Boolean = false
    override suspend fun setDhikrTags(dhikrId: UUID, tagIds: Set<UUID>) = Unit
    override fun observeTagIdsForDhikr(dhikrId: UUID): Flow<Set<UUID>> = flowOf(emptySet())
    override fun observeAssignments(): Flow<Map<UUID, Set<UUID>>> = flowOf(emptyMap())
    override suspend fun getOwnedAudio(dhikrId: UUID) = null
    override fun observeOwnedAudio(dhikrId: UUID) = flowOf(null)
    override fun observeOwnedAudioByDhikrId() =
        flowOf(emptyMap<UUID, app.awrad.awrad_dhikrgoalstracker.data.model.DhikrAudioAsset>())
    override suspend fun attachOwnedAudio(
        dhikrId: UUID,
        staged: StagedOwnedAudio,
    ) = error("unused")
    override suspend fun removeOwnedAudio(dhikrId: UUID) = Unit
    override suspend fun ownedAudioAvailability(dhikrId: UUID) = OwnedAudioAvailability.MISSING
    override suspend fun cleanupOwnedAudioOrphans() = Unit
}
