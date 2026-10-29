# Slice 3d: Practice settings

Status: In progress (contract accepted 2026-10-29)
Plan entry: [`docs/rebuild-plan.md`](../rebuild-plan.md), slice 3d
Playbook: [`docs/slice-playbook.md`](../slice-playbook.md)

## Goal

Users choose how their practice is measured: when the day resets (midnight or Maghrib), where they are, the prayer calculation method and madhab, the first day of the week, and corrections to the Hijri calendar for local moon sighting. All of it works signed out and offline on phones. Once signed in, the account's choices reach every device and the web through the change queue, while location stays on the device.

## Decisions (2026-10-29)

- **Account practice policy** (synced): day reset, calculation method, madhab, week start, Hijri corrections. **Device context** (never synced): time zone and location.
- **Location never leaves the device.** No server copy, no device-context endpoint. The web keeps its own location in the browser. Without one, the Maghrib reset falls back to midnight there, and Settings says so. A server copy can come later, with its own ADR, if server-side reminders need it.
- **Choosing a place:**
  - **"Use my location"** (coarse permission, one reading).
  - **A bundled city list,** shared in `contracts/` and generated into every app. It works offline and gives the same results everywhere. It has cities of 15,000 people or more in Kerala and the Gulf states, and 50,000 or more elsewhere.
  - **Phones only, when online:** the platform's own place search (Android `Geocoder`, iOS `CLGeocoder`), shown under the bundled results for places the list doesn't have.
  - **The web** uses browser location and the bundled list only. It has no server search endpoint and calls no third-party service.
- **Method and madhab both land now,** as in the frozen policy. The method moves Maghrib by up to 3 minutes for some methods; madhab affects only Asr, which no screen uses until the prayer-times slice.
- **First sign-in:** an account that has ever saved practice settings keeps them, and the phone takes them. An account that never has takes this phone's settings, but only if the user actually changed them; untouched defaults are never uploaded.
- **Two devices editing before they sync merge by setting,** with no prompt. Each setting you changed keeps your value; the others come from the other device. Hijri corrections merge month by month.
- **Hijri corrections UI:** Settings shows today's Hijri date with "Adjust this month". Near the end of a month it also offers the next month, since sightings are announced then. Earlier corrections are listed and can be removed.
  - It offers only the offsets the rules allow. Every month is 29 or 30 days, so a month usually moves one day from the month before, in one direction; two days takes two months in a row (found while writing the contract).
- **Defaults** are the frozen ones: midnight reset, Karachi method, Shafi'i madhab, Monday week start.

## Contract details (accepted 2026-10-29)

Settled while writing the contract (step 4):

- **City names are English only for now.** GeoNames' Arabic and Malayalam names need its 205 MB alternate-names file, which wasn't downloaded. So:
  - the display name is GeoNames' ASCII name ("Ponnani", not "Ponnāni");
  - Arabic- and Malayalam-script names, older English names (Calicut, Trivandrum) and the accented name are search-only aliases.
- **Size:** 11,976 cities, 2.6 MB of JSON, 680 KB gzipped.
- **Search** ranks name matches above alias matches: exact, then the start of the name, then the start of a later word. Within that, larger cities first.
- **Phones keep `base_document`** beside the policy: the server copy it was edited from, used for the merge.
- **New codes:**
  - `entity_id_invalid`: a policy whose ID isn't the account's;
  - `hijri_corrections_replaced`: a notice when a merge drops this phone's Hijri corrections.
- **`sync_receipts` states now carry `account_id`.** The server's fixture runner passes it in.
- **Settings alone don't count as data** for the first sign-in's Add / Erase question.

## Scope

| In scope | Out of scope (and where it goes instead) |
|---|---|
| Account practice policy as a change-queue entity (`practice_policy`): day reset, method, madhab, week start, Hijri corrections | Prayer times screen, high-latitude rules for Fajr and Isha (prayer-times slice) |
| Device context on phones and the web: automatic time zone, location (GPS, bundled cities, platform search on phones) | Reminders and notifications (later slice) |
| Maghrib from the adhan library on Android, iOS and web, pinned by a shared fixture | Maghrib on the server (not needed: the server never derives the practice day, STYLE §6) |
| Bundled city list in `contracts/`, generated into each app, with GeoNames attribution | Regional Hijri corrections published by the server (ADR-2026-10-26, later) |
| Practice settings screen on Android, iOS and web | Onboarding steps that set these (slice 6) |
| First-sign-in rule and merge-by-setting on conflict | Language, theme, sound, vibration (existing or later settings) |
| Settings preview: today's Hijri date and today's Maghrib time | Suggesting a method from the country (not now; maybe onboarding) |

Platforms: server ☑ (stores and validates the entity only) · Android ☑ · iOS ☑ · web ☑ (online; its own location in the browser)

## Behaviour inventory (step 2)

| Behaviour | Today (frozen apps) | Decision | Evidence |
|---|---|---|---|
| Day reset: midnight or Maghrib, default midnight | Account policy; Maghrib falls back to midnight without location | **Keep** | `awrad_server/lib/awrad_server/practice_settings/account_practice_policy.ex:7-44`; `awrad-android/.../util/DateProvider.kt:49-75` |
| The Maghrib instant starts the new day | `>=` on server, web and iOS; strict `>` in Android's `DateProvider` | **Keep `>=`** (already in `effective_practice_day.json`) | `awrad_server/lib/awrad_server/practice_day.ex:27-67`; `awrad-ios/awrad/awrad/Core/AwradCalculators.swift:3-14` |
| Calculation method: 10 methods, default Karachi | Account policy | **Keep** the same 10, renamed to adhan's names (below) | `account_practice_policy.ex`; `awrad-android/.../data/model/PrayerSettings.kt:3-36` |
| Madhab: Shafi'i or Hanafi, default Shafi'i | Account policy | **Keep** | same |
| Prayer maths | adhan on Android and web; a hand-written calculator on iOS, which can disagree | **Change:** adhan on all three clients, checked by a shared `maghrib_time` fixture | `awrad-ios/awrad/awrad/Core/AppServices.swift:995-1115`; `awrad_server/assets/js/practice_day.js:24-76` |
| Time zone | From the device or browser, uploaded per installation | **Keep** automatic; **drop** the upload | `awrad-android/.../data/sync/PracticeSettingsRepository.kt:109`; `awrad-ios/awrad/awrad/Core/PracticeSettingsSync.swift:239` |
| Location | GPS or platform geocoder on phones, Nominatim on the web; uploaded per installation, never read back | **Change:** stays on the device; bundled cities plus GPS everywhere, platform search on phones when online | `awrad_server/lib/awrad_server/practice_settings/device_context.ex:29-70`; `awrad_server/lib/awrad_server/location_search.ex:9`; `awrad-android/.../PrayerTimeRepository.kt:86-121` |
| Week start | Hard-coded Monday | **Change:** a setting, Saturday, Sunday or Monday, default Monday (`CONTEXT.md`) | `awrad-android/.../util/GoalProgressCalculator.kt:131-133`; `awrad-ios/awrad/awrad/Core/AwradCalculators.swift:156` |
| Hijri corrections | None; each platform's own Umm al-Qura | **New:** account corrections from ADR-2026-10-26, with the 1b table and rules | `awrad-android/.../util/DateUtils.kt:27-32` |
| Policy API | `GET /api/sync/v1/practice-settings`, `PUT /policy` with `expected_revision`, `PUT /device-context` | **Drop:** the policy is a change-queue entity; there's no device-context endpoint | `CONTRACTS.md:50-80` |
| Stale policy write | 409, and the client adopts the server's policy, losing its edit | **Change:** merge by setting | `awrad-android/.../PracticeSettingsRepository.kt:96-99` |
| Web settings form | Writes with no revision check (last write wins) | **Drop:** the web sends commands with `base_version`, like phones | `awrad_server/lib/awrad_server_web/controllers/user_settings_controller.ex:43-58` |
| First sign-in | Server wins, unless it still has untouched defaults and the phone has non-default choices | **Keep** the idea, in the change queue's terms (below) | `awrad-android/.../data/sync/PracticeSettingsReconciliation.kt:29-59`; `awrad-ios/awrad/awradTests/PracticeSettingsSyncTests.swift:13-54` |
| Sync only with a verified email (iOS client check) | iOS-only check | **Drop:** the change queue's own auth rules apply | `PracticeSettingsSync.swift:172-174` |
| Hint when Maghrib is chosen with no location | iOS only | **Keep** on every platform | `awrad-ios/awrad/awrad/.../SettingsView.swift:103-107` |

## Design

### The policy document

`practice_policy`, one per account. Its `entity_id` is the account's ID, and the server rejects any other ID.

```json
{
  "day_reset": "maghrib",
  "calculation_method": "karachi",
  "madhab": "shafi",
  "week_start": "monday",
  "hijri_corrections": [{ "year": 1448, "month": 9, "offset_days": 1 }]
}
```

- `day_reset`: `midnight` | `maghrib`.
- `calculation_method`: `karachi`, `north_america`, `muslim_world_league`, `egyptian`, `umm_al_qura`, `moonsighting_committee`, `dubai`, `kuwait`, `qatar`, `singapore` (adhan's names for the frozen ten).
- `madhab`: `shafi` | `hanafi`.
- `week_start`: `saturday` | `sunday` | `monday`.
- `hijri_corrections`: a valid set as in `urn:awrad:hijri-calendar:1#/$defs/corrections`, sorted by year and month. An invalid set is `rejected document_invalid`, with the `hijri_corrections_validity` codes as field errors.
- A delete is `rejected delete_not_allowed`, as for `dhikr_personal`.

### On phones

- **Each local profile has its own policy,** including the anonymous one. The profile records whether the user has changed it since it was created (`chosen`).
- **Device context belongs to the installation,** shared by every profile on the phone: the time zone (read live from the system), and the location `{latitude, longitude, name, source}` where `source` is `gps`, `city` or `search`.
- **The first sign-in,** whatever the user answers to "Add to my account" or "Erase":
  - the feed has a `practice_policy`: the phone takes it;
  - it doesn't, and the anonymous policy is `chosen`: the phone queues a put with `base_version` 0;
  - otherwise: nothing is sent, and the account stays unset.

  Two phones seeding the same unset account at once: the second put conflicts and merges by setting, with the defaults as its base.
- **Signing in to an account that already has a profile on the phone:** that profile's policy, as with tags.
- **Conflict:** the phone keeps the last server document it knew (the base). On a `conflict` receipt it takes the server's `current` document, re-applies every setting where its own document differs from the base, and queues a put on `current.version`.
  - Hijri corrections merge per month: months it added, changed or removed relative to the base win; the server's other months stay.
  - If the merged corrections are invalid, the server's corrections are kept, and the user gets a notice.

### On the web

- The policy comes from the changes feed and is saved as a one-command batch, as in 3b. Conflicts merge by setting the same way, without a prompt.
- Location is kept in browser storage for that account, so another account in the same browser doesn't inherit it (`CONTEXT.md`, Device context).

### Maghrib

- Android, iOS and web use the adhan library for their platform, with the policy's method and madhab, the device's location, and the local date.
- **`maghrib_time`** fixtures pin it within ±1 minute.
- Where the sun doesn't set or doesn't rise that day, there's no Maghrib, and the reset falls back to midnight.

### The city list

- `contracts/places/v1/cities.json`, generated from GeoNames (CC BY 4.0) by a script in `contracts/tools/`, with attribution in each app's About.
- Each city has its GeoNames ID, an English display name, country, region, coordinates, population and search-only aliases (see Contract details).
- **Which cities** (decided 2026-10-29), by GeoNames population:
  - at least 15,000 people in Kerala (GeoNames admin1 `IN.13`) and the six Gulf states: Saudi Arabia, the UAE, Kuwait, Qatar, Bahrain and Oman (`SA`, `AE`, `KW`, `QA`, `BH`, `OM`);
  - at least 50,000 people everywhere else.

  The script holds these regions and thresholds as data, so adding a region is a one-line change.
- Search behaviour, `city_search` fixtures:
  - case-, accent- and harakat-insensitive;
  - an exact match first, then a name's start, then a later word's start, with the display name ranked above aliases;
  - then by population.

## Domain and fixtures (step 3)

- **`CONTEXT.md`:** Account practice policy (defaults, method, madhab), Hijri correction, Device context (never leaves the device), Location.
- **`contracts/practice-settings/v1/`** (`urn:awrad:practice-settings:1`; [README](../../contracts/practice-settings/v1/README.md)):

  | Fixture | Run by | Cases |
  |---|---|---|
  | `practice_policy_validity.json` | All four | 28 |
  | `practice_policy_merge.json` | Android, iOS, web | 14 |
  | `practice_policy_first_sign_in.json` | Android, iOS | 10 |
  | `maghrib_time.json` | Android, iOS, web | 24, every method, polar days |

- **`contracts/places/v1/`** (`urn:awrad:places:1`; [README](../../contracts/places/v1/README.md)): `cities.json` and `city_search.json` (Android, iOS, web; 19 cases).
- **`contracts/sync/v1/`:**
  - `practice_policy` entity;
  - `sync_receipts`: `account_id` and 7 policy cases (server);
  - `apply_changes`: `base_document` and 7 policy cases (Android, iOS).
- **Checks:** `tools/check-practice-settings.mjs` compares every case with the reference rules in `tools/practice-settings-rules.mjs`, with Maghrib from adhan-js 4.4.6.

## Contract (step 4)

- **Operations:** none new. `post_sync_commands` and `list_sync_changes` carry the `practice_policy` entity (`PracticePolicyDocument`, the `entity_id_invalid` code, a request example).
- **ADR:** ADR-2026-10-29 "Practice settings travel in the change queue; location stays on the device" (Accepted). It supersedes both ADR-2026-09-09 practice-settings ADRs for the rebuild.

## Platform work (step 5)

| Project | Work | Validation | Status |
|---|---|---|---|
| awrad-server-next | Validate and store `practice_policy` in the change queue; runs `practice_policy_validity` | `mix validate` | ☐ |
| awrad-android-next | Policy per profile, device context, adhan Maghrib, city list and platform search, first-sign-in and merge rules, Practice settings screen | Gradle validation | ☐ |
| awrad-ios-next | The same in `AwradKit` | `scripts/validate` | ☐ |
| awrad-web-next | Practice settings page, browser location and city list, adhan Maghrib, merge rule | `npm run validate` | ☐ |

## Integration evidence (step 6)

| Flow | Android | iOS | Web | Notes |
|---|---|---|---|---|
| Signed out, offline: change every setting, set a city, see today's Hijri date and Maghrib (en) | ☐ | ☐ | n/a | |
| First sign-in seeds an unset account; a second device takes it (en) | ☐ | ☐ | ☐ | |
| Edit on two devices offline, then sync: merged by setting (en) | ☐ | ☐ | ☐ | |
| Adjust this Hijri month; the date changes on every device (ar, RTL) | ☐ | ☐ | ☐ | |
| Maghrib reset with no location shows the hint and uses midnight (ar, RTL) | ☐ | ☐ | ☐ | |

## Definition of done

Copied from the playbook; ticked before closing.

- [ ] In-scope items built on every platform, or the exclusion recorded here.
- [ ] Every shared rule has fixture cases, run by every implementing platform.
- [ ] Every operation has spec examples, server `assert_conforms` tests and client round-trip tests or mocks.
- [ ] Each project's validation passes locally, and `ci_ok` is green.
- [ ] Main flows checked on running builds in English and Arabic (RTL), with evidence above.
- [ ] On mobile, the core flows work signed out with the network off, and nothing adds a sign-in gate.
- [ ] All user-facing text is in en, ar and ml, and translation checks pass.
- [ ] Decisions are ADRs; none contradicts an accepted ADR without superseding it.
- [ ] Stale docs updated: `CONTEXT.md`, `STRUCTURE.md`, project `ARCHITECTURE.md`, `COMMANDS.md`.
- [ ] Nothing changed in the frozen projects.
