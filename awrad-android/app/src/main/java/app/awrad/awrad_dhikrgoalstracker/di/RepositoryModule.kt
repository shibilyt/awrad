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
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationPlanGateway
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationSchedulingEffectGateway
import app.awrad.awrad_dhikrgoalstracker.notification.AndroidNotificationSchedulingEffects
import app.awrad.awrad_dhikrgoalstracker.notification.DataStoreNotificationScheduleStore
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationScheduleStore
import app.awrad.awrad_dhikrgoalstracker.notification.RepositoryNotificationObligationPlanGateway
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderSchedulingGateway
import app.awrad.awrad_dhikrgoalstracker.notification.AndroidNotificationObligationEngineErrorReporter
import app.awrad.awrad_dhikrgoalstracker.notification.GoalReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.EffectiveTodayProvider
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationEngineErrorReporter
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationRequestDispatcher
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationRequestSink
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

    @Binds
    @Singleton
    abstract fun bindGoalReminderScheduler(impl: ReminderScheduler): GoalReminderScheduler

    @Binds
    @Singleton
    abstract fun bindEffectiveTodayProvider(impl: DateProvider): EffectiveTodayProvider

    @Binds
    @Singleton
    abstract fun bindNotificationObligationPlanGateway(
        impl: RepositoryNotificationObligationPlanGateway,
    ): NotificationObligationPlanGateway

    @Binds
    @Singleton
    abstract fun bindNotificationSchedulingEffects(
        impl: AndroidNotificationSchedulingEffects,
    ): NotificationSchedulingEffectGateway

    @Binds
    @Singleton
    abstract fun bindNotificationScheduleStore(
        impl: DataStoreNotificationScheduleStore,
    ): NotificationScheduleStore

    @Binds
    @Singleton
    abstract fun bindNotificationObligationEngineErrorReporter(
        impl: AndroidNotificationObligationEngineErrorReporter,
    ): NotificationObligationEngineErrorReporter

    @Binds
    @Singleton
    abstract fun bindNotificationObligationRequestSink(
        impl: NotificationObligationRequestDispatcher,
    ): NotificationObligationRequestSink
}
