# Awrad Goal Domain

This context defines the language for the current goal-creation experience. The current scope is a single tracked goal; multi-practice Wird plans are future capability.

## Goal language

**Goal**:
A single measurable objective attached to one dhikr or tracked amal, with its own schedule, timing, requirements, and completion condition.
_Avoid_: Practice plan, routine, bundle

**Requirement**:
A rule that determines whether a goal is on track or complete within a defined time window, such as at least 313 every day or 10,000 every week.
_Avoid_: Repeat, cadence, streak rule

**Schedule**:
The calendar pattern that determines when a goal is expected, such as one time, every day, selected weekdays, or specific dates.
_Avoid_: Target period

**Session**:
A time-of-day opportunity for completing a goal, such as anytime, after Fajr, at 18:00, or within an evening window.
_Avoid_: Recurrence

**Active period**:
The span during which a goal is valid, such as 30 days, a date range, or until its final requirement is met.
_Avoid_: Duration when referring to a single session

**Streak**:
A derived progress view showing consecutive scheduled periods in which a selected daily requirement was satisfied.
_Avoid_: A separate goal target

## Practice settings language

**Account practice policy**:
The account-shared choices that shape practice interpretation across devices: day-end rule, prayer calculation method, and madhab. It has one canonical revision per account.
_Avoid_: Device settings, location profile

**Device context**:
The settings owned by one authenticated installation, including browser timezone, latitude, longitude, accuracy, and location source. A device context is keyed by the account and installation, so another device or another account in the same browser cannot inherit it.
_Avoid_: Account location, global location

**Effective practice day**:
The day used to evaluate a goal after combining the account practice policy with the current device context and browser-local time. Two devices may therefore show different current prayer-relative context without changing the account policy or historical count dates.
_Avoid_: Server date

## Future scope

**Practice plan**:
A future multi-practice Wird capability that groups multiple dhikrs or rituals under one parent objective. It is intentionally outside the current goal-creation scope.
_Avoid_: Goal in the current single-activity flow
