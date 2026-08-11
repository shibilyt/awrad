package app.awrad.awrad_dhikrgoalstracker.data.database

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.CountEntryDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrAudioAssetDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrCategoryAssignmentDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrTagAssignmentDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalRecurrenceDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalReminderDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalSlotDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.SeasonTemplateDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.SyncDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.UserTagDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.WirdDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.WirdSessionDao
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.CountEntryEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrAudioAssetEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrCategoryAssignmentEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrTagAssignmentEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceDateEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceMonthDayEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceWeekdayEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalReminderEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalSlotEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SeasonTemplateDayEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SeasonTemplateEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncEntityShadowEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncCountShadowEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncConflictEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncInboxPageEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncOpenCountBatchEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncOutboxEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncStateEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.UserTagEntity
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
        UserTagEntity::class,
        DhikrTagAssignmentEntity::class,
        DhikrAudioAssetEntity::class,
        DhikrCategoryAssignmentEntity::class,
        SyncStateEntity::class,
        SyncOutboxEntity::class,
        SyncOpenCountBatchEntity::class,
        SyncEntityShadowEntity::class,
        SyncInboxPageEntity::class,
        SyncCountShadowEntity::class,
        SyncConflictEntity::class,
    ],
    version = 15,
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
    abstract fun userTagDao(): UserTagDao
    abstract fun dhikrTagAssignmentDao(): DhikrTagAssignmentDao
    abstract fun dhikrAudioAssetDao(): DhikrAudioAssetDao
    abstract fun dhikrCategoryAssignmentDao(): DhikrCategoryAssignmentDao
    abstract fun syncDao(): SyncDao
}
