# Awrad Goal Domain

This context defines the language for goals and how they're evaluated. A goal tracks a single activity; multi-practice Wird plans and sequenced dhikr are future capabilities.

The executable definitions of these rules are the fixtures in `contracts/goal-model/v1/fixtures/`. When this text and a fixture disagree, the fixture is the spec.

## Goal language

**Goal**:
A single measurable objective attached to one dhikr or tracked amal, with its own schedule, active period, sessions, requirement and completion condition.
_Avoid_: Practice plan, routine, bundle

**Schedule**:
The calendar pattern that determines which days a goal is due:
- every day;
- selected weekdays;
- every N days from an anchor date;
- selected days of the month (a day past the month's end falls on its last day, so the 31st is 30 April);
- specific dates;
- **one time**: no repeating pattern, so the goal is due every day of its active period until it's completed;
- selected days of every **Hijri month** (white days: 13–15);
- **yearly**: dates or date ranges every year, in the Gregorian or the Hijri calendar. A range may run over the year end.

A Hijri day 30 falls on the 29th in a 29-day month, and 29 February on the 28th in a common year.
_Avoid_: Target period, recurrence (as a user-facing term)

**Hijri date**:
The Hijri date of an effective practice day, from the shared Umm al-Qura table and the account's **Hijri corrections**. With the Maghrib reset it changes at Maghrib; with the midnight reset, at midnight. Outside the table (1400–1500 AH) there's none, and Hijri schedules aren't due.

**Hijri correction**:
A month-start correction for local moon sighting: "Ramadan 1447 started a day later here". It moves that month and every later month until the next correction. It's at most 2 days from the table, and every month still has 29 or 30 days. It's part of the account practice policy.
_Avoid_: Hijri offset (a fixed shift for every month)

**Goal preset**:
A built-in shortcut that fills in a goal's schedule, and sometimes its requirement: Ramadan, the white days, six days of Shawwal. The goal keeps the full schedule; the preset's key is only a label. Users build their own occasions with the same schedules.
_Avoid_: Season (as a schedule kind)

**Active period**:
The span during which a goal can be due: from its start date, until its end date or the last day of its duration (start + N − 1), whichever comes first. Both ends are inclusive.
_Avoid_: Duration when referring to a single session

**Paused**:
A stretch of days the user has suspended a goal. A paused day isn't due: it neither counts toward nor breaks a streak.

**Session**:
A time-of-day opportunity for completing a goal, such as anytime, after Fajr, at 18:00, or within an evening window. Each session has its own count policy. When a goal has sessions, **each session must meet its own target** for the day to be met.
_Avoid_: Recurrence

**Count policy**:
The numbers a goal or session works against: an optional minimum, the target, an optional maximum (cap), and which of them the streak uses (the **streak threshold**: any count, minimum, target or maximum). Counts are always whole numbers.

A **valid goal** has a target for every requirement except tracker (on the goal, or on every session when it has sessions), and its streak threshold points at a value that is set. Invalid goals can't be created, synced or imported; there's no fallback behaviour for them.

**Requirement**:
The rule that decides whether a goal is met within a window. One of:
- **Per due date:** the target, on each due day (e.g. 313 every day).
- **Cumulative total:** one target across the whole active period (e.g. 10,000 in total).
- **Period total:** a target per week or month (e.g. 1,000 per week).
- **Days per period:** a number of qualifying days per week or month (e.g. 5 of 7 days a week). A day qualifies when it meets the daily target.
- **Tracker:** no target; any count is progress.

Periods are a week, a month or a **Hijri month**. Week-based windows start on the account's **week start**.
_Avoid_: Repeat, cadence, streak rule

**Completion**:
Derived, never set by counting code. A goal is completed when its completion policy says so:
- **when target reached:** cumulative goals, once the cumulative total is reached;
- **when duration ended:** once the active period is over;
- **never.**

If counts drop back below the target, the goal is no longer completed.

**Streak**:
A derived progress view: how many consecutive due units the goal was met, counting back from the effective practice day.
- For per-due-date, cumulative and tracker goals the unit is a **due day**, and a day counts when it meets the **streak threshold** (with sessions, every session meets its own).
- For period-total and days-per-period goals the unit is a **week or month** that met its requirement.
- Days that aren't due (unscheduled, paused, outside the active period) are skipped.
- **Today, or the current period, never breaks a streak while it's in progress.** It only adds to the streak once met.
_Avoid_: A separate goal target

## Practice settings language

**Account practice policy**:
The account-shared choices that shape practice interpretation across devices: day-end rule, prayer calculation method, madhab, **week start** (Saturday, Sunday or Monday; default Monday), and **Hijri corrections**. It has one canonical revision per account.
_Avoid_: Device settings, location profile

**Device context**:
The settings owned by one authenticated installation, including browser timezone, latitude, longitude, accuracy, and location source. A device context is keyed by the account and installation, so another device or another account in the same browser cannot inherit it.
_Avoid_: Account location, global location

**Effective practice day**:
The day used to evaluate a goal, from the current instant, the device's timezone and the day-end rule:
- **With a midnight reset**, it's the local calendar date.
- **With a Maghrib reset**, it's the next calendar date from the instant of that day's Maghrib onwards: the Maghrib instant itself belongs to the new day.
- **Without a known Maghrib** (no location), it falls back to midnight.

Two devices may show different prayer-relative context without changing the account policy or historical count dates.
_Avoid_: Server date

## Dhikr language

**Dhikr**:
A single text of remembrance: one entity with a kind, its Arabic, and a title, transliteration and translation per language. It is the building block that goals, wirds and practices use; it holds no counts, occasions or sequences itself.
_Avoid_: Practice, wird (for a single dhikr)

**Kind**:
What a dhikr is, which decides how it is shown: `quran`, `dhikr`, `dua`, `salawat` or `name_of_allah`.

**Catalog**:
The built-in dhikrs, collections and tags shipped with every app, from `contracts/dhikr-catalog/v1/catalog.json`. Built-ins are read-only; their keys and IDs never change.

**Collection**:
An ordered list of dhikrs with a translated title, such as Asma-ul Husna or Swalaths. A dhikr can be in several collections.
_Avoid_: Category

**Reference**:
Where a dhikr or a virtue comes from: the Qur'an (surah and ayahs), a hadith (collection, number, grade), a book, a shaykh, or another source.

**Virtue**:
A benefit of reciting a dhikr. Every virtue cites at least one reference.
_Avoid_: Benefit (in product text, unless sourced)

**Alias**:
Another spelling or name people search for a dhikr by, per language (Istighfar, Astaghfirullah).

## Account language

**Account**:
An Awrad identity: an email and a password. It's optional: the mobile apps are complete without one, and signing in is how a user opts in to sync (ADR-2026-10-28). An account can only sign in once its email is verified.
_Avoid_: User (in product text), profile

**Email code**:
A 6-digit code emailed to verify an account's email or to reset its password. It lasts 15 minutes and allows 5 tries.
_Avoid_: OTP, magic link

**Installation**:
One install of a mobile app, identified by a random UUID it keeps in secure storage. Reinstalling makes a new installation.

**Device session**:
A mobile installation signed in to an account, with its own refresh token. It ends after 30 days without use, after 180 days in any case, or when it's revoked (sign out, password reset, or a reused refresh token). Signing in again from the same installation replaces it.

**Browser session**:
A web browser signed in to an account with Phoenix's session cookie. It's separate from device sessions, and neither accepts the other's credential.

**Account session**:
Either kind of session, as the account sees it in its device list. Any one can be revoked; "sign out of all other devices" keeps the one in use.

**Account deletion**:
Immediate and permanent on the server, after the password is re-entered. Practice data stored on devices is untouched.

## Future scope

**Practice plan**:
A future multi-practice Wird capability that groups multiple dhikrs or rituals under one parent objective. It is intentionally outside the current goal scope.
_Avoid_: Goal in the current single-activity flow

**Sequenced dhikr**:
A future goal shape where one session has ordered parts, such as Tasbih Fatimah (33, 33, 34). Planned as its own slice.

**Carry-over**:
A future rule where a missed amount moves to the next due day.
