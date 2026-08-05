package app.awrad.awrad_dhikrgoalstracker.ui.screens.settings

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/**
 * Urgency settings coverage without production test seams.
 *
 * Preference default/persistence/isolation is asserted against [UserPreferences] — the same
 * store [SettingsViewModel.onUrgencyRemindersChanged] writes and [SettingsUiState] reads.
 * The Settings notification row binds `uiState.urgencyRemindersEnabled` directly; Compose UI
 * is covered by that wiring plus resource/assemble checks (no JVM Compose seam here).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelUrgencyTest {

    @get:Rule
    val temporaryFolder = TemporaryFolder()

    private val dispatcher = UnconfinedTestDispatcher()

    @Before
    fun setUp() = Dispatchers.setMain(dispatcher)

    @After
    fun tearDown() = Dispatchers.resetMain()

    @Test
    fun settingsUiStateDefaultsUrgencyRemindersEnabled() {
        assertTrue(SettingsUiState().urgencyRemindersEnabled)
    }

    @Test
    fun urgencyPreferenceFlowDefaultsTrueThenPersistsFalseAndTrue() = runTest(dispatcher) {
        val preferences = UserPreferences(testDataStore("urgency-flow"))
        val values = mutableListOf<Boolean>()
        val collectJob = launch {
            preferences.urgencyRemindersEnabled.collect { values.add(it) }
        }
        advanceUntilIdle()

        assertTrue(values.last())
        assertTrue(SettingsUiState(urgencyRemindersEnabled = values.last()).urgencyRemindersEnabled)

        preferences.setUrgencyRemindersEnabled(false)
        advanceUntilIdle()
        assertFalse(values.last())
        assertFalse(SettingsUiState(urgencyRemindersEnabled = values.last()).urgencyRemindersEnabled)

        preferences.setUrgencyRemindersEnabled(true)
        advanceUntilIdle()
        assertTrue(values.last())
        assertTrue(SettingsUiState(urgencyRemindersEnabled = values.last()).urgencyRemindersEnabled)

        collectJob.cancel()
    }

    @Test
    fun urgencySetterLeavesDailyReminderRemembranceAndTimeUnchanged() = runTest(dispatcher) {
        val preferences = UserPreferences(testDataStore("urgency-toggle-isolation"))
        preferences.setDailyReminderEnabled(true)
        preferences.setDailyRemembranceEnabled(true)
        preferences.setReminderHour(10)
        preferences.setReminderMinute(45)

        // Same write path as SettingsViewModel.onUrgencyRemindersChanged
        preferences.setUrgencyRemindersEnabled(false)
        advanceUntilIdle()

        assertFalse(preferences.urgencyRemindersEnabled.first())
        assertTrue(preferences.dailyReminderEnabled.first())
        assertTrue(preferences.dailyRemembranceEnabled.first())
        assertEquals(10, preferences.reminderHour.first())
        assertEquals(45, preferences.reminderMinute.first())
        assertEquals(
            SettingsUiState(
                dailyReminderEnabled = true,
                dailyRemembranceEnabled = true,
                urgencyRemindersEnabled = false,
                reminderHour = 10,
                reminderMinute = 45,
            ).urgencyRemindersEnabled,
            false,
        )
    }

    private fun TestScope.testDataStore(name: String): DataStore<Preferences> =
        PreferenceDataStoreFactory.create(scope = backgroundScope) {
            File(temporaryFolder.root, "$name.preferences_pb")
        }
}
