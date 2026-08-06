# Notification obligation engine

This document describes the current cross-platform urgency-reminder behavior. Configured goal, Wird, and daily reminders remain separate and retain their existing schedules.

## Timing contract

- `PER_DUE_DATE` + `ANYTIME`: warn 150 minutes before the effective-day deadline.
- `TIME_WINDOW` and `PRAYER` slots: warn at `start + floor((end - start) * 4 / 5)`, leaving 20% of the slot.
- Bounded `CUMULATIVE_TOTAL`: warn at the same 80%-elapsed point across the full goal duration. Undated cumulative goals have no urgency warning.
- Streak guardian: for an unsatisfied scheduled occurrence with a current streak of at least 3, warn 30 minutes before its deadline.
- `PERIOD_TOTAL` does not create artificial daily warnings. A guardian requires a real completed-period streak; platform assemblers suppress it when that streak cannot be derived safely.
- Tracker (`NONE`) notifications never invent a target or remaining count.

All deadlines are end-exclusive. The user's Midnight or Maghrib day reset defines occurrence boundaries. Missing Maghrib boundary data falls back to local midnight; unavailable prayer-slot times suppress that slot instead of inventing an interval.

## Shared invariants

- Reminder, streak, and completion thresholds remain distinct.
- Explicit active slots are conjunctive: over-counting one slot cannot compensate for another incomplete slot.
- Warnings are omitted when disabled, unscheduled, satisfied, completed, expired, invalid, closed, or no longer in the future. A missed warning is never retimed to “now.”
- Canonical stage identity includes goal, obligation scope, optional slot, and nudge kind. Trigger and expiry are mutable schedule metadata, so rescheduling does not create a second delivery stage.
- Delivered-stage tombstones prevent duplicate delivery and are retained through both the stage expiry and the retention window.

The acceptance cases live in [`contracts/behavior-model/v1/fixtures/behavior-cases.json`](../contracts/behavior-model/v1/fixtures/behavior-cases.json). Both native parity suites execute production planner and semantics code for every `notification_obligations` case.

## Android pipeline

1. Repository, sync, preference, startup, boot/time-change, and watchdog events request reconciliation.
2. `NotificationObligationPlanService` assembles current goal, progress, slot, prayer, streak, and effective-day inputs.
3. `NotificationScheduleReconciler` diffs desired records against the DataStore manifest and delivered ledger.
4. Adaptive nudges use exact alarms when permitted and one-time WorkManager fallback otherwise. Configured reminders keep their existing alarm path.
5. At delivery, live state is revalidated under the shared scheduling critical section before a deterministic tag/ID notification is posted.

The global **Urgency reminders** preference defaults on. Disabling it cancels only engine-owned urgency work and visible urgency notifications.

## iOS pipeline

1. Durable store mutations and relevant preference/lifecycle changes enter the combined notification refresh coordinator.
2. Configured reminders are refreshed first; urgency then uses the remaining `UNUserNotificationCenter` capacity.
3. The urgency reconciler owns only versioned urgency identifiers, merges system-delivered requests into its app-group tombstone ledger, and removes stale engine requests.
4. Notification responses carry validated goal/slot metadata into the existing app router.

iOS local notifications cannot run application code immediately before system presentation. iOS therefore relies on prompt mutation-time cancellation plus launch, foreground, significant-time, timezone, locale, and preference reconciliation rather than Android-style fire-time validation.

## Validation

- Root contract checks: `python3 scripts/validate_behavior_fixtures.py --self-test`
- Android resource parity: `python3 scripts/validate_android_urgency_resources.py --self-test`
- Cross-platform model checks: `./check-mobile-model-parity`
- Android: `cd awrad-android && ./gradlew :app:testDebugUnitTest :app:assembleDebug`
- iOS: run the `awrad` test target or `xcodebuild ... test` against an available simulator.

Real-device QA remains important for Android exact-alarm permission/fallback, OEM power behavior, Android notification permission transitions, iOS pending-request capacity, and foreground/background notification response handling.
