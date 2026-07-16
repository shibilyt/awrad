package app.awrad.awrad_dhikrgoalstracker.di

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase
import app.awrad.awrad_dhikrgoalstracker.data.database.AwradMigrations
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.CountEntryDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalRecurrenceDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalReminderDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalSlotDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.SeasonTemplateDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.SyncDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.WirdDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.WirdSessionDao
import app.awrad.awrad_dhikrgoalstracker.data.model.BuiltInSeasonTemplates
import app.awrad.awrad_dhikrgoalstracker.data.preferences.AuthTokenStorage
import app.awrad.awrad_dhikrgoalstracker.data.preferences.EncryptedAuthTokenStorage
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "awrad_preferences")

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AwradDatabase {
        val seedSeasonsCallback = object : RoomDatabase.Callback() {
            override fun onCreate(db: SupportSQLiteDatabase) {
                seedSeasonTemplates(db)
            }
        }
        return Room.databaseBuilder(
            context,
            AwradDatabase::class.java,
            "awrad_database",
        )
            .addMigrations(*AwradMigrations.ALL_MIGRATIONS)
            // Every schema upgrade MUST ship an explicit Migration in AwradMigrations; there is no
            // destructive fallback for upgrades, so a missing one crashes in dev instead of wiping
            // user data. Destructive downgrade is kept for dev/sideload only (never happens in prod).
            .fallbackToDestructiveMigrationOnDowngrade()
            .addCallback(seedSeasonsCallback)
            .build()
    }

    @Provides
    fun provideDhikrDao(database: AwradDatabase): DhikrDao = database.dhikrDao()

    @Provides
    fun provideGoalDao(database: AwradDatabase): GoalDao = database.goalDao()

    @Provides
    fun provideGoalRecurrenceDao(database: AwradDatabase): GoalRecurrenceDao = database.goalRecurrenceDao()

    @Provides
    fun provideGoalSlotDao(database: AwradDatabase): GoalSlotDao = database.goalSlotDao()

    @Provides
    fun provideGoalReminderDao(database: AwradDatabase): GoalReminderDao = database.goalReminderDao()

    @Provides
    fun provideSeasonTemplateDao(database: AwradDatabase): SeasonTemplateDao = database.seasonTemplateDao()

    @Provides
    fun provideCountEntryDao(database: AwradDatabase): CountEntryDao = database.countEntryDao()

    @Provides
    fun provideWirdDao(database: AwradDatabase): WirdDao = database.wirdDao()

    @Provides
    fun provideWirdSessionDao(database: AwradDatabase): WirdSessionDao = database.wirdSessionDao()

    @Provides
    fun provideSyncDao(database: AwradDatabase): SyncDao = database.syncDao()

    @Provides
    @Singleton
    fun provideDataStore(@ApplicationContext context: Context): DataStore<Preferences> = context.dataStore

    @Provides
    @Singleton
    fun provideAuthTokenStorage(@ApplicationContext context: Context): AuthTokenStorage =
        EncryptedAuthTokenStorage.create(context)

    private fun seedSeasonTemplates(db: SupportSQLiteDatabase) {
        BuiltInSeasonTemplates.all.forEach { template ->
            db.execSQL(
                """
                    INSERT OR REPLACE INTO season_templates (code, label, calendar, month)
                    VALUES (?, ?, ?, ?)
                """.trimIndent(),
                arrayOf(template.code.name, template.label, template.calendar.name, template.month),
            )
            template.days.forEach { day ->
                db.execSQL(
                    """
                        INSERT OR IGNORE INTO season_template_days (templateCode, dayOfMonth)
                        VALUES (?, ?)
                    """.trimIndent(),
                    arrayOf(template.code.name, day),
                )
            }
        }
    }

}
