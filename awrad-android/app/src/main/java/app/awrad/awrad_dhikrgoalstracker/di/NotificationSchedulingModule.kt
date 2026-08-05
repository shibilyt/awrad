package app.awrad.awrad_dhikrgoalstracker.di

import android.app.AlarmManager
import android.content.Context
import androidx.work.WorkManager
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.notification.AndroidNotificationGoalNameResolver
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationGoalNameResolver
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationLivePlanProvider
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationPlanService
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationPlanningContextProvider
import app.awrad.awrad_dhikrgoalstracker.notification.ProductionNotificationObligationPlanningContextProvider
import app.awrad.awrad_dhikrgoalstracker.notification.UrgencyEnabledProvider
import app.awrad.awrad_dhikrgoalstracker.notification.UrgencyNudgeLivePlanProvider
import app.awrad.awrad_dhikrgoalstracker.notification.UserPreferencesUrgencyEnabledProvider
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import java.time.Clock
import javax.inject.Qualifier
import javax.inject.Singleton

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class ApplicationCoroutineScope

@Module
@InstallIn(SingletonComponent::class)
object NotificationSchedulingModule {
    @Provides
    @Singleton
    @ApplicationCoroutineScope
    fun provideApplicationCoroutineScope(): CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @Provides
    @Singleton
    fun provideAlarmManager(@ApplicationContext context: Context): AlarmManager =
        context.getSystemService(AlarmManager::class.java)

    @Provides
    @Singleton
    fun provideWorkManager(@ApplicationContext context: Context): WorkManager =
        WorkManager.getInstance(context)

    @Provides
    @Singleton
    fun provideClock(): Clock = Clock.systemUTC()

    @Provides
    @Singleton
    fun provideUrgencyEnabledProvider(
        userPreferences: UserPreferences,
    ): UrgencyEnabledProvider = UserPreferencesUrgencyEnabledProvider(userPreferences)

    @Provides
    @Singleton
    fun provideNotificationGoalNameResolver(
        resolver: AndroidNotificationGoalNameResolver,
    ): NotificationGoalNameResolver = resolver

    @Provides
    @Singleton
    fun provideUrgencyNudgeLivePlanProvider(
        planService: NotificationObligationPlanService,
    ): UrgencyNudgeLivePlanProvider = NotificationObligationLivePlanProvider(planService)

    @Provides
    @Singleton
    fun provideNotificationPlanningContextProvider(
        provider: ProductionNotificationObligationPlanningContextProvider,
    ): NotificationObligationPlanningContextProvider = provider
}
