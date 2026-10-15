# Phase 1 — Android Application Reconnaissance

## Scope and evidence labels

This report covers the current Android app in `awrad-android/`. Root API contracts and architecture notes are used only to identify Android integration boundaries. It does not specify iOS behavior or claim that a server capability is exposed in the Android UI.

- **[OBSERVED]** Directly present in current source, resources, manifest, build configuration, tests, or current repository contracts.
- **[INFERRED]** A product interpretation supported by multiple observed implementation details.
- **[UNKNOWN]** Not established by the evidence inspected so far; do not fill in during a rebuild without a product decision or further evidence.

No feature PRDs or final GOAL.md have been created. This is the Phase 1 inventory and evidence baseline.

## 1. Findings summary

- **[INFERRED]** Awrad is a local-first Islamic practice tracker centered on dhikr goals and counting, with prayer-time awareness, audio-assisted practice, and structured Wird reading. The existing product overview describes the same intent.
- **[OBSERVED]** Android is one Kotlin application module (`:app`) using a single Activity, Jetpack Compose, one Navigation Compose graph, ViewModels, Hilt, Room, DataStore, Retrofit/OkHttp, WorkManager, and Media3.
- **[OBSERVED]** The current navigation graph registers **35 destinations**. Home, Goals, Library, and Community are the four bottom-navigation roots. Community also has a navigation drawer.
- **[OBSERVED]** Dhikr, goals, counts, and Wird reading use local Room-backed repositories. Authenticated progress can synchronize with the API; routine local practice does not require sign-in or network access.
- **[OBSERVED]** Account/authentication, community statistics, progress synchronization, and practice settings use the API. The social feed and its secondary community pages are currently demonstrative UI with sample content and local-only or snackbar actions; they are not shown to be backed by social APIs.
- **[OBSERVED]** Local reminders, exact-alarm settings, boot/time-change rescheduling, daily remembrance work, urgency nudges, Wird reminders, and a media-playback foreground service integrate with Android lifecycle and system settings.
- **[OBSERVED]** Several existing Android PRDs are stale relative to current source. In particular, the old navigation PRD says three bottom tabs, the onboarding PRD describes a different default sequence, and the old data model uses integer IDs unlike the current UUID-based app model.

## 2. Application architecture

### Runtime path

The main local path is:

Person → Compose screen → feature ViewModel/domain rules → repository → Room → observable screen state.

Selective remote and Android paths are:

- Auth, community statistics, practice settings, and progress sync → Retrofit/OkHttp → Awrad API.
- Reminder policy and schedule planning → Android alarms, notification receivers, and WorkManager.
- Audio download/playback → app-specific files and Media3 service/player.
- Prayer calculations → local Adhan library using stored location and calculation preferences; city search uses Android Geocoder.

### Project and build inventory

| Area | Current evidence |
|---|---|
| Gradle modules | One application module, `:app`; no separate product Gradle modules are identified. |
| Build variants | Debug and release build types. Release configuration requires an HTTPS API base URL and explicit version values; signing values are supplied outside committed source. |
| Platform range | minSdk 26; compileSdk and targetSdk 36. |
| UI and dependency injection | Kotlin, Jetpack Compose/Material 3, Navigation Compose, AndroidX Lifecycle, Hilt. |
| Persistence | Room with committed schema history; current `AwradDatabase` version is 15. DataStore stores preferences. |
| Networking | Retrofit, Gson conversion, OkHttp, logging interceptor. API URL comes from build configuration. |
| Background/media | WorkManager/Hilt worker integration, Android alarms/receivers, Media3 ExoPlayer/session/UI. |
| Prayer calculation | Adhan library; prayer calculation is local. |
| Resources | English, Arabic, and Malayalam string/localization resources; app declares RTL support. Arabic resources and font assets are present. |
| Tests | JVM unit tests under `app/src/test/` and Compose/device instrumentation under `app/src/androidTest/`. The two source sets contain 158 files in total; tests were not run for this documentation pass. |

### App entry and navigation

**[OBSERVED]** `MainActivity` installs the Android splash screen, handles cold-start and `onNewIntent` notification/deep-link intents, enables edge-to-edge, then hosts `AwradApp`. `MainViewModel` reads onboarding and theme preferences. The app starts at Onboarding when not onboarded and Home otherwise.

**[OBSERVED]** Onboarding completion navigates to Home and removes Onboarding from the back stack. If onboarding created a first goal, the app then navigates to its Counting screen with Home beneath it. At the Home root, system Back clears the active navigation stack and exits the Activity.

**[OBSERVED]** Notification goal IDs open Counting with an optional slot ID. Wird notification/deep-link intents open a specific Wird or the Wird list. Verification app links open the email verification flow. The app accepts `awrad://` scheme intents and HTTPS verification paths on the configured app-link host.

## 3. Screen inventory

The following are registered navigation destinations, not a claim that every destination is a complete network-backed product capability. Ordinary child screens navigate back/up to their caller. Root tab and onboarding transitions are noted where they differ. Local state and API dependencies are summarized; feature PRDs must later record detailed actions and each loading, empty, validation, and error state.

| Screen ID | Destination / route | Purpose, entry/exit, and data boundary |
|---|---|---|
| SCREEN-ONB-001 | Onboarding — `onboarding` | First-launch setup; starts the app when onboarding is incomplete. Can optionally sign in, select location, enable reminder/audio setup, and create a first goal depending on flow. Completion goes to Home and optionally Counting. Uses preferences, local prayer/content data, selected auth/API operations, permissions, alarms, and audio download. |
| SCREEN-HOME-001 | Home — `home` | Main dashboard and shortcuts to Goals, Library, settings, collections, Wird, and Counting. Uses local goals/practice/preferences, calculated prayer times, and Wird state; includes a prayer-times sheet. Bottom-nav root. |
| SCREEN-GOAL-001 | Goals — `goals` | Browse goal states and open count/detail/edit/create flows. Uses local goal, slot, schedule, reminder, and count data. Bottom-nav root. |
| SCREEN-GOAL-002 | Create Goal — `create_goal?dhikrId={dhikrId}` | Create a local goal, optionally carrying a dhikr ID; successful creation navigates to Counting for the new goal. Uses dhikr catalog and goal domain rules. |
| SCREEN-GOAL-003 | Goal Detail — `goal_detail/{goalId}` | Inspect an individual goal and its progress/actions. Uses local goal/count records; offers edit/lifecycle actions. |
| SCREEN-GOAL-004 | Edit Goal — `edit_goal/{goalId}` | Edit goal configuration using local goal/domain rules. |
| SCREEN-GOAL-005 | Edit Goal Schedule — `edit_goal_schedule/{goalId}` | Edit recurrence/schedule using local schedule/goal data. |
| SCREEN-GOAL-006 | Edit Goal Reminders — `edit_goal_reminders/{goalId}` | Edit goal reminder policies; Android notification/exact-alarm reliability can affect delivery. |
| SCREEN-COUNT-001 | Counting — `counting/{goalId}?slotId={slotId}` | Count for a goal/slot, inspect or adjust progress, use sessions and audio, and open goal, edit, history, and Quran reading paths. Count writes are local-first; audio may use a foreground service. |
| SCREEN-LIB-001 | Library — `library` | Browse/search local dhikr and featured collections, and enter custom dhikr/Wird creation or detail flows. Bottom-nav root. |
| SCREEN-LIB-002 | Library Collection — `library_collection/{collection}` | Browse a selected built-in/featured collection and open dhikr detail or custom dhikr creation. Uses local catalog data. |
| SCREEN-LIB-003 | Category — `category/{category}` | Browse dhikr filtered by category and open detail/create-goal flows. Uses local catalog data. |
| SCREEN-LIB-004 | Dhikr Detail — `dhikr_detail/{dhikrId}` | View a local dhikr, actions, audio preview where available, and goal-creation path. |
| SCREEN-LIB-005 | Create Dhikr — `create_dhikr?dhikrId={dhikrId}` | Compose local custom dhikr data, categories/tags, and optional enrichment/audio details. Route declares optional dhikr ID. |
| SCREEN-LIB-006 | Manage Tags — `manage_tags/{dhikrId}` | Manage user tags/assignments in local data; route carries a dhikr ID. |
| SCREEN-QURAN-001 | Quran Dhikr Reader — `quran_reader/{dhikrId}?goalId={goalId}&slotId={slotId}` | Read full Quran dhikr text and retain optional counting goal/slot context. |
| SCREEN-WIRD-001 | Wird List — `wird_list` | Browse local/bundled and user-created Wird definitions. Entry points include Home and Library; opens create/detail. |
| SCREEN-WIRD-002 | Wird Create — `wird_create` | Create a user Wird definition locally. |
| SCREEN-WIRD-003 | Wird Detail — `wird_detail/{wirdId}` | Inspect a Wird, schedule/selection state, and open a reader or edit flow. |
| SCREEN-WIRD-004 | Wird Edit — `wird_edit/{wirdId}` | Edit a local user Wird definition. |
| SCREEN-WIRD-005 | Wird Reader — `wird_reader/{wirdId}/{partId}` | Read a selected part, navigate contents/parts, track the local reading session/progress, and use reader controls. |
| SCREEN-COMM-001 | Community — `community` | Guest/pending-verification/verified states. Guests see stats and auth entry points; verified users see For You, Explore, and Goals tabs. Community statistics are API-backed; feed cards and actions are demonstrative. Bottom-nav root with drawer. |
| SCREEN-COMM-002 | Community Stats — `community/stats` | Show API-backed aggregate community statistics with loading/error/retry/refresh state. |
| SCREEN-COMM-003 | Community Challenges — `community/challenges` | Displays sample challenge content and a local message action; no challenge API or durable participation state observed. |
| SCREEN-COMM-004 | Community Circles — `community/circles` | Displays sample circles; join toggles use saveable UI state and snackbar feedback, not a server-backed membership record. |
| SCREEN-COMM-005 | Community Saved — `community/saved` | Displays a sample saved-post surface; opening currently shows a message rather than a persisted post detail. |
| SCREEN-COMM-006 | Community Profile — `community/profile` | Demonstrative profile surface; no profile API/persistence observed. |
| SCREEN-COMM-007 | Community Post Detail — `community/post` | Demonstrative post detail destination; no post entity/API observed. |
| SCREEN-COMM-008 | Community Messages — `community/messages` | Displays hard-coded sample conversations; instrumentation test asserts dummy items. No messaging API observed. |
| SCREEN-COMM-009 | Community Notifications — `community/notifications` | Displays hard-coded sample notifications; instrumentation test asserts dummy items. No social notification API observed. |
| SCREEN-AUTH-001 | Login — `login?email={email}&origin={origin}` | Submit credentials, handle verified/pending states, and navigate to signup/forgot-password/verification. Uses Auth API and encrypted token storage. |
| SCREEN-AUTH-002 | Signup — `signup` | Submit account registration and move to the pending verification flow. Uses Auth API. |
| SCREEN-AUTH-003 | Verify Email — `verify_email?token={token}` | Verify an email token, resend verification, or move to sign-in. Uses Auth API; may be reached from app/universal links. |
| SCREEN-AUTH-004 | Forgot Password — `forgot_password?email={email}` | Request password recovery via Auth API. Android client has the request route; no reset-completion destination is registered. |
| SCREEN-SET-001 | Settings — `settings` | Edit profile/preferences, theme/language, counting behavior, prayer/calendar settings, reminders, audio downloads, sync state/actions, and data-reset/delete-goals actions. Uses local preferences/repositories and selected API sync; may request Android permissions or open system settings. |

### Non-route UI surfaces

**[OBSERVED]** Onboarding is one route containing scenes for opening, language, account, name, location/prayer setup, notification reliability, reminder presets, audio, goal introduction, and first-goal configuration. The normal first-run path currently displays only opening, language, account, and first-goal scenes. A separate six-step returning-user path is encoded in the ViewModel; its ordinary product entry point is not established by the route graph.

Other non-route overlays identified in current Compose source:

- Onboarding: email auth sheet, prayer calculation/madhab sheet, OEM battery guidance dialog, and Android permission/system-settings actions.
- Home: prayer-times sheet.
- Goals: goal detail sheet, goal composer selectors/multiselect, prayer-relation sheet, and confirmation dialog.
- Counting: slot details, session target, text size/full text, count history, estimates, playback speed, and count/availability dialogs.
- Dhikr: action sheet, add-goal confirmation, optional-details sheet, category/tag selector sheets, and Quran-reader dialog.
- Settings: option selectors, location search dialog, reminder time picker, reset/delete confirmations, and OEM battery guide.
- Wird: contents sheet, time picker, and edit/delete confirmation surfaces.
- Community: drawer, feed tabs, and snackbar feedback.

Exact labels, conditional visibility, and each alternate/error state remain feature-specification work.

## 4. Feature inventory

Candidate stable feature IDs for Phase 2 decomposition:

| Feature ID | Capability and user goal | Main screens / dependencies | Current evidence status |
|---|---|---|---|
| FEAT-SETUP-001 | Complete first-run setup and optionally create a first goal. | Onboarding; preferences, auth, prayer setup, notification settings, audio, goal creation. | **[OBSERVED]**; current first-run sequence differs from legacy PRD. |
| FEAT-AUTH-001 | Register/sign in, verify email, recover password, and manage sessions. | Community, onboarding auth sheet, Login, Signup, Verify Email, Forgot Password, Settings/community session UI; Auth API. | **[OBSERVED]** for implemented API flows; exact UI/backend recovery completion differs by client/server. |
| FEAT-HOME-001 | Review today/practice context and reach common actions. | Home; local goals/counts/Wird, prayer calculations, settings/preferences. | **[OBSERVED]**. |
| FEAT-GOAL-001 | Create, inspect, edit, schedule, and configure goal reminders. | Goals, Create Goal, Goal Detail, three edit screens; Room and domain validation. | **[OBSERVED]**. |
| FEAT-COUNT-001 | Count manually or with audio, choose slot/session context, and review/adjust count history. | Counting, Quran reader, goal screens; Room, counting service, Media3. | **[OBSERVED]**. |
| FEAT-PROGRESS-001 | Derive goal totals, daily history, streak/calendar/progress summaries. | Home, Goals, Counting, Settings; local count data/domain calculators. | **[OBSERVED]**; exact display/rules require feature pass. |
| FEAT-LIBRARY-001 | Browse/search/filter built-in and custom dhikr and featured collections. | Library, Collection, Category, Detail; Room and bundled catalog. | **[OBSERVED]**. |
| FEAT-DHIKR-001 | Create/manage custom dhikr and user tags/categories. | Create Dhikr, Manage Tags, library/detail; Room and sync support. | **[OBSERVED]**. |
| FEAT-AUDIO-001 | Download/manage audio, preview it, and use audio-assisted counting. | Onboarding, Settings, Dhikr Detail, Counting; app files and Media3. | **[OBSERVED]**. |
| FEAT-QURAN-001 | Read Quran dhikr text in context of a dhikr/goal. | Quran Dhikr Reader and Counting/Dhikr Detail entry points; bundled/local content. | **[OBSERVED]**. |
| FEAT-WIRD-001 | Browse/create/edit structured Wird and record reading progress. | Home, Library, Wird list/detail/editor/reader; bundled content, Room sessions. | **[OBSERVED]**. |
| FEAT-PRAYER-001 | Configure location and calculation preferences and show local prayer times/day context. | Onboarding, Home, Settings; Android Geocoder/LocationManager, Adhan, DataStore. | **[OBSERVED]**. |
| FEAT-REMIND-001 | Schedule goal, daily, urgency, and Wird reminders with Android reliability settings. | Onboarding, goal screens, Settings, notification surfaces; AlarmManager/WorkManager/receivers. | **[OBSERVED]**. |
| FEAT-SYNC-001 | Sync account-bound practice/content changes and expose sync health/conflicts. | Settings and background sync; API plus Room outbox/shadow/inbox/conflict data. | **[OBSERVED]** in current Android implementation and root v1 contract. |
| FEAT-COMM-STATS-001 | View community aggregates. | Community and Community Stats; GET community stats API. | **[OBSERVED]**. |
| FEAT-COMM-SOCIAL-001 | Explore sample feeds, posts, challenges, circles, saved items, messages, and notifications. | Community and its eight child routes. | **[OBSERVED]** as UI prototypes; real social service semantics are **[UNKNOWN]**. |
| FEAT-SETTINGS-001 | Change app preferences, configure practice context, and manage local data. | Settings; DataStore, Room repositories, audio files, sync status. | **[OBSERVED]**. |
| FEAT-LOCALIZATION-001 | Select supported app language and render Arabic/RTL and other localized content. | Onboarding and Settings plus all screens; Android resource locales. | **[OBSERVED]** for en/ar/ml resource configuration; translation completeness by string is not audited here. |

## 5. Proposed product hierarchy

This is a product grouping, not a copy of the Gradle/package tree:

- **MOD-SETUP** — onboarding, language/account choice, optional practice setup, first-goal creation.
- **MOD-PRACTICE** — goals, counting, schedules/slots, progress/history, completion and lifecycle behavior.
- **MOD-DHIKR-LIBRARY** — built-in/custom dhikr, browsing/search, categories/tags, audio, Quran reader entry points.
- **MOD-WIRD** — bundled/custom Wird definitions, schedules/selection, reader, session progress.
- **MOD-PRAYER-REMINDERS** — location, prayer calculation, day/calendar settings, local notifications and Android reliability.
- **MOD-ACCOUNT-SYNC** — auth, email verification, sessions, account-bound progress sync and conflict reporting.
- **MOD-COMMUNITY** — community statistics (implemented API) and separate demonstrative social UI.
- **MOD-SETTINGS** — user preferences and local-data management; owns settings UI while delegating domain changes to their modules.
- **Cross-cutting platform capabilities** — Room/DataStore, navigation/deep links, audio files/Media3, Android lifecycle/work, localization/theme, notification scheduling, and API transport.

Likely journeys connecting modules:

1. First launch → language/account choice → first-goal setup → Home → Counting.
2. Home/Goals → goal create/edit/schedule/reminders → Counting → history/detail.
3. Library/collection/category → dhikr detail → create a goal → Counting; or create/manage custom dhikr and tags.
4. Home/Library → Wird list/detail → reader → persisted session progress.
5. Community guest → sign in/sign up → pending email verification → verified account; then API stats and demonstrative feed tabs.
6. Settings/onboarding → location and prayer rules → local prayer display/day calculation → configured reminders.
7. Goal/Wird notification or app link → relevant Counting, Wird, or verification route on cold or warm Activity start.
8. Local practice mutation → durable sync work when an eligible verified account is available; otherwise local practice remains usable.

## 6. Data, storage, and API inventory

### Local data

**[OBSERVED]** Current Room database version 15 contains entities for dhikr, goals, goal recurrence (including weekdays/month days/dates), slots, reminders, season templates/days, count entries, Wird definitions/sessions, user tags and dhikr-tag/category assignments, audio assets, and progress-sync state/outbox/open-count-batch/entity-shadow/inbox-page/count-shadow/conflict records. Room schemas and forward migrations are committed under `app/schemas/` and the database migration sources.

Built-in dhikr and Wird content is shipped locally; a Dalail al-Khayrat JSON asset is present. UUID-like `AwradId` identities and current schema/contract data are authoritative, not the older integer-ID PRD model.

DataStore stores app/practice preferences. Auth tokens are stored as encrypted files under no-backup app storage using AES/GCM and an Android Keystore key. Audio is stored in app-specific directories. WorkManager stores durable scheduled work.

**[OBSERVED]** Manifest permits Android backup but backup/device-transfer rules exclude auth token storage, DataStore preferences, the Room database and its journal/WAL/SHM files, and owned/downloaded audio directories. Therefore Android backup is not the restoration path for local practice records; authenticated progress sync is a separate path.

### API and external service inventory

**[OBSERVED]** `AwradApiService` declares:

- Auth register, login, refresh, logout, forgot-password request, verify/resend email, list/revoke sessions.
- GET community statistics.
- Progress sync commands, snapshots, deltas, transfer pages, actor acknowledgements.
- GET/update practice settings, including day reset, calculation method, madhab, timezone, and optional device location context.

The app uses bearer-token interception/refresh and encrypted token storage. Root `CONTRACTS.md` describes the current Phoenix API contract, verification links, and progress-sync v1. No secrets or credentials are documented here.

City search uses Android Geocoder, requesting up to five results after a two-character query; the ViewModel debounces typing. GPS selection requests coarse location and reads last-known network-provider location, falling back to GPS provider. The implementation does not establish a third-party geocoding API. Prayer calculations use Adhan locally.

No analytics SDK or social-feed API is evident in the inspected Android dependency/API surfaces. Whether either is intended is **[UNKNOWN]**. No push messaging integration is evident in the inspected manifest; notifications appear locally scheduled.

## 7. Permissions and Android platform behavior

Manifest-declared permissions and observed purpose:

| Permission | Observed/derived use |
|---|---|
| INTERNET, ACCESS_NETWORK_STATE | API calls and network-aware sync. |
| ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION | Location setup/prayer context. Current UI requests coarse permission; no fine-location request was found in the indexed code searched. Fine permission’s separate need is **[UNKNOWN]**. |
| POST_NOTIFICATIONS | Runtime notification consent on Android 13+; requested from onboarding notification setup, goal creation, and Settings. Denial can prevent visible notification delivery. |
| USE_EXACT_ALARM, SCHEDULE_EXACT_ALARM | Time-sensitive reminder scheduling and exact-alarm access/settings handling. The app checks reliability and can open Android exact-alarm settings. |
| RECEIVE_BOOT_COMPLETED | Reschedule/reconcile after boot, package replacement, timezone/time changes, and exact-alarm access changes. |
| REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | Reminder reliability guidance/system settings path. OEM battery behavior is also explained in a dialog. |
| FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK | Media/counting foreground service playback. |
| VIBRATE, WAKE_LOCK | Haptics and service/playback runtime behavior. |

No shared-storage or media-read permission appears in the manifest; audio is handled in app storage. Exact denial/permanent-denial behavior and OEM-specific delivery variance need per-feature extraction in later phases.

## 8. Background work, notifications, and lifecycle

**[OBSERVED]** At process startup, `AwradApplication` initializes the reminder scheduler, starts the notification-obligation engine and issues a startup request, starts periodic and immediate progress-sync work, starts foreground sync coordination, and asynchronously cleans orphaned owned-audio files.

Current Android components include:

- Goal reminder alarms, dismiss receiver, urgency nudge receiver/retry flow, daily remembrance worker, and Wird reminder receiver/scheduler.
- Boot/time/timezone/package replacement/exact-alarm-change rescheduling through `BootRescheduleReceiver`.
- Hilt-configured WorkManager workers, including progress sync and deferrable daily work.
- `DhikrCountingService`, declared as a non-exported media-playback foreground service.
- Notification taps that route to goal/slot counting or a Wird destination; email verification links route to Verify Email.

Room and DataStore preserve durable product state; onboarding step uses SavedStateHandle; WorkManager and alarms cover persisted background scheduling. Exact recovery of every transient screen, player, and in-progress counting UI after process death is **[UNKNOWN]** pending targeted lifecycle review.

## 9. Cross-cutting requirements visible in current implementation

- **Local-first behavior [OBSERVED]:** goal, count, dhikr, and Wird use local state; API access is selective.
- **Identity/sync [OBSERVED]:** account-bound progress sync has durable local sync records, background scheduling, and Settings health/conflict visibility.
- **Prayer/date semantics [OBSERVED]:** stored location and calculation preferences feed local prayer calculations and effective-day logic; day reset/calendar are configurable.
- **Notifications/reliability [OBSERVED]:** reminders need Android permission/exact-alarm/battery handling and lifecycle rescheduling.
- **Localization [OBSERVED]:** en/ar/ml locales and RTL support are configured. User-facing strings are resource-backed.
- **Theme [OBSERVED]:** explicit light/dark/system preference controls theme; app otherwise follows system.
- **Security/privacy [OBSERVED]:** encrypted auth token storage, HTTPS release URL validation, cleartext traffic disabled in the manifest, and explicit backup exclusions are present.
- **Analytics [UNKNOWN]:** none identified in the inspected app dependencies/API list; absence from this pass is not a product requirement.

## 10. Known unknowns, ambiguities, and reconstruction gaps

1. **Product audience and success criteria — [INFERRED/UNKNOWN].** The existing product overview describes Muslim users building dhikr habits and structured Wird practice. User personas, measured outcomes, priorities, and product-level success criteria are not established by runtime code.
2. **Community scope — [UNKNOWN].** Stats are API-backed, but social pages/feed use hard-coded samples or transient local actions. Whether these are intended final features, demos, or unfinished work and what backend semantics they should have cannot be derived.
3. **Password reset completion — [UNKNOWN for Android].** Android exposes the forgot-password request but no reset-completion route. Root contract documents a server reset endpoint and iOS flow; the Android product UX after email delivery is not established.
4. **Returning-user onboarding entry — [UNKNOWN].** A six-step returning-user sequence exists in onboarding state, but the current NavGraph only shows onboarding automatically for users not marked onboarded. Its intended entry point is not established in the inspected wiring.
5. **City/GPS edge states — [UNKNOWN].** Geocoder behavior is platform/device dependent; no result, disabled location, denied permission, and stale last-known location need detailed acceptance rules. Current GPS code only reads last-known location and may produce no selection.
6. **Network behavior detail — [UNKNOWN until feature pass].** Exact request timeout, retry/backoff, cache lifetime, community-stat auth requirements, and per-endpoint error mapping need inspection before reconstruction. Progress-sync policy is separately specified by current root contracts.
7. **Notification edge cases — [UNKNOWN until feature pass].** Exact alarm permission denial, battery restriction/OEM variation, reboot races, timezone changes, duplicate/stale work, and notification-action behavior need a requirement-by-requirement state analysis.
8. **Transient restoration — [UNKNOWN].** Durable Room/DataStore/scheduled work are clear, but the restoration contract for audio position, unfinished UI forms, and counting sessions after process death is not yet complete.
9. **Offline-only data recovery — [OBSERVED GAP].** Android backup excludes practice databases/preferences/audio. Without authenticated sync, cross-device restoration is not demonstrated.
10. **Analytics/push — [UNKNOWN].** No analytics integration or push receiver was found in the inspected Android graph/manifest. Do not add one to a rebuild without evidence or product direction.
11. **Full UX state coverage — [UNKNOWN until later phases].** Each of the 35 routes needs exact empty/loading/error/validation/interruption/back-state capture. This reconnaissance establishes ownership and major dependencies, not exhaustive screen-by-screen acceptance criteria.

### Existing documentation drift (implementation wins)

- `prd/17-navigation-app-structure.md` says there are three bottom tabs and omits Community as a root; current source uses Home, Goals, Library, and Community.
- `prd/03-onboarding.md` describes a five-step default flow with name, audio, and location. Current code defines ten possible scene indices, but the normal first-run visible path is opening, language, account, and first goal; the longer setup screens are available in a separate encoded returning-user path.
- `prd/02-data-model.md` describes integer auto-increment IDs and a smaller legacy schema. Current Room v15, `AwradId`, committed schemas, migrations, and the root progress-model contract are authoritative.
- The existing PRD mockup count is not a source of route completeness: current `AwradDestination`/`AwradNavGraph` registers 35 destinations, plus in-route scenes and modal surfaces.

## 11. Evidence index

| Evidence | Supports |
|---|---|
| `app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/navigation/AwradDestination.kt` and `AwradNavGraph.kt` | Route names/arguments, 35 destinations, screen wiring, navigation callbacks, onboarding and goal completion transitions. |
| `MainActivity.kt`, `MainViewModel.kt`, `AwradApplication.kt` | Process entry, startup gate, intents, deep links, notification navigation, background initialization. |
| `ui/screens/onboarding/OnboardingScreen.kt`, `OnboardingViewModel.kt`, `OnboardingPrayerScene.kt` | Onboarding scenes/visible-step variants, account choice, location/GPS permission, reminder reliability, audio, first goal. |
| `ui/screens/community/CommunityScreen.kt`, `CommunityLandingFeed.kt`, `CommunityDestinations.kt`; `CommunityInboxScreensTest.kt` | Auth-conditioned community UI, sample feed actions, static secondary destinations, dummy messages/notifications. |
| `data/database/AwradDatabase.kt`, `data/database/entity/`, `data/database/dao/`, `app/schemas/` | Current persisted model and migration history. |
| `data/repository/`, `domain/` | Local repositories and goal/count/prayer/Wird rules. |
| `data/network/AwradApiService.kt`, auth/network repositories, root `CONTRACTS.md` | API operations and cross-project wire contracts. |
| `data/preferences/`, `EncryptedAuthTokenStorage.kt` | Preference and credential storage boundaries. |
| `notification/`, `service/`, `data/sync/` | Alarm/notification lifecycle, audio/counting service, progress sync and work. |
| `app/src/main/AndroidManifest.xml`, `app/build.gradle.kts`, `app/src/main/res/xml/` | Permissions, app links, services/receivers, build variants, SDKs, backup rules, network policy, locale config. |
| `app/src/main/res/values*/strings.xml`, `app/src/main/assets/wird_library/` | Localized UI resources and bundled devotional content. |
| `app/src/test/`, `app/src/androidTest/` | Existing domain/unit and device/Compose test evidence; no tests were run during this documentation-only phase. |
| `prd/01-product-overview.md` through `prd/17-navigation-app-structure.md` | Existing declared product intent and historical specification; use only after reconciling with current code. |

## Phase 1 exit

Phase 1 reconnaissance is complete. The next phase should confirm the candidate product modules/features and journeys in Section 5, assign final stable IDs, and retain the observed-vs-inferred distinctions above. Feature PRDs and GOAL.md are intentionally deferred until their later phases.
