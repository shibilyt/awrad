package app.awrad.core.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import androidx.room.Room
import app.awrad.core.data.account.NetworkAccountRepository
import app.awrad.core.data.account.NetworkAccountSettingsRepository
import app.awrad.core.data.audio.ExoAudioPlayerFactory
import app.awrad.core.data.dhikr.BundledDhikrCatalogSource
import app.awrad.core.database.AwradDatabase
import app.awrad.core.database.GoalDao
import app.awrad.core.domain.UuidV7
import app.awrad.core.domain.account.AccountRepository
import app.awrad.core.domain.account.AccountSettingsRepository
import app.awrad.core.domain.audio.AudioPlayerFactory
import app.awrad.core.domain.dhikr.DhikrCatalogSource
import app.awrad.core.domain.goal.GoalRepository
import app.awrad.core.domain.onboarding.OnboardingStatusStore
import app.awrad.core.network.IdGenerator
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import java.time.Clock
import javax.inject.Singleton

private val Context.awradPreferences: DataStore<Preferences> by preferencesDataStore(name = "awrad_next")

/** The only place adapters meet ports. Features never see this module. */
@Module
@InstallIn(SingletonComponent::class)
internal interface DataModule {

    @Binds
    fun goalRepository(adapter: RoomGoalRepository): GoalRepository

    @Binds
    fun accountRepository(adapter: NetworkAccountRepository): AccountRepository

    @Binds
    fun accountSettingsRepository(adapter: NetworkAccountSettingsRepository): AccountSettingsRepository

    @Binds
    fun onboardingStatusStore(adapter: DataStoreOnboardingStatusStore): OnboardingStatusStore

    @Binds
    fun dhikrCatalogSource(adapter: BundledDhikrCatalogSource): DhikrCatalogSource

    @Binds
    fun audioPlayerFactory(adapter: ExoAudioPlayerFactory): AudioPlayerFactory

    companion object {
        @Provides
        @Singleton
        fun database(@ApplicationContext context: Context): AwradDatabase =
            Room.databaseBuilder(context, AwradDatabase::class.java, AwradDatabase.NAME).build()

        @Provides
        fun goalDao(database: AwradDatabase): GoalDao = database.goalDao()

        @Provides
        @Singleton
        fun preferences(@ApplicationContext context: Context): DataStore<Preferences> = context.awradPreferences

        @Provides
        fun clock(): Clock = Clock.systemDefaultZone()

        /** `:core:network`'s installation id and idempotency keys are the domain's UUIDv7 (ADR-2026-10-28). */
        @Provides
        fun idGenerator(clock: Clock): IdGenerator = IdGenerator { UuidV7.generate(clock) }
    }
}
