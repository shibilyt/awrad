package app.awrad.awrad_dhikrgoalstracker.data.preferences

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class UserPreferences @Inject constructor(
    private val dataStore: DataStore<Preferences>
) {
    companion object {
        private val KEY_USER_NAME = stringPreferencesKey("user_name")
        private val KEY_IS_ONBOARDED = booleanPreferencesKey("is_onboarded")
        private val KEY_HAS_SEEN_COUNTING_GUIDE = booleanPreferencesKey("has_seen_counting_guide")
        private val KEY_DARK_MODE = booleanPreferencesKey("dark_mode")
        private val KEY_VIBRATE_ON_COUNT = booleanPreferencesKey("vibrate_on_count")
        private val KEY_KEEP_SCREEN_ON = booleanPreferencesKey("keep_screen_on")
        private val KEY_SOUND_ON_COUNT = booleanPreferencesKey("sound_on_count")
        private val KEY_DAILY_REMINDER_ENABLED = booleanPreferencesKey("daily_reminder_enabled")
        private val KEY_DAILY_REMEMBRANCE_ENABLED = booleanPreferencesKey("daily_remembrance_enabled")
        private val KEY_REMINDER_HOUR = intPreferencesKey("reminder_hour")
        private val KEY_REMINDER_MINUTE = intPreferencesKey("reminder_minute")
        private val KEY_LATITUDE = stringPreferencesKey("location_latitude")
        private val KEY_LONGITUDE = stringPreferencesKey("location_longitude")
        private val KEY_CITY_NAME = stringPreferencesKey("city_name")
        private val KEY_CALCULATION_METHOD = stringPreferencesKey("calculation_method")
        private val KEY_MADHAB = stringPreferencesKey("madhab")
        private val KEY_DAY_RESET_TIME = stringPreferencesKey("day_reset_time")
        private val KEY_CALENDAR_SYSTEM = stringPreferencesKey("calendar_system")
        private val KEY_PRAYER_SLOT_DEFAULT_LEAD_MINUTES = intPreferencesKey("prayer_slot_default_lead_minutes")
        private val KEY_READER_FONT_SCALE = floatPreferencesKey("wird_reader_font_scale")
        private val KEY_COUNTING_DHIKR_TEXT_SCALE = floatPreferencesKey("counting_dhikr_text_scale")
        private val KEY_COUNTING_DHIKR_LINE_SPACING = floatPreferencesKey("counting_dhikr_line_spacing")
        private val KEY_COUNTING_AVAILABILITY_CONFIRMATIONS =
            stringSetPreferencesKey("counting_availability_confirmations")
    }

    val userName: Flow<String> = dataStore.data.map { it[KEY_USER_NAME] ?: "" }
    val isOnboarded: Flow<Boolean> = dataStore.data.map { it[KEY_IS_ONBOARDED] ?: false }
    val hasSeenCountingGuide: Flow<Boolean> = dataStore.data.map { it[KEY_HAS_SEEN_COUNTING_GUIDE] ?: false }
    val darkMode: Flow<Boolean?> = dataStore.data.map { it[KEY_DARK_MODE] }
    val vibrateOnCount: Flow<Boolean> = dataStore.data.map { it[KEY_VIBRATE_ON_COUNT] ?: false }
    val keepScreenOn: Flow<Boolean> = dataStore.data.map { it[KEY_KEEP_SCREEN_ON] ?: false }
    val soundOnCount: Flow<Boolean> = dataStore.data.map { it[KEY_SOUND_ON_COUNT] ?: false }
    val dailyReminderEnabled: Flow<Boolean> = dataStore.data.map { it[KEY_DAILY_REMINDER_ENABLED] ?: false }
    val dailyRemembranceEnabled: Flow<Boolean> = dataStore.data.map { it[KEY_DAILY_REMEMBRANCE_ENABLED] ?: false }
    val reminderHour: Flow<Int> = dataStore.data.map { it[KEY_REMINDER_HOUR] ?: 8 }
    val reminderMinute: Flow<Int> = dataStore.data.map { it[KEY_REMINDER_MINUTE] ?: 0 }
    val latitude: Flow<Double?> = dataStore.data.map { it[KEY_LATITUDE]?.toDoubleOrNull() }
    val longitude: Flow<Double?> = dataStore.data.map { it[KEY_LONGITUDE]?.toDoubleOrNull() }
    val cityName: Flow<String> = dataStore.data.map { it[KEY_CITY_NAME] ?: "" }
    val calculationMethod: Flow<String> = dataStore.data.map { it[KEY_CALCULATION_METHOD] ?: "KARACHI" }
    val madhab: Flow<String> = dataStore.data.map { it[KEY_MADHAB] ?: "SHAFI" }
    val dayResetTime: Flow<String> = dataStore.data.map { it[KEY_DAY_RESET_TIME] ?: "MIDNIGHT" }
    val calendarSystem: Flow<String> = dataStore.data.map { it[KEY_CALENDAR_SYSTEM] ?: "GREGORIAN" }
    val prayerSlotDefaultLeadMinutes: Flow<Int> = dataStore.data.map { it[KEY_PRAYER_SLOT_DEFAULT_LEAD_MINUTES] ?: 30 }
    val readerFontScale: Flow<Float> = dataStore.data.map { it[KEY_READER_FONT_SCALE] ?: 1f }
    val countingDhikrTextScale: Flow<Float> = dataStore.data.map { it[KEY_COUNTING_DHIKR_TEXT_SCALE] ?: 1f }
    val countingDhikrLineSpacing: Flow<Float> = dataStore.data.map { it[KEY_COUNTING_DHIKR_LINE_SPACING] ?: 1f }

    suspend fun setUserName(name: String) {
        dataStore.edit { it[KEY_USER_NAME] = name }
    }

    suspend fun setOnboarded(onboarded: Boolean) {
        dataStore.edit { it[KEY_IS_ONBOARDED] = onboarded }
    }

    suspend fun setHasSeenCountingGuide(seen: Boolean) {
        dataStore.edit { it[KEY_HAS_SEEN_COUNTING_GUIDE] = seen }
    }

    suspend fun setDarkMode(enabled: Boolean?) {
        dataStore.edit {
            if (enabled != null) {
                it[KEY_DARK_MODE] = enabled
            } else {
                it.remove(KEY_DARK_MODE)
            }
        }
    }

    suspend fun setVibrateOnCount(enabled: Boolean) {
        dataStore.edit { it[KEY_VIBRATE_ON_COUNT] = enabled }
    }

    suspend fun setKeepScreenOn(enabled: Boolean) {
        dataStore.edit { it[KEY_KEEP_SCREEN_ON] = enabled }
    }

    suspend fun setSoundOnCount(enabled: Boolean) {
        dataStore.edit { it[KEY_SOUND_ON_COUNT] = enabled }
    }

    suspend fun setDailyReminderEnabled(enabled: Boolean) {
        dataStore.edit { it[KEY_DAILY_REMINDER_ENABLED] = enabled }
    }

    suspend fun setDailyRemembranceEnabled(enabled: Boolean) {
        dataStore.edit { it[KEY_DAILY_REMEMBRANCE_ENABLED] = enabled }
    }

    suspend fun setReminderHour(hour: Int) {
        dataStore.edit { it[KEY_REMINDER_HOUR] = hour }
    }

    suspend fun setReminderMinute(minute: Int) {
        dataStore.edit { it[KEY_REMINDER_MINUTE] = minute }
    }

    suspend fun setLocation(latitude: Double, longitude: Double, cityName: String) {
        dataStore.edit {
            it[KEY_LATITUDE] = latitude.toString()
            it[KEY_LONGITUDE] = longitude.toString()
            it[KEY_CITY_NAME] = cityName
        }
    }

    suspend fun setCalculationMethod(method: String) {
        dataStore.edit { it[KEY_CALCULATION_METHOD] = method }
    }

    suspend fun setMadhab(madhab: String) {
        dataStore.edit { it[KEY_MADHAB] = madhab }
    }

    suspend fun setDayResetTime(value: String) {
        dataStore.edit { it[KEY_DAY_RESET_TIME] = value }
    }

    suspend fun setCalendarSystem(value: String) {
        dataStore.edit { it[KEY_CALENDAR_SYSTEM] = value }
    }

    suspend fun setPrayerSlotDefaultLeadMinutes(minutes: Int) {
        dataStore.edit { it[KEY_PRAYER_SLOT_DEFAULT_LEAD_MINUTES] = minutes.coerceAtLeast(0) }
    }

    suspend fun setReaderFontScale(scale: Float) {
        dataStore.edit { it[KEY_READER_FONT_SCALE] = scale }
    }

    suspend fun setCountingDhikrTextScale(scale: Float) {
        dataStore.edit { it[KEY_COUNTING_DHIKR_TEXT_SCALE] = scale }
    }

    suspend fun setCountingDhikrLineSpacing(spacing: Float) {
        dataStore.edit { it[KEY_COUNTING_DHIKR_LINE_SPACING] = spacing }
    }

    suspend fun hasCountingAvailabilityConfirmation(key: String): Boolean {
        val prefix = "${key.substringBefore(':')}:"
        val stored = dataStore.data.first()[KEY_COUNTING_AVAILABILITY_CONFIRMATIONS].orEmpty()
        if (stored.all { it.startsWith(prefix) }) return key in stored
        dataStore.edit { preferences ->
            preferences[KEY_COUNTING_AVAILABILITY_CONFIRMATIONS] =
                stored.filterTo(mutableSetOf()) { it.startsWith(prefix) }
        }
        return key in stored
    }

    suspend fun confirmCountingAvailability(key: String, effectiveDate: String) {
        dataStore.edit { preferences ->
            val currentDatePrefix = "$effectiveDate:"
            val pruned = preferences[KEY_COUNTING_AVAILABILITY_CONFIRMATIONS]
                .orEmpty()
                .filterTo(mutableSetOf()) { it.startsWith(currentDatePrefix) }
            pruned.add(key)
            preferences[KEY_COUNTING_AVAILABILITY_CONFIRMATIONS] = pruned
        }
    }
}
