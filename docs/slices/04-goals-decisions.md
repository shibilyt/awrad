# Slice 4 (goals): design decisions log

A working log of what the user decided while designing goals (2026-10-30). It becomes the slice 4 brief. The prototype is on branch `prototype/goals` (`prototypes/goals/`).

## Counting and goals

1. **Counts belong to a dhikr, not a goal.** A count is stored once, against the dhikr and the practice day, and it can fill several goals.
2. **Each goal is `shared` or `dedicated`:**
   - a shared goal is filled by every shared count of its dhikr, wherever it was made;
   - a dedicated goal is filled only by counts made inside it, and they don't spill into other goals.
3. **Creating a goal asks about sharing only when another goal uses the same dhikr** ("Count Istighfar from your other goal too?"), with shared pre-selected. Otherwise it's never mentioned.
4. **Undo and reset on a shared goal act on the dhikr's shared count,** so every shared goal on it changes, with a warning when another goal is affected. *(To revisit.)*
5. **Proposed storage** (agreed in principle):
   - goals are a `goal` item in the change queue, whole documents with version checks;
   - counts are an append-only log `{id, dhikr_id, practice_day, session_id?, goal_id? (dedicated only), amount, counted_at}`, batched while counting. Undo adds a correcting entry; reset cancels only the entries this device has seen;
   - both live in the profile database and work signed out;
   - the server stores counts in their own append-only table (contract in slice 5, shape fixed now).

## Creating goals

6. **Goals are created with an editable sentence** (variant B): verb · dhikr · amount · rhythm.
   - The verb follows the dhikr's kind: Say, Read, Recite.
   - The amount and rhythm choose the requirement: per day, a week/month/Hijri-month total, days per period, in total, or "whenever I can" (tracker).
   - The rhythm offers every schedule plus occasions: Ramadan (whole, first/middle/last 10, odd nights), six of Shawwal, first 10 of Dhul Hijjah, Arafah, Ashura.
7. **Details are optional clause lines,** each with ✕:
   - at least (minimum), stop at (cap);
   - sessions;
   - until / for N days / until I stop;
   - finish rule (cumulative only);
   - streak counts at;
   - name;
   - shared counts.

   Alongside them:
   - a plain read-back sentence and a live goal-row preview;
   - errors shown in the sentence;
   - an Examples strip;
   - a separate sentence template per language.
8. **Entry points:** the + on My Goals, and "Set a goal" from a dhikr (Library or the counter's ⋮ menu), which fills in the dhikr.
9. **Sentence limits accepted for now:**
   - sessions XOR minimum/cap;
   - no "N days a week within a narrower schedule";
   - an end date OR a number of days, not both;
   - several yearly ranges only through occasions.

   A fuller advanced editor can come later.
10. **Model change:** a session needs a **kind** (anytime, after a prayer, at a time, between two times). Today it's only `{id, count_policy}`.

## Sessions

11. **The counting page shows manual session pills.** The current or next session is pre-selected, and any session can be counted that day, including a missed one. Time windows only guide and never block. The day counts only when every session meets its number. Lists show the day's combined ring and a chip like "100 after Fajr · 100 after Maghrib".

## Lists

12. **Where a goal shows:**
    - due today → **Today's goals**;
    - weekly or monthly totals mid-period → Today's goals, with the period's progress;
    - due later this week, or an occasion outside its time → **Upcoming**, with when;
    - paused → a **Paused** section at the bottom of Active;
    - a reached cumulative goal → **History** (completed, with a short celebration);
    - ended by date → History ("Ended", with its result);
    - recurring occasion goals stay in Active as Upcoming for next time.
13. **Home's Today's goals** shows only goals due today. Goals finished today stay, with a filled ring.

## Counter

14. **The ring uses the green `progress` colour, not gold** (the palette stays as decided). The minimum is a small tick on the ring. The ring goes lighter green below the minimum and stronger green from the minimum to the target. Past the target it shows the grey lap plus the overflow arc, as designed.
15. **Reaching the target:** a success haptic and a ring pulse, then a small card: "Target reached · Next: <next due goal> →". Tapping the circle keeps counting into the overflow, so the card never blocks. After the last of today's goals, the card reads "All of today's goals are done". **The minimum** gets a soft haptic and the tick lights, with no card. **The cap** stops counting: the circle dims, "Reached your limit of N" shows, a strong haptic plays, and nothing counts past it.
16. **Tap area:** any tap in the lower half of the counting screen counts (everything below the Arabic text and the buttons); the circle is the visual. The header and buttons stay safe from stray taps. *(May revisit: circle only.)* The screen stays awake on the counter.

## Streaks and encouragement (in discussion)

17. **Late counting:** you can still count for yesterday until the end of today; after that the day is final. Late counts count normally, with no marker.
    - **User direction, to settle:** making up a missed day the next day should be a per-goal setting chosen at creation.
    - A consistent user who misses a day shouldn't feel defeated: show something like a consistency tag.
18. **Make-up (qada) is a per-goal setting chosen at creation:** off, the next day (the default when it's on), or within 3 days. Counts past the next day's own target fill the missed day first ("Making up Monday: 40/100"), and a filled missed day becomes "made up", which keeps the streak. *(Confirmed 2026-10-31: the choices are off / the next day / within 3 days, and the default when make-up is on is **within 3 days**.)*
19. **Rows show the streak first and consistency as the fallback.** A running streak shows "🔥 15 days". When it breaks, the row shows the consistency tag ("Steady · 28/30") until a new streak passes a few days. Tags are measured over the last 30 due days, or periods for weekly and monthly goals: **Steady ≥ 80%**, **Devoted ≥ 90%**, nothing shown below 80%. The goal's page always shows the streak, best streak and consistency.
20. **Excused days:** a missed day can be marked excused (illness, travel or similar) after the fact, from the goal's history calendar or the "yesterday was missed" message. It's skipped like a paused day. **Limit: 2 per goal per month.** It shows as "excused" in the calendar.
21. **A row switches back from the consistency tag to 🔥 once a new streak reaches 3 days** (the assistant's default; the user hasn't objected).

## Goal page

22. **The counter is the goal page.** Tapping a goal goes straight to counting. The counter's ☰ button opens a stats sheet: the history calendar (met, minimum only, made up, excused or paused, missed), the streak, best streak, consistency and totals. The ⋮ menu has edit, pause, delete and "Set a goal" for the same dhikr. Excusing a day happens from the calendar.

## Editing

23. **Editing a goal never rewrites its past.**
    - **Details edit in place and apply from today:** the number, minimum, cap, sessions' numbers, name, streak rule, make-up and the active period's end. The goal keeps dated versions, so each past day is judged by the rules it had then. The edit sheet says "Changes apply from today; your past stays as it was".
    - **Structural changes end the old goal and start a new one:** a different dhikr, schedule type or requirement type. The old goal moves to History ("Ended") and the new one starts today. The edit sheet warns before saving.

## Home

24. **Home's Today's goals card shows 3 goals:** unfinished first, in the user's own order from My Goals (goals with sessions keep that order too; their row names the next session, and the user chose simplicity over time-based reordering); finished goals sink to the bottom. When everything is done it reads "All done today", with the finished rings. "View All" opens My Goals. **No counting from Home:** taps open the counter.
25. **My Goals can be reordered by the user**, and that order is the tie-breaker everywhere.

## History

26. **History lists finished goals:** completed (cumulative reached) and ended (by date, or by a structural edit), each with its result ("70,000 ✓ in 34 days", "Met 34 of 40 days").
    - Tapping a goal opens its stats sheet, read-only.
    - The ⋮ menu offers **Start again** (a new goal with the same settings, starting today) and delete. A finished goal is never reactivated.
    - Once there are enough goals, History groups them by year, with a small yearly summary ("2026: 12 goals, 184,300 dhikr").
27. **Ending or deleting a goal:**
    - **A goal with history is ended, not deleted:** "End goal" in the ⋮ menu moves it to History ("Ended").
    - **Deleting happens only from History,** or straight away for a goal with no counts yet. There's a confirmation and a short Undo.
    - **Deleting removes the goal, its record and its dedicated counts.** Shared counts stay with the dhikr, for lifetime totals and other shared goals.

## Totals

28. **Total (cumulative) goals with an end date show a daily pace:** "About 1,250 a day to finish by 30 Dec". Rings on Home and in My Goals fill toward today's share, which is recalculated each day from what's left (it rises when you fall behind and drops when you're ahead). The counter shows both today's share and the overall total. **Without an end date** there's no pace: they show the total and today's count.
29. **Total goals without an end date have streaks too** (the user, 2026-10-30), like every other goal: 🔥 on the row, the consistency fallback, make-up and excused days.
    - A day counts toward the streak when it reaches the goal's "streak counts at" amount. The default is any count, and the user can set a daily number in the sentence ("streak counts at 100 a day").
    - The ring in lists fills toward that daily amount, so with the default any count fills it. The counter still shows the overall total.
    - Total goals with an end date work the same way, except that today's pace share is the default streak amount.
30. **Tracker goals ("whenever I can") have streaks too** (the user, 2026-10-30), to keep encouraging the user.
    - Any count that day keeps the streak.
    - Rows show 🔥 and the consistency fallback like any other goal. Late counting and excused days apply. Make-up doesn't (there's no daily target to fill).
    - Trackers sit in their own **Tracking** section in My Goals, below Today's/Upcoming and above Paused.
    - Rows show no ring: "Today 33 · Total 12,400 · 🔥 6 days".
    - The counter shows a plain count, with no ring fill and no target card. The stats sheet shows the calendar (days counted), the streak, the consistency and the totals.
    - **Trackers never appear on Home** (the user chose simplicity): Home shows only goals that are due today.
31. **Make-up chooses how much fills a missed day** (the user, 2026-10-30): "enough to keep the streak" (the streak amount, i.e. the minimum or the "streak counts at" number) or "the full target". The window stays off / the next day / within 3 days. Suggested default: enough to keep the streak.
32. **Consistency windows, accepted for now** (may change): the last 30 due days for daily goals, the last 12 periods for weekly and monthly goals, and no tag before 7 due days.
33. **Every ring in lists means "today"** (confirmed, 2026-10-30). For an open-ended total goal, the ring fills toward the daily streak amount (with the default, the first count fills it). The row's text carries the total ("12,050 of 70,000 · 🔥 9 days"), and the counter shows the overall total.
34. **No "Next goal" card when the target is reached** (the user, 2026-10-30; replaces that part of decision 15). The counter is all tap area, so a card risks accidental taps.
    - Reaching today's target fires an alert only: a strong success haptic and a short alert sound, the ring pulses, and a non-tappable banner reads "Today's goal is done" in the top area, outside the tap zone, and fades.
    - Nothing on screen navigates. The user leaves with back.
    - Counting continues into the overflow (confirmed); only a cap stops it.
    - **Sound and vibration are app-wide settings** (confirmed): "Goal sound" and "Vibration", both on by default, and the sound always follows the phone's silent mode. There are no per-goal sound settings.
35. **The counting circle sits at the bottom of the screen** (the user, 2026-10-30), within thumb reach above the safe area, instead of centred. The Arabic card and buttons stay at the top; the space between them is still tap area (decision 16).
36. **A tracker with a daily streak number shows a ring until it's reached, then a plain running total** (the user, 2026-10-30). For example, "whenever I can, streak counts at 100 a day": the counter rings toward 100, fires the decision 34 alert at 100, and then shows the total ("Total 12,450 · today 130") with no ring for the rest of the day. A tracker without a number never shows a ring (decision 30).
37. **Deleting a custom dhikr that goals use** (the user, 2026-10-30):
    - It deletes after one warning ("This ends 2 active goals; they'll move to History").
    - Its active and paused goals end into History as "Ended".
    - Goal history and counts stay, so lifetime totals don't change.
    - **Contract:** every goal keeps a snapshot of its dhikr's label (name, Arabic text, kind), so History and stats still read correctly after the dhikr is gone. A goal whose dhikr is missing on a device is shown from the snapshot, ended, and never counted into.
38. **Entering counts by hand: add or subtract N** (the user, 2026-10-30). For counts done away from the phone, or to fix a mistake.
    - On the counter, through "Adjust count" in the ⋮ menu and by long-pressing the number, a sheet opens with a number field, − / + and the day (today, or yesterday under decision 17).
    - Each adjustment is one count-log entry, positive or negative.
    - **Confirmed:**
      - a subtraction can't take the day below 0;
      - an addition stops at the cap;
      - when other goals share the count, the sheet names them ("Also changes Lifetime 70,000");
      - make-up (decision 18) applies to additions as it does to taps.
39. **Undo and reset, settled** (replaces decision 4's "to revisit", the user, 2026-10-30):
    - **Undo** is instant with no warning, and reaches back only through your own taps in the current counter session. For shared counts it naturally lowers every shared goal.
    - **Adjust** (decision 38) handles anything bigger or older.
    - **Reset today** always confirms and names the other goals it changes ("Reset today's Istighfar? This also changes Lifetime 70,000 (−120)"). It cancels only the entries this device has seen (decision 5).
40. **The empty state suggests one goal: Istighfar, at least 70 and aiming for 100 a day** (the user, 2026-10-30, "we value istighfar highly"). It shows on Home's Today's goals card and in My Goals.
    - A card reads "Say Isthighfar 100 times a day, at least 70", with a short virtue line. The line needs a source that passes content review (SOURCES.md), as with other virtues.
    - It has one primary button, **Start this goal**, which saves it straight away with the built-in Istighfar dhikr by its catalog ID. That works offline and signed out.
    - A secondary link, **Choose another goal**, opens a blank sentence.
    - Seasonal suggestions may come later.
41. **Spelling: "Isthighfar" everywhere** (the catalog spelling; the user, 2026-10-31). Other spellings (Istighfar, Astaghfirullah, استغفار) are search aliases. The catalog already supports this: `isthighfar` has en aliases Istighfar, Astaghfirullah and Astaghfirullahal Azim, and `dhikr_search.json` covers "astaghfirullah". Nothing new is needed.
42. **No limit on goals; a gentle note instead** (the user, 2026-10-31).
    - When a new goal would take the user above about 7 daily goals (the threshold can be tuned), the sentence preview shows a quiet line, roughly: "That's 8 goals a day. Small and steady is beloved: consider starting with fewer." The wording and the hadith need a source in SOURCES.md.
    - Saving is never blocked.
43. **Streaks count in the goal's own rhythm** (the user, 2026-10-31):
    - 🔥 N days for daily goals (and due days for specific weekdays: "🔥 12 Fridays");
    - 🔥 N weeks for weekly totals and "N days a week";
    - 🔥 N months for monthly and Hijri-month goals;
    - 🔥 N Ramadans (or occasions) for occasion goals.

    How it behaves:
    - The current period stays open and breaks the streak only once it ends unmet. Rows add the period's progress ("🔥 5 weeks · 2 of 3 days this week").
    - Make-up applies only to daily goals.
    - An excused day in an "N days a week" goal lowers that week's number by one.
    - Consistency for these goals uses the last 12 periods (decision 32).
44. **Conflicting goal edits from two devices: the first to reach the server wins** (the user, 2026-10-31).
    - This reuses 3b's version check on whole goal documents. The losing device takes the server's version.
    - The losing device shows a quiet notice with a one-tap retry: "Isthighfar was updated on another device; your pause wasn't applied. Pause again?"
    - Counts never conflict: the append-only log merges taps from every device.
45. **Counting input: screen taps only for now** (the user, 2026-10-31), plus the existing audio count and timer.
    - Screen-reader support is in scope: the tap area is a single "Count, 45 of 100" button, and every tenth count, the minimum and the target are announced.
    - **Later:** volume buttons as counters (up adds 1, down undoes within the session, off by default) and a dark "pocket mode". Needs an iOS feasibility check first.

## Reviewing slice 4a's judgment calls

46. **A missed day inside its make-up window doesn't break the streak** (the user, 2026-10-31; replaces slice 4a's judgment call that it breaks at once).
    - The day is **pending** while its window is open, and the streak keeps running. It breaks only when the window closes unfilled; a made-up day keeps the streak as before.
    - Rows show it, like "🔥 15 · make up Mon" (`goal_streak`'s `pending_make_up`). The goal stays in Today's goals while a day is pending, even on a day it isn't due.
    - Consistency doesn't count a pending day until its window closes.
    - With make-up off, a missed day still breaks the streak at once.
47. **Sessions carry a target only** (the user, 2026-10-31): no minimum or cap per session, and a session's streak amount is its target.
48. **Make-up also applies to total goals whose streak counts at a daily number** (the user, 2026-10-31; decision 29), such as "streak counts at 100 a day". It fills a missed day up to that number, always. A total without a daily number has no make-up.
49. **Accepted as slice 4a wrote them** (the user, 2026-10-31):
    - session IDs are derived from the session's kind, so a goal can't have two sessions of one kind;
    - a goal the server ends itself (its custom dhikr deleted) gets the server's UTC date;
    - the daily pace rules: rounded up, fixed for the day, and the default streak amount of a total with an end.
