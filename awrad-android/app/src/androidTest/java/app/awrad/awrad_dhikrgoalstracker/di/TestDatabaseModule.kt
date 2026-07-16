package app.awrad.awrad_dhikrgoalstracker.di

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.room.Room
import app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.CountEntryDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalSlotDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.SyncDao
import dagger.Module
import dagger.Provides
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn
import javax.inject.Singleton

@Module
@TestInstallIn(components = [SingletonComponent::class], replaces = [DatabaseModule::class])
object TestDatabaseModule {

    @Provides
    @Singleton
    fun provideInMemoryDatabase(@ApplicationContext context: Context): AwradDatabase =
        Room.inMemoryDatabaseBuilder(context, AwradDatabase::class.java)
            .allowMainThreadQueries()
            .build()

    @Provides
    fun provideDhikrDao(db: AwradDatabase): DhikrDao = db.dhikrDao()

    @Provides
    fun provideGoalDao(db: AwradDatabase): GoalDao = db.goalDao()

    @Provides
    fun provideGoalSlotDao(db: AwradDatabase): GoalSlotDao = db.goalSlotDao()

    @Provides
    fun provideCountEntryDao(db: AwradDatabase): CountEntryDao = db.countEntryDao()

    @Provides
    fun provideSyncDao(db: AwradDatabase): SyncDao = db.syncDao()

    @Provides
    @Singleton
    fun provideDataStore(@ApplicationContext context: Context): DataStore<Preferences> =
        PreferenceDataStoreFactory.create {
            context.filesDir.resolve("test_preferences.preferences_pb")
        }
}
