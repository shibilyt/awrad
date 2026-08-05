package app.awrad.awrad_dhikrgoalstracker.data.preferences

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import java.io.File
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class UserPreferencesUrgencyTest {

    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun missingUrgencyReminderKeyDefaultsToEnabled() = runTest {
        val preferences = UserPreferences(testDataStore("missing-key"))

        assertTrue(preferences.urgencyRemindersEnabled.first())
    }

    @Test
    fun settingUrgencyReminderPersistsAcrossRecreatedPreferences() = runTest {
        val dataStore = testDataStore("urgency-persist")
        val preferences = UserPreferences(dataStore)

        preferences.setUrgencyRemindersEnabled(false)
        assertFalse(preferences.urgencyRemindersEnabled.first())

        val recreated = UserPreferences(dataStore)
        assertFalse(recreated.urgencyRemindersEnabled.first())

        recreated.setUrgencyRemindersEnabled(true)
        assertTrue(UserPreferences(dataStore).urgencyRemindersEnabled.first())
    }

    @Test
    fun settingUrgencyReminderDoesNotChangeDailyRemembranceOrTimePreferences() = runTest {
        val preferences = UserPreferences(testDataStore("urgency-isolated"))
        preferences.setDailyReminderEnabled(true)
        preferences.setDailyRemembranceEnabled(true)
        preferences.setReminderHour(10)
        preferences.setReminderMinute(45)

        preferences.setUrgencyRemindersEnabled(false)

        assertFalse(preferences.urgencyRemindersEnabled.first())
        assertTrue(preferences.dailyReminderEnabled.first())
        assertTrue(preferences.dailyRemembranceEnabled.first())
        assertEquals(10, preferences.reminderHour.first())
        assertEquals(45, preferences.reminderMinute.first())
    }

    private fun TestScope.testDataStore(name: String): DataStore<Preferences> =
        PreferenceDataStoreFactory.create(scope = backgroundScope) {
            File(temporaryFolder.root, "$name.preferences_pb")
        }
}
