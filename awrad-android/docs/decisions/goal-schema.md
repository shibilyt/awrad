# Goal Schema Design Decisions

## Context

The original goal system used a flat `GoalType` enum (`DAILY`, `PRAYER_BASED`, `ONE_TIME`, `ADVANCED`). That model could not safely express weekly schedules, Hijri seasons, time-window slots, tracker goals, or different target/progress semantics.

The current system uses a normalized goal aggregate and a domain-level creation boundary. UI presets are convenience inputs only; durable goals must be created from a validated command.

## Decision: Validated Creation Pipeline

All creation entry points should produce `CreateGoalCommand`, then pass through `GoalFactory` and `CreateGoalUseCase`.

```
Wizard Draft / Suggested Goal
    -> CreateGoalCommand
    -> GoalFactory validation
    -> ValidatedGoal
    -> CreateGoalUseCase
    -> GoalRepository
    -> Room tables
```

This prevents screens, suggestions, imports, or future APIs from constructing raw `Goal` objects with missing recurrence, invalid slots, or inconsistent targets.

## Decision: Composable Domain Concepts

Goal creation is described with explicit domain concepts:

| Concept | Purpose |
|---------|---------|
| `ScheduleSpec` | When the goal is due: daily, weekly, monthly, interval, yearly, season, specific dates |
| `TimingSpec` | When during a due day counting happens: anytime, prayer slots, time windows |
| `CountPolicy` | Minimum, target, maximum, thresholds, and cap behavior |
| `ProgressScope` | Which count entries contribute: due date, period, lifetime |
| `CompletionPolicy` | Whether the goal auto-completes on target |
| `ReminderPolicy` | Fixed-time, prayer-offset, or time-window-start reminders |

`GoalPreset` remains a UI concept. Presets prefill drafts/commands, but they are not persisted as the source of truth.

## Decision: Normalized Persistence

The implemented schema is normalized, not `configJson` based.

```
goals
├── dhikrId
├── targetPolicy            (PER_DUE_DATE, CUMULATIVE_TOTAL, PERIOD_TOTAL, NONE)
├── startDate / endDate / durationDays
├── minimumStreakCount
├── autoCompleteOnTarget
├── totalCompletedCount
├── isActive / completedAt
├── createdAt / updatedAt

goal_recurrences
├── goalId                  (unique)
├── frequency               (DAILY, WEEKLY, MONTHLY, INTERVAL, YEARLY, SEASON, SPECIFIC_DATES)
├── calendar
├── intervalDays
├── anchorDate
├── month
├── seasonTemplateCode

goal_recurrence_weekdays
goal_recurrence_month_days
goal_recurrence_dates

goal_slots
├── goalId
├── slotType                (ANYTIME, PRAYER, TIME_WINDOW)
├── targetCount             (nullable for trackers)
├── prayerName / prayerRelation
├── startMinute / endMinute
├── startLeadMinutesOverride
├── label
├── sortOrder
├── isActive                (active sessions only appear in counting/edit flows)
├── archivedAt              (set when a removed session is retained for history)

goal_reminders
├── goalId
├── slotId                  (optional)
├── reminderType            (FIXED_TIME, PRAYER_OFFSET, TIME_WINDOW_START)
├── hour / minute / offsetMinutes
├── enabled
├── sortOrder

count_entries
├── goalId
├── slotId                  (nullable only for legacy goals without an explicit slot)
├── date
├── count
├── lastUpdated
```

## Decision: Count Policy

`CountPolicy` separates minimum, target, and maximum count semantics.

- `minimumCount` is for threshold-style behavior such as streak credit.
- `targetCount` is the intended count displayed as the goal target.
- `maximumCount` is available for exact or bounded goals.
- `CapBehavior` describes whether over-target counting is allowed, warned, or blocked.

Persistence stores the validated goal-level defaults on `goals` and the slot-level overrides on `goal_slots`:

- `goals.minimumStreakCount`, `goals.maximumCount`, and `goals.capBehavior` represent the goal default policy.
- `goal_slots.minimumCount`, `goal_slots.targetCount`, `goal_slots.maximumCount`, and `goal_slots.capBehavior` represent per-slot policy.
- New anytime goals still receive an explicit `ANYTIME` slot, so count entries should target that slot. Null `count_entries.slotId` remains readable for legacy rows only.
- Removed sessions are archived with `goal_slots.isActive = false` instead of deleted, so historical `count_entries.slotId` values continue to point to the original session.

## Consequences

- `GoalRepository.createGoal()` accepts only `ValidatedGoal`.
- Count mutation updates count entries, `totalCompletedCount`, and cumulative completion state in one transaction.
- Count mutation returns the applied delta so callers can reconcile optimistic UI/service state with the persisted result.
- Schedule/session edits preserve history by archiving removed slots and filtering inactive slots out of active counting/reminder flows.
- Future goal creation surfaces should depend on `CreateGoalUseCase`, not raw repository insertion.
