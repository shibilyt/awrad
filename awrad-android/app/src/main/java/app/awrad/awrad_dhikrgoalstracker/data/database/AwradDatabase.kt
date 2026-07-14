package app.awrad.awrad_dhikrgoalstracker.data.database

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.CountEntryDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalRecurrenceDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalReminderDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalSlotDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.SeasonTemplateDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.WirdDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.WirdSessionDao
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.CountEntryEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceDateEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceMonthDayEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceWeekdayEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalReminderEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalSlotEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SeasonTemplateDayEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SeasonTemplateEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.WirdEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.WirdSessionEntity

@Database(
    entities = [
        DhikrEntity::class,
        GoalEntity::class,
        GoalRecurrenceEntity::class,
        GoalRecurrenceWeekdayEntity::class,
        GoalRecurrenceMonthDayEntity::class,
        GoalRecurrenceDateEntity::class,
        GoalSlotEntity::class,
        GoalReminderEntity::class,
        SeasonTemplateEntity::class,
        SeasonTemplateDayEntity::class,
        CountEntryEntity::class,
        WirdEntity::class,
        WirdSessionEntity::class,
    ],
    version = 6,
    exportSchema = true,
)
@TypeConverters(Converters::class)
abstract class AwradDatabase : RoomDatabase() {
    abstract fun dhikrDao(): DhikrDao
    abstract fun goalDao(): GoalDao
    abstract fun goalRecurrenceDao(): GoalRecurrenceDao
    abstract fun goalSlotDao(): GoalSlotDao
    abstract fun goalReminderDao(): GoalReminderDao
    abstract fun seasonTemplateDao(): SeasonTemplateDao
    abstract fun countEntryDao(): CountEntryDao
    abstract fun wirdDao(): WirdDao
    abstract fun wirdSessionDao(): WirdSessionDao
}
