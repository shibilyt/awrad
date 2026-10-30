# Practice settings v1

How a user's practice is measured: when the day resets, the prayer calculation method and madhab, the week start, Hijri corrections, and where the device is. Slice 3d ([brief](../../../docs/slices/03d-practice-settings.md)); decision: root [`DECISIONS.md`](../../../DECISIONS.md) ADR-2026-10-29 "Practice settings travel in the change queue; location stays on the device".

| File | What it is |
|---|---|
| `practice-settings.schema.json` | `urn:awrad:practice-settings:1`: the policy document, the default policy, methods, and the device location |
| `fixtures/practice_policy_validity.json` | Which policy documents are valid, with `{field, code}` errors (all four) |
| `fixtures/practice_policy_merge.json` | Merge by setting after a conflict (Android, iOS, web) |
| `fixtures/practice_policy_first_sign_in.json` | Whose policy a phone ends up with at its first sign-in (Android, iOS) |
| `fixtures/maghrib_time.json` | Maghrib at a place on a date, with a method (Android, iOS, web) |

The effective practice day itself is `goal-model/v1/fixtures/effective_practice_day.json` (slice 1a), and Hijri dates with corrections are `hijri-calendar/v1/` (slice 1b). The city list is [`../../places/v1/`](../../places/v1/).

## Account policy and device context

| | Account practice policy | Device context |
|---|---|---|
| Holds | `day_reset`, `calculation_method`, `madhab`, `week_start`, `hijri_corrections` | Time zone (read live from the system or browser) and `location` |
| Lives | Phones: in each local profile, including the anonymous one. Server: the `practice_policy` entity of the change queue. Web: read from the changes feed | Phones: per installation, shared by every profile. Web: browser storage, per account |
| Syncs | Yes, through the change queue ([`../../sync/v1/`](../../sync/v1/)), when signed in | Never. No endpoint receives it |

## The policy document

```json
{
  "day_reset": "maghrib",
  "calculation_method": "karachi",
  "madhab": "shafi",
  "week_start": "monday",
  "hijri_corrections": [{ "year": 1448, "month": 5, "offset_days": -1 }]
}
```

- **Every member is required.** The default policy, which a new profile starts with: `midnight`, `karachi`, `shafi`, `monday`, no corrections.
- **`calculation_method`** uses adhan's names for the frozen apps' ten methods. Only `dubai` and `moonsighting_committee` move Maghrib (3 minutes after sunset).
- **`madhab`** changes only Asr, which no screen uses before the prayer-times slice.
- **`week_start`** is `saturday`, `sunday` or `monday` (`goal-model` `$defs/week_start`).
- **`hijri_corrections`** follow [`../../hijri-calendar/v1/README.md`](../../hijri-calendar/v1/README.md): offsets are absolute from the table and carry forward to later months, at most one per month, and every month stays 29 or 30 days. Clients write them sorted by year, then month; the server accepts any order.

## Validity

`fixtures/practice_policy_validity.json`. Errors are `{field, code}` with pointers into the document, sorted by field, then code:

| Problem | Error |
|---|---|
| A member missing | `required` on it |
| An unknown member, such as `location` or `timezone` | `not_allowed` on it |
| A value that isn't one of the member's values, including `null` and wrong case | `invalid` on it |
| `hijri_corrections` not a list | `invalid` on `/hijri_corrections` |
| A correction that isn't exactly `{year, month, offset_days}` as integers, with year 1400–1500, month 1–12, offset −2 to 2 | `invalid` on `/hijri_corrections/N` |
| The same month twice (checked only when every correction is well formed) | `duplicate` on each later one |
| A month that would have neither 29 nor 30 days (checked only when there are no duplicates) | `range` on `/hijri_corrections` |

The server answers an invalid put with `rejected document_invalid`, with the same errors under `/document`.

**What the UI offers.** Because every month is 29 or 30 days, a month can usually move only one day from the month before, in one direction. So, on every platform:
- "Adjust this month" offers only the offsets that keep the set valid; two days apart takes two months in a row.
- From day 29 of the current Hijri month (of the effective practice day), the next month can be adjusted too, since sightings are announced then.
- Earlier corrections are listed with Remove, which is disabled when removing that correction would leave an invalid set.
- The location can be cleared; the Maghrib reset then falls back to midnight, with the hint.

## Syncing the policy

- **One entity per account:** `entity_type` `practice_policy`, `entity_id` the account's ID. Any other ID is `rejected entity_id_invalid`, and a delete is `rejected delete_not_allowed` (`sync/v1/fixtures/sync_receipts.json`).
- **Saving an edit** follows the change queue's rules (`outbox_enqueue.json`): a never-sent put is replaced, otherwise a put is chained on the next version.
- **The base.** Phones keep `base_document` with the policy: the server copy the local document was edited from, or the default policy when they know none. An `applied` receipt, or a page with nothing queued for the policy, sets it to the server document. A page that arrives while an edit is queued leaves it alone (`apply_changes.json`).
- **Conflicts merge by setting** (`fixtures/practice_policy_merge.json`), and never open a "Changed on another device" prompt:
  - every setting where the local document differs from the base keeps the local value; the others take the server's;
  - Hijri corrections merge month by month the same way: a month added, changed or removed locally wins, and the server's other months stay;
  - if the merged corrections aren't valid, the server's corrections are kept and the user gets the notice `hijri_corrections_replaced`;
  - the result is sorted, becomes the local document, and the server copy becomes the base. If the result differs from the server's copy, it's queued as a put on the server's version; otherwise nothing is sent.
- **The web** does the same with the document it loaded as the base, then sends the merged policy straight away.
- **The policy is never removed from a phone.** A `rejected` put takes the server's copy when the receipt carries one; with `current: null` the phone keeps its document, its known version goes back to 0 and its base to the default policy. Clients validate before saving, so neither should happen in practice.

## The first sign-in

`fixtures/practice_policy_first_sign_in.json`. A profile records whether the user has **chosen** its policy: changed any setting since the profile was created, even back to a default.

- **From the anonymous profile into a new account profile**, whatever the user answers to Add to my account or Erase:
  - the account has a `practice_policy` in its changes feed: the phone takes it, with its version as the base;
  - it has none, and the anonymous policy is chosen: the phone keeps it and queues a create (`base_version` 0);
  - it has none, and the policy is untouched: nothing is sent, and the account stays without a policy until someone chooses one.
- **Into an account profile already on the phone:** that profile keeps its own policy; the anonymous one is discarded.
- **When it's decided:** at the end of the first complete pull after signing in. An edit made before then stays local; if the account turns out to have a policy, the account's replaces it.
- **Settings alone don't count as data** for the Add / Erase question: a profile with only a chosen policy is "empty", and adopted without asking.
- **Two phones seeding one account at once:** the second create conflicts (`sync_receipts` `practice_policy_second_seed_conflicts`) and merges with the default policy as its base.

## Maghrib and the day reset

`fixtures/maghrib_time.json`. Each client computes Maghrib with the adhan library (adhan-kotlin, adhan-swift, adhan-js) from:
- the local date of the instant, in the device's time zone;
- the device's location;
- the policy's method.

Clients must agree with the fixture within 60 seconds; expected values are adhan-js 4.4.6's, rounded to the minute. Where the sun doesn't set or doesn't rise that day there is no Maghrib (`null`), and the Maghrib reset falls back to midnight, as it does without a location (`effective_practice_day.json`). Settings shows a hint when the Maghrib reset is chosen without a location.

The server never computes Maghrib: it receives practice dates from clients (API STYLE §6).

## Checking

`npm test` in `contracts/` runs `tools/check-practice-settings.mjs`. It compares every case with the reference rules in `tools/practice-settings-rules.mjs` (Maghrib from adhan), checks that validity agrees with the schema, that the documents cases start from are valid, that every method has a Maghrib case, and that `apply_changes.json` merges practice-policy conflicts by this rule.
