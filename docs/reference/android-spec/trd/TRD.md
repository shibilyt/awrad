# Awrad Android — technical requirements document

**Scope:** technical shape and integration requirements for reconstructing the current Android app.  
**Authority:** current Android source/build/resources, root contracts, and the Phase 1 evidence inventory.  
**Not in scope:** iOS internals, API reimplementation, or new product behavior without a product decision.

## 1. Runtime and build target

| Concern | Requirement/evidence |
|---|---|
| Application shape | One Android application module, `:app`; one Activity (`MainActivity`) hosts the Compose app. |
| Language/UI | Kotlin, Jetpack Compose, Material 3, Navigation Compose, AndroidX Lifecycle. |
| Dependency injection | Hilt for application, repository, worker, and service dependencies. |
| Platform | `minSdk 26`; `compileSdk` / `targetSdk 36`. |
| Build types | Debug and release. Release requires explicit version values and an HTTPS API base URL; signing comes from external configuration. |
| Persistence | Room v15 with committed schemas and forward migrations; Preferences DataStore. |
| Network | Retrofit/Gson, OkHttp, bearer interceptor/authenticator; build-configured API base URL. |
| Background/media | WorkManager, Android AlarmManager/receivers, Media3 ExoPlayer/session/UI. |
| Prayer | Local Adhan calculation. |
| Locales | English, Arabic, Malayalam resources and RTL support. |

The source implementation and committed Room schemas are authoritative. Do not reuse historical build/model statements that disagree with this table.

## 2. Runtime architecture

```text
Activity + Nav Compose
  -> Compose route/screen
  -> feature ViewModel and domain policy
  -> repository
  -> Room / DataStore
  -> Flow/state back to UI
```

Remote and Android system adapters are selective:

- Retrofit/OkHttp for auth, community statistics, account-bound progress sync, and synchronized practice settings.
- AlarmManager/receivers for scheduled reminders; WorkManager for durable/deferred jobs and progress sync.
- Media3 preview/player/service for audio.
- Android Geocoder/LocationManager for city/current location input; Adhan for local prayer calculations.

The [architecture diagram source](../diagrams/architecture.architecture.json) and [rendered diagram](../diagrams/architecture.html) show the system boundary and ownership at a high level.

## 3. Navigation and application lifecycle

- Register the current 35 routes from the navigation destination/graph sources; four bottom roots are Home, Goals, Library, and Community. Community also owns a drawer.
- Onboarding completion removes its route from the back stack. If onboarding created a goal, route into its counter with Home beneath it.
- Support cold/warm notification intents for goal/slot counting and Wird routes; support verification app links for email confirmation.
- On process startup initialize reminder planning/obligation handling, periodic and immediate sync work, foreground sync coordination, and orphaned owned-audio cleanup.
- Treat transient restoration of audio position, open forms, and counter session UI after process death as **[UNKNOWN]** until measured.

See [Phase 1 §3](../analysis/phase-1-reconnaissance.md#3-screen-inventory) for all routes and major overlays.

## 4. Local model and persistence

Room v15 contains the current local model families:

| Family | Examples/ownership |
|---|---|
| Practice definitions | Dhikr, goals, recurrence, slots, reminders, seasonal template/day records. |
| Practice activity | Count entries and local aggregate/cache projections. Count uses signed 64-bit semantics. |
| Dhikr organization/media | User tags, dhikr-tag/category assignments, audio metadata/owned-file references. |
| Wird | Bundled/user definitions and persisted reading sessions. |
| Sync | Sync state, outbox/open count batches, entity shadows, transfer/inbox pages, count shadows, conflicts and receipts/metadata. |

Implementation requirements:

- Persist UUIDv4 identities as Room `TEXT` for synchronized dhikr/goals/slots/reminders/counts; built-in content also uses immutable canonical catalog keys.
- Keep local write plus outbox append atomic. UI uses repositories; it does not mutate Room tables or call progress APIs directly.
- Add forward Room migrations and committed schema snapshots. Never rewrite migration history or silently reset user data.
- Keep derived progress (`total_completed_count`, projections) separate from synchronization authority. Counts and goal relationships follow `contracts/progress-model/v1/`.
- Store preferences in DataStore, independent from goal/count entity tables.
- Keep built-in dhikr and Wird source assets versioned; validate their identities against their contracts.

## 5. API and account integration

### Android API surface observed

| Purpose | Method/path |
|---|---|
| Community aggregates | `GET api/community/stats` |
| Authentication | `POST api/auth/register`, `/login`, `/refresh`, `/forgot-password`, `/verify-email`, `/verify-email/resend`; `DELETE api/auth/logout` |
| Sessions | `GET api/auth/sessions`; `DELETE api/auth/sessions/{id}` and `/sessions` |
| Progress commands | `POST api/sync/v1/progress/commands` |
| Progress snapshot/delta | `POST api/sync/v1/progress/snapshots` and `/deltas` |
| Progress transfer pages | `GET api/sync/v1/progress/{kind}/{id}/pages/{page}` |
| Actor acknowledgement | `POST api/sync/v1/progress/actors/ack` |
| Practice settings | `GET api/sync/v1/practice-settings?installation_id=<uuidv4>`; `PUT api/sync/v1/practice-settings/policy`; `PUT api/sync/v1/practice-settings/device-context` |

Use typed DTOs/mappers and versioned contracts. Authenticated ownership comes from the token; do not add client-owned user IDs. Do not rename/remove wire fields without reviewing API and both mobile clients per root `CONTRACTS.md`.

### Network behavior

- Debug emulator API default is `http://10.0.2.2:4000/`; release must supply explicit HTTPS `AWRAD_RELEASE_API_BASE_URL`.
- Base URL path joining must preserve relative endpoint paths and a trailing-slash-safe base.
- Access token is attached by the auth interceptor. The authenticator refreshes expired access and retries according to the existing token lifecycle.
- Exact retry/backoff/timeout/error mapping for every endpoint is **[UNKNOWN]** in this feature inventory; consult current network implementation before a rebuild.
- Community stats are public, cached aggregates. Do not require auth for that endpoint unless the API contract changes.

## 6. Sync and consistency

Use the current v1 contract rather than a simpler last-write-wins implementation:

- Local practice mutations remain immediately available offline.
- A native transaction updates local projection and appends an immutable ordered outbox command.
- Positive count credits are idempotent. Decrement/reset consume only the user's observed eligible credits; they cannot create negative debt.
- Goal/custom-dhikr documents use optimistic concurrency. Preserve stale differing proposals as conflicts.
- Snapshot/delta sessions are materialized and paginated; install state atomically and advance the saved cursor only after all included canonical state is durable.
- Preserve account binding, actor sequence, command identity/hash, tombstones, installation scope, and sync exclusion from device backup.
- Visible progress overlays server canonical state with pending local changes without counting acknowledgements twice.
- Account practice policy is revisioned/shared; timezone/location device context is installation-specific. On stale policy update, apply the current server policy rather than blindly retrying the stale write.

Current sync guarantees and invariants are specified in [`docs/progress-sync-architecture.md`](../../docs/progress-sync-architecture.md) and `contracts/progress-sync/v1/`.

## 7. Background scheduling and notifications

- Use AlarmManager/receivers for current goal, daily, urgency, and Wird reminder paths; WorkManager for durable deferrable work and sync.
- Reconcile after boot, package replacement, wall-clock/timezone change, and exact-alarm permission changes.
- Use stable notification/alarm identity; updates should replace the intended schedule rather than create duplicates.
- Request `POST_NOTIFICATIONS` on Android 13+ at the current user flow; exact alarm capability and OEM battery rules remain conditional.
- Notification click intents must validate goal/slot/Wird IDs and use a safe fallback for deleted/stale destinations.
- The app declares `FOREGROUND_SERVICE_MEDIA_PLAYBACK`; active audio uses a non-exported service/notification lifecycle.

## 8. Media and files

- Use app-specific internal/owned directories for downloaded/custom audio; no broad storage/media read permission is observed.
- Preview uses Media3 player state; goal counting uses the counting service and its player lifecycle.
- Count only completed playback loops. Apply `audioCountPerPlay` and goal cap to each completion; stop playback at hard limit or zero applied increment.
- Custom audio import currently supports MP4/M4A/AAC/MP3/WAV MIME families, less than 10,000,000 bytes, and up to 10 minutes. Validate metadata/duration and stage before commit.
- Clean orphaned app-owned audio asynchronously; never delete an active or committed file as a failed-import side effect.
- Do not assume playback position survives process death; the current restoration contract is not established.

## 9. Permissions, security, and privacy

Observed manifest permission groups: Internet/network state, coarse/fine location, notification posting, exact alarms, boot receive, battery-optimization request, foreground media playback, vibration, and wake lock. Current UI requests coarse location; continuous tracking and fine-location necessity are not established.

Security requirements:

- Encrypt auth tokens using AES/GCM with Android Keystore-backed key material; keep under no-backup app storage.
- Release API must use HTTPS; manifest cleartext traffic is disabled.
- Exclude auth tokens, DataStore, Room/WAL/SHM, and app-owned audio from Auto Backup/device transfer under current rules.
- Do not log credentials or sensitive request payloads. Review network logging level by build type before release.
- Keep social statistics aggregate-only; sample social pages do not imply real user-content APIs.
- Do not add analytics or push SDKs without an approved product/privacy decision; neither is evidenced in current Android integration.

## 10. UI, accessibility, and localization

- Keep user-facing text in string resources and support en/ar/ml locale configuration and RTL.
- Preserve Compose screen-level state through ViewModels and lifecycle-aware collection; keep domain rules outside composable-only state.
- The counter must expose accessible count/target/slot state and operable count controls. Exact screen-reader labels and accessibility test coverage are **[UNKNOWN]** and require a validation pass.
- Apply current theme preference (light/dark/system), counter text size/spacing and keep-awake preference.
- Use the [design tokens](../design.md) and [mockups](../mockups/README.md) as source-derived references; mockups are structural, not pixel-accurate.

## 11. Quality and validation requirements

Repository evidence includes JVM unit tests and Android instrumentation/Compose tests. High-value suites cover behavior fixtures, Room migration/contracts, goal and count calculators, notification scheduling, sync, auth, Quran rendering, and sample Community UI. This documentation task did not run them. A reconstruction change should select focused tests from `awrad-android/TESTING.md`; broad release workflows are outside this TRD.

## 12. Recommended build sequence

1. Establish app shell, locale/theme, entry, navigation, and repository boundaries.
2. Implement Room models/migrations, bundled catalog, goal domain policies, and offline counter with migration/behavior checks.
3. Add dhikr library, custom content, audio preview/import, and Wird reader/session.
4. Add local prayer context, reminders, notification/deep-link lifecycle, and Android permission states.
5. Add auth/token storage and account-bound sync using current contracts.
6. Add Home, Settings, and Community surfaces; preserve the explicit boundary between real stats and sample social UI.

## 13. Technical unknowns and risks

- Exact endpoint retry/backoff, transient UI restoration, and error mapping need source inspection.
- Guest-only Room data is excluded from backup and lacks a demonstrated export recovery path.
- Alarm delivery varies with Android version, permissions, and device OEM policy.
- Social feature requirements and backend do not exist in inspected Android integration.
- Current PRD docs contain stale navigation, onboarding, and persistence statements; reconcile before adopting any of them.

