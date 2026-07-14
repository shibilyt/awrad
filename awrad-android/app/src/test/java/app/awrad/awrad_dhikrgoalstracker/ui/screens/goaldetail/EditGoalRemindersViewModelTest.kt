package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import java.util.UUID

import app.awrad.awrad_dhikrgoalstracker.testId

import androidx.lifecycle.SavedStateHandle
import app.awrad.awrad_dhikrgoalstracker.data.model.CountEntry
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateError
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalRemindersCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalRemindersResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ValidatedGoal
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ValidatedGoalUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.UpdateGoalRemindersUseCase
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderSchedulingGateway
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
import java.time.LocalDate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
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
class EditGoalRemindersViewModelTest {

    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `loads existing reminders and hides unavailable reminder types`() = runTest(dispatcher) {
        val viewModel = viewModel(
            goal = goal(
                slots = listOf(slot(id = testId(10), slotType = GoalSlotType.ANYTIME)),
                reminders = listOf(
                    GoalReminder(id = testId(2), goalId = testId(1), reminderType = ReminderType.FIXED_TIME, hour = 21, minute = 5, sortOrder = 1),
                    GoalReminder(id = testId(1), goalId = testId(1), reminderType = ReminderType.FIXED_TIME, hour = 8, minute = 0, sortOrder = 0),
                ),
            ),
        )

        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals("Istighfar", state.title)
        assertFalse(state.canAddPrayerReminder)
        assertFalse(state.canAddTimeWindowReminder)
        assertEquals(listOf(testId(1), testId(2)), state.draft.reminders.mapNotNull { it.reminderId })
        assertFalse(state.isDirty)
    }

    @Test
    fun `add edit delete toggle and reorder update dirty state and validation`() = runTest(dispatcher) {
        val viewModel = viewModel(
            goal = goal(
                slots = listOf(
                    slot(id = testId(10), slotType = GoalSlotType.TIME_WINDOW),
                    slot(id = testId(11), slotType = GoalSlotType.PRAYER),
                ),
                reminders = listOf(
                    GoalReminder(id = testId(1), goalId = testId(1), reminderType = ReminderType.FIXED_TIME, hour = 8, minute = 0),
                ),
            ),
        )
        advanceUntilIdle()

        viewModel.onAddReminder(ReminderType.TIME_WINDOW_START)
        val windowDraftId = viewModel.uiState.value.draft.reminders.last().draftId
        viewModel.onTargetChange(windowDraftId, testId(10))
        viewModel.onToggleReminder(windowDraftId, false)
        viewModel.onMoveReminder(windowDraftId, -1)
        val fixedDraftId = viewModel.uiState.value.draft.reminders.last().draftId
        viewModel.onHourChange(fixedDraftId, "25")

        val invalid = viewModel.uiState.value
        assertTrue(invalid.isDirty)
        assertTrue(invalid.validationErrors.contains(GoalUpdateError.InvalidReminder))
        assertFalse(invalid.canSave)

        viewModel.onHourChange(fixedDraftId, "7")
        val valid = viewModel.uiState.value
        assertTrue(valid.canSave)
        assertEquals(ReminderType.TIME_WINDOW_START, valid.draft.reminders.first().reminderType)
        assertFalse(valid.draft.reminders.first().enabled)

        viewModel.onDeleteReminder(windowDraftId)
        assertEquals(listOf(ReminderType.FIXED_TIME), viewModel.uiState.value.draft.reminders.map { it.reminderType })
    }

    @Test
    fun `save delete all reminders persists empty list and reschedules`() = runTest(dispatcher) {
        val scheduler = FakeReminderSchedulingGateway()
        val repository = FakeGoalRepository(
            goal(
                reminders = listOf(
                    GoalReminder(id = testId(1), goalId = testId(1), reminderType = ReminderType.FIXED_TIME, hour = 8, minute = 0),
                )
            )
        )
        val viewModel = viewModel(repository = repository, scheduler = scheduler)
        advanceUntilIdle()

        val draftId = viewModel.uiState.value.draft.reminders.single().draftId
        viewModel.onDeleteReminder(draftId)
        viewModel.save()
        advanceUntilIdle()

        assertTrue(viewModel.uiState.value.saveCompleted)
        assertTrue(repository.goal.reminders.isEmpty())
        assertEquals(1, scheduler.rescheduleCount)
    }

    @Test
    fun `save disabled reminder persists but scheduler will ignore it downstream`() = runTest(dispatcher) {
        val scheduler = FakeReminderSchedulingGateway()
        val repository = FakeGoalRepository(
            goal(
                reminders = listOf(
                    GoalReminder(id = testId(1), goalId = testId(1), reminderType = ReminderType.FIXED_TIME, hour = 8, minute = 0),
                )
            )
        )
        val viewModel = viewModel(repository = repository, scheduler = scheduler)
        advanceUntilIdle()

        val draftId = viewModel.uiState.value.draft.reminders.single().draftId
        viewModel.onToggleReminder(draftId, false)
        viewModel.save()
        advanceUntilIdle()

        assertEquals(listOf(false), repository.goal.reminders.map { it.enabled })
        assertEquals(1, scheduler.rescheduleCount)
    }

    private fun viewModel(
        goal: Goal = goal(),
        repository: FakeGoalRepository = FakeGoalRepository(goal),
        scheduler: FakeReminderSchedulingGateway = FakeReminderSchedulingGateway(),
    ) = EditGoalRemindersViewModel(
        savedStateHandle = SavedStateHandle(mapOf("goalId" to testId(1).toString())),
        goalRepository = repository,
        dhikrRepository = FakeDhikrRepository(),
        updateGoalRemindersUseCase = UpdateGoalRemindersUseCase(repository),
        reminderScheduler = scheduler,
    )

    private fun goal(
        slots: List<GoalSlot> = listOf(slot(id = testId(10), slotType = GoalSlotType.ANYTIME)),
        reminders: List<GoalReminder> = emptyList(),
    ) = Goal(
        id = testId(1),
        dhikrId = testId(1),
        slots = slots,
        reminders = reminders,
        startDate = LocalDate.parse("2026-05-27"),
    )

    private fun slot(id: UUID, slotType: GoalSlotType) = GoalSlot(
        id = id,
        goalId = testId(1),
        slotType = slotType,
        prayerName = if (slotType == GoalSlotType.PRAYER) Prayer.FAJR else null,
        prayerRelation = if (slotType == GoalSlotType.PRAYER) PrayerRelation.AFTER else null,
        startMinute = if (slotType == GoalSlotType.TIME_WINDOW) 6 * 60 else null,
        endMinute = if (slotType == GoalSlotType.TIME_WINDOW) 7 * 60 else null,
        label = when (slotType) {
            GoalSlotType.ANYTIME -> "Anytime"
            GoalSlotType.PRAYER -> "After Fajr"
            GoalSlotType.TIME_WINDOW -> "Morning"
        },
    )
}

private class FakeReminderSchedulingGateway(
    private val canSchedule: Boolean = true,
) : ReminderSchedulingGateway {
    var rescheduleCount = 0
        private set

    override fun canScheduleExactAlarms(): Boolean = canSchedule

    override fun rescheduleAll() {
        rescheduleCount += 1
    }
}

private class FakeGoalRepository(
    var goal: Goal,
) : GoalRepository {
    override fun getActiveGoals(): Flow<List<Goal>> = flowOf(listOf(goal))
    override fun getCompletedGoals(): Flow<List<Goal>> = flowOf(emptyList())
    override fun getAllGoals(): Flow<List<Goal>> = flowOf(listOf(goal))
    override fun getGoalByIdFlow(id: UUID): Flow<Goal?> = flowOf(goal.takeIf { it.id == id })
    override suspend fun getGoalById(id: UUID): Goal? = goal.takeIf { it.id == id }
    override suspend fun createGoal(validatedGoal: ValidatedGoal): UUID = unsupported()
    override suspend fun updateGoal(goal: Goal) {
        this.goal = goal
    }
    override suspend fun updateGoal(validatedGoalUpdate: ValidatedGoalUpdate): Goal {
        goal = validatedGoalUpdate.goal
        return goal
    }
    override suspend fun updateGoalSchedule(validatedGoalUpdate: ValidatedGoalUpdate): Goal {
        goal = validatedGoalUpdate.goal
        return goal
    }
    override suspend fun updateGoalReminders(validatedGoalUpdate: ValidatedGoalUpdate): Goal {
        goal = validatedGoalUpdate.goal
        return goal
    }
    override suspend fun deleteGoal(id: UUID) = unsupported()
    override suspend fun addCount(goalId: UUID, slotId: UUID?, count: Long): Long = unsupported()
    override fun getTotalCountForDate(goalId: UUID, date: String): Flow<Long?> = flowOf(0)
    override fun getTotalCount(goalId: UUID): Flow<Long?> = flowOf(0)
    override suspend fun getCountForSlotAndDate(goalId: UUID, slotId: UUID, date: String): Long = 0
    override fun getProgressMapForDate(date: String): Flow<Map<UUID, Long>> = flowOf(emptyMap())
    override fun getHistoryForGoal(goalId: UUID): Flow<List<CountEntry>> = flowOf(emptyList())
    override fun getDailyCountsByGoal(): Flow<Map<UUID, Map<LocalDate, Long>>> = flowOf(emptyMap())
    override fun getDailySlotCountsByGoal(): Flow<Map<UUID, Map<LocalDate, Map<UUID, Long>>>> = flowOf(emptyMap())
    override fun getDailySlotCountsForGoal(goalId: UUID): Flow<Map<LocalDate, Map<UUID, Long>>> = flowOf(emptyMap())
    override suspend fun getSlotCountsForGoalAndDate(goalId: UUID, date: String): Map<UUID, Long> = emptyMap()
    override suspend fun getTotalCountBetween(goalId: UUID, startDate: String, endDate: String): Long = 0
    override suspend fun getActiveGoalsWithNotifications(): List<Goal> = listOf(goal).filter { it.notificationEnabled }
    override suspend fun deleteAllProgress() = unsupported()
    override suspend fun deleteAllGoalsAndProgress() = unsupported()
    override fun getActiveGoalsByDhikrId(dhikrId: UUID): Flow<List<Goal>> = flowOf(listOf(goal).filter { it.dhikrId == dhikrId })
    override fun getDailyCountsForGoal(goalId: UUID): Flow<Map<LocalDate, Long>> = flowOf(emptyMap())

    private fun unsupported(): Nothing = error("Not needed for EditGoalRemindersViewModelTest")
}

private class FakeDhikrRepository : DhikrRepository {
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
    override fun getDhikrsByCategory(category: DhikrCategory): Flow<List<Dhikr>> = flowOf(listOf(dhikr).filter { it.category == category })
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
}
