# Awrad Goal Domain

This context defines the language for goals and how they're evaluated. A goal tracks a single activity; multi-practice Wird plans and sequenced dhikr are future capabilities.

The executable definitions of these rules are the fixtures in `contracts/goal-model/v1/fixtures/`. When this text and a fixture disagree, the fixture is the spec.

## Goal language

**Goal**:
A single measurable objective attached to one dhikr or tracked amal, with its own schedule, active period, sessions, requirement and completion condition. It syncs as one document: its dhikr, a **dhikr snapshot**, an optional name, **shared or dedicated counts**, its **dated versions**, pauses, **excused days** and how it **ended**.
_Avoid_: Practice plan, routine, bundle

**Dhikr snapshot**:
A copy of the goal's dhikr label (title, Arabic text, kind) kept in the goal, so History and stats still read correctly after a custom dhikr is deleted. Apps show the live dhikr while it exists.

**Shared and dedicated counts**:
Counts belong to the dhikr, not the goal: each count is stored once in the **count log**, against the dhikr and the practice day. A **shared** goal is filled by every shared count of its dhikr, wherever it was made; a **dedicated** goal only by counts made inside it, which fill no other goal. A goal is shared unless the user chose otherwise, and the question is asked only when another goal already uses the dhikr.
_Avoid_: Linked goals, goal progress (as stored data)

**Count log**:
A profile's append-only list of count entries (dhikr, practice day, session, the goal for a dedicated count, amount, time). Undo and adjustments are entries with a negative amount; nothing is ever edited. Counts never conflict between devices.

**Dated version**:
A goal's settings from one practice day on. Editing a goal's details adds a version from today, so each past day is judged by the settings it had. A **structural** change (another dhikr, schedule type or requirement type) ends the goal instead, and starts a new one.
_Avoid_: Revision (that's the sync counter), history

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

**Excused day**:
A missed due day the user excused after the fact (illness, travel). It's skipped like a paused day, and in an "N days a period" goal it lowers that period's number by one. At most 2 per goal per calendar month (the Gregorian month of the practice day); only past, missed days of goals judged by day can be excused, and an excused day can be un-excused.
_Avoid_: Freeze, skip day

**Session**:
A time-of-day opportunity for completing a goal: **anytime**, **before** or **after a prayer**, **at a time**, or **between two times**. Sessions only guide: any session can be counted any time that day. Each session has its own count policy, and its ID comes from its kind (`after_fajr`), so a shared count fills the same session in every goal on that dhikr. When a goal has sessions, **each session must meet its own target** for the day to be met.
_Avoid_: Recurrence, slot

**Count policy**:
The numbers a goal or session works against: an optional minimum, the target, an optional maximum (cap), and which number the streak uses (the **streak threshold**: any count, the minimum, target or maximum, a number of its own, or the **daily pace** for a total with an end). Counts are always whole numbers.

A **valid goal** has a target for every requirement except tracker (on the goal, or on every session when it has sessions), and its streak threshold points at a value that is set. It has sessions or a minimum and cap, not both; an end date or a number of days, not both; and make-up only if it's per due date. Invalid goals can't be created, synced or imported; there's no fallback behaviour for them.

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

The derivation follows the counts. Once a client sees a goal completed it writes that into the goal (**ended**, reason completed), so a completed goal stays in History even if an adjustment lowers its total.

**Ended and completed goals**:
A goal that has finished and moved to History. **Completed** means a total was reached; **ended** means the user ended it, its end date passed, a structural edit replaced it, or its custom dhikr was deleted. The goal records the day (its last day) and the reason. A finished goal is never reactivated: **Start again** creates a new goal with the same settings.
_Avoid_: Archived, deleted (deleting removes a goal from History)

**Streak**:
A derived progress view: how many consecutive **streak units** the goal was met, counting back from the effective practice day.
- A day **keeps the streak** when it reaches the **streak amount** (the streak threshold's number; with sessions, every session its own), or was **made up**.
- Days that aren't due (unscheduled, paused, excused, outside the active period) are skipped.
- **Today, the current period, or the current occasion never breaks a streak while it's in progress.** It only adds to the streak once met.
_Avoid_: A separate goal target

**Streak unit**:
What a streak counts, in the goal's own rhythm: **days** (due days; "12 Fridays" for a one-weekday schedule), **weeks** or **months** for period totals and "N days a period", and **occasions** for yearly schedules ("3 Ramadans", met when every due day of that year's occasion kept the streak).

**Make-up**:
A per-goal setting for daily (per-due-date) goals: counts past a later day's own target fill a missed day, which then counts as **made up** and keeps the streak. The **make-up window** is off, the next day, or within 3 days; the **make-up fill** is enough to keep the streak, or the full target. Missed days are filled oldest first.
_Avoid_: Carry-over (moving an amount forward), qada (in product text, unless reviewed)

**Consistency**:
How steadily a goal is kept: due days that kept the streak among the last 30 (or periods met among the last 12). Its **consistency tag** is **Devoted** at 90% or more and **Steady** at 80% or more, and none shows before 7 due days (4 periods). A row shows 🔥 and the streak; when the streak breaks, the tag, until a new streak reaches 3.
_Avoid_: Adherence, score

**Daily pace**:
Today's share of a total goal with an end date: what's left divided by the due days left, rounded up, recalculated each day. It's the default streak amount of such a goal, and what its ring fills toward.

**My Goals sections**:
Where a goal shows on a day: **Today's goals** (due today), **Upcoming** (due later, with when), **Tracking** (trackers, which are never "due"), **Paused**, and **History** (ended and completed goals). Within a section goals follow the user's **goal order**.
_Avoid_: Active (as a section name)

**Goal order**:
The user's own order of their goals, one per account. It's the tie-breaker everywhere goals are listed.

## Practice settings language

**Account practice policy**:
The account-shared choices that shape practice interpretation across devices: **day reset** (midnight or Maghrib; default midnight), **calculation method** (default Karachi), **madhab** (Shafi'i or Hanafi; only Asr), **week start** (Saturday, Sunday or Monday; default Monday), and **Hijri corrections**. It syncs as one change-queue entity per account. Signed out, each local profile has its own.
_Avoid_: Device settings, location profile

**Hijri correction**:
A move of one Hijri month's start, by up to 2 days from the Umm al-Qura table, that carries forward to later months; it follows local moon sighting. Every month stays 29 or 30 days, so a month usually moves only one day from the month before.
_Avoid_: Hijri offset (a fixed shift for every month)

**Device context**:
What only this device knows: its time zone (always the system's) and its **location**. It never leaves the device. A phone keeps one per installation, shared by its profiles; the web keeps one per account in that browser, so another account there doesn't inherit it.
_Avoid_: Account location, global location

**Location**:
Where the device is, for Maghrib: coordinates from GPS, a **bundled city** (from `contracts/places/v1/`), or a phone's online place search.
_Avoid_: Home, address

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

**Custom dhikr**:
A dhikr a user wrote. It has the same shape as a built-in, lives in that user's data, and syncs when they're signed in.

**Tag**:
A user's own label for dhikrs, such as "Morning". Tag names compare case-insensitively, and two tags with the same name merge.

**Personal record**:
A user's own data about one dhikr, built-in or custom. For now, that's its tags.

**Change queue**:
How user data reaches the server. Every edit on a phone is saved with a command in one step, and commands are sent in order when the phone is signed in and online. The web sends each edit straight away.
_Avoid_: Ledger, outbox (in product text)

**Revision**:
The server's running number for one account's changes. Devices ask for the changes after the revision they last saw.

**Conflict**:
An edit made against an older version than the server's. For custom dhikrs, tags and personal records the user chooses Keep mine or Use theirs; nothing is overwritten silently. For goals the first edit to reach the server wins: the other device takes the server's goal and shows a notice with a one-tap retry. The practice policy and the goal order merge without asking.

**Local profile**:
One account's data on a phone, kept in its own store, or the anonymous data before any sign-in. Two accounts' data never mix.

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
