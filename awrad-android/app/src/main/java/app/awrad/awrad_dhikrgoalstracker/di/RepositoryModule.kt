package app.awrad.awrad_dhikrgoalstracker.di

import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepositoryImpl
import app.awrad.awrad_dhikrgoalstracker.data.repository.CommunityStatsRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.CommunityStatsRepositoryImpl
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepositoryImpl
import app.awrad.awrad_dhikrgoalstracker.data.repository.WirdLibraryRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.WirdLibraryRepositoryImpl
import app.awrad.awrad_dhikrgoalstracker.data.wird.HijriCalendar
import app.awrad.awrad_dhikrgoalstracker.data.wird.IcuHijriCalendar
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderSchedulingGateway
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindCommunityStatsRepository(impl: CommunityStatsRepositoryImpl): CommunityStatsRepository

    @Binds
    @Singleton
    abstract fun bindDhikrRepository(impl: DhikrRepositoryImpl): DhikrRepository

    @Binds
    @Singleton
    abstract fun bindGoalRepository(impl: GoalRepositoryImpl): GoalRepository

    @Binds
    @Singleton
    abstract fun bindWirdLibraryRepository(impl: WirdLibraryRepositoryImpl): WirdLibraryRepository

    @Binds
    @Singleton
    abstract fun bindHijriCalendar(impl: IcuHijriCalendar): HijriCalendar

    @Binds
    @Singleton
    abstract fun bindReminderSchedulingGateway(impl: ReminderScheduler): ReminderSchedulingGateway
}
