package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.DayResetOption
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import com.batoulapps.adhan.PrayerTimes
import kotlinx.coroutines.flow.first
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import javax.inject.Inject

fun interface UrgencyEnabledProvider {
    suspend fun isUrgencyEnabled(): Boolean
}

class UserPreferencesUrgencyEnabledProvider(
    private val userPreferences: UserPreferences,
) : UrgencyEnabledProvider {
    override suspend fun isUrgencyEnabled(): Boolean = userPreferences.urgencyRemindersEnabled.first()
}

data class UrgencyNudgeValidationContext(
    val nowMillis: Long,
    val zoneId: ZoneId,
    val dayReset: DayResetOption,
    val defaultPrayerLeadMinutes: Int,
    val appLanguage: String = AppLanguageResolver.current(),
    val maghribForCivilDate: (LocalDate) -> Instant? = { null },
    val prayerTimesForOccurrenceDate: (LocalDate) -> PrayerTimes? = { null },
)

data class UrgencyNudgeReplanInput(
    val nowMillis: Long,
    val zoneId: ZoneId,
    val dayReset: DayResetOption,
    val defaultPrayerLeadMinutes: Int,
    val appLanguage: String = AppLanguageResolver.current(),
    val maghribForCivilDate: (LocalDate) -> Instant?,
    val prayerTimesForOccurrenceDate: (LocalDate) -> PrayerTimes?,
)

fun interface UrgencyNudgeLivePlanProvider {
    suspend fun plan(input: UrgencyNudgeReplanInput): List<PlannedUrgencyNudge>
}

class NotificationObligationLivePlanProvider(
    private val planService: NotificationObligationPlanService,
) : UrgencyNudgeLivePlanProvider {
    override suspend fun plan(input: UrgencyNudgeReplanInput): List<PlannedUrgencyNudge> =
        planService.planDetailed(
            NotificationObligationPlanInput(
                now = Instant.ofEpochMilli(input.nowMillis),
                zoneId = input.zoneId,
                dayReset = input.dayReset,
                urgencyEnabled = true,
                defaultPrayerLeadMinutes = input.defaultPrayerLeadMinutes,
                appLanguage = input.appLanguage,
                maghribForCivilDate = input.maghribForCivilDate,
                prayerTimesForOccurrenceDate = input.prayerTimesForOccurrenceDate,
            ),
        )
}

enum class UrgencyNudgeRejectionReason {
    TOO_EARLY,
    EXPIRED,
    ALREADY_DELIVERED,
    NOT_SCHEDULED_OR_REPLACED,
    DISABLED,
    NO_LONGER_RELEVANT,
    TRIGGER_UNDERFLOW,
}

sealed interface UrgencyNudgeValidationOutcome {
    data class Valid(
        val nudge: PlannedUrgencyNudge,
        val remainingDurationMillis: Long,
    ) : UrgencyNudgeValidationOutcome

    data class Rejected(
        val reason: UrgencyNudgeRejectionReason,
    ) : UrgencyNudgeValidationOutcome
}

/**
 * Slice 5C2's local NotificationManager post boundary.
 *
 * It runs while scheduling is locked to close validation/post/tombstone TOCTOU. Implementations
 * must only perform the bounded local post and must not re-enter scheduling APIs or perform IO.
 */
internal fun interface UrgencyNudgePostingAction {
    suspend fun post(nudge: PlannedUrgencyNudge)
}

class UrgencyNudgeFireValidator @Inject constructor(
    private val planProvider: UrgencyNudgeLivePlanProvider,
    private val scheduleStore: NotificationScheduleStore,
    private val urgencyEnabledProvider: UrgencyEnabledProvider,
    private val coordinator: NotificationScheduleCoordinator,
) {
    suspend fun validate(
        envelope: AdaptiveNudgeEnvelope,
        context: UrgencyNudgeValidationContext,
    ): UrgencyNudgeValidationOutcome = coordinator.withScheduleLock {
        validateLocked(envelope, context)
    }

    internal suspend fun validateAndPost(
        envelope: AdaptiveNudgeEnvelope,
        context: UrgencyNudgeValidationContext,
        postingAction: UrgencyNudgePostingAction,
    ): UrgencyNudgeValidationOutcome = coordinator.withScheduleLock {
        val outcome = validateLocked(envelope, context)
        if (outcome is UrgencyNudgeValidationOutcome.Valid) {
            postingAction.post(
                outcome.nudge.copy(remainingDurationMillis = outcome.remainingDurationMillis),
            )
            // A process death between the local post and tombstone write retries the deterministic
            // tag+ID. It replaces the visual notification but may re-alert: the unavoidable
            // NotificationManager/DataStore at-least-once boundary.
            coordinator.markDeliveredInScheduleLock(
                envelope.identity,
                context.nowMillis,
                envelope.expiresAtMillis,
            )
        }
        outcome
    }

    private suspend fun validateLocked(
        envelope: AdaptiveNudgeEnvelope,
        context: UrgencyNudgeValidationContext,
    ): UrgencyNudgeValidationOutcome {
        if (context.nowMillis < envelope.triggerAtMillis) {
            return UrgencyNudgeValidationOutcome.Rejected(UrgencyNudgeRejectionReason.TOO_EARLY)
        }
        if (context.nowMillis >= envelope.expiresAtMillis) {
            return UrgencyNudgeValidationOutcome.Rejected(UrgencyNudgeRejectionReason.EXPIRED)
        }

        val state = scheduleStore.read()
        if (state.delivered.any { it.identity == envelope.identity }) {
            return UrgencyNudgeValidationOutcome.Rejected(UrgencyNudgeRejectionReason.ALREADY_DELIVERED)
        }
        val manifest = state.manifest.singleOrNull { it.identity == envelope.identity }
        if (manifest == null ||
            manifest.triggerAtMillis != envelope.triggerAtMillis ||
            manifest.expiresAtMillis != envelope.expiresAtMillis ||
            manifest.kind != envelope.kind
        ) {
            return UrgencyNudgeValidationOutcome.Rejected(
                UrgencyNudgeRejectionReason.NOT_SCHEDULED_OR_REPLACED,
            )
        }
        if (!urgencyEnabledProvider.isUrgencyEnabled()) {
            return UrgencyNudgeValidationOutcome.Rejected(UrgencyNudgeRejectionReason.DISABLED)
        }
        if (envelope.triggerAtMillis == Long.MIN_VALUE) {
            return UrgencyNudgeValidationOutcome.Rejected(UrgencyNudgeRejectionReason.TRIGGER_UNDERFLOW)
        }

        // Replanning just before the original trigger retains its effective window when a fallback runs late.
        val live = planProvider.plan(
            UrgencyNudgeReplanInput(
                nowMillis = envelope.triggerAtMillis - 1L,
                zoneId = context.zoneId,
                dayReset = context.dayReset,
                defaultPrayerLeadMinutes = context.defaultPrayerLeadMinutes,
                appLanguage = context.appLanguage,
                maghribForCivilDate = context.maghribForCivilDate,
                prayerTimesForOccurrenceDate = context.prayerTimesForOccurrenceDate,
            ),
        ).singleOrNull { nudge ->
            nudge.record.identity == envelope.identity &&
                nudge.record.triggerAtMillis == envelope.triggerAtMillis &&
                nudge.record.expiresAtMillis == envelope.expiresAtMillis &&
                nudge.record.kind == envelope.kind
        } ?: return UrgencyNudgeValidationOutcome.Rejected(UrgencyNudgeRejectionReason.NO_LONGER_RELEVANT)

        return UrgencyNudgeValidationOutcome.Valid(
            nudge = live,
            remainingDurationMillis = saturatedDurationMillis(envelope.expiresAtMillis, context.nowMillis),
        )
    }

    private fun saturatedDurationMillis(expiresAtMillis: Long, nowMillis: Long): Long =
        if (nowMillis < 0L && expiresAtMillis > Long.MAX_VALUE + nowMillis) {
            Long.MAX_VALUE
        } else {
            expiresAtMillis - nowMillis
        }
}
