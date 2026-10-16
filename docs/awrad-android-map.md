# Awrad Android app map

This guide maps the current Android implementation: its user-facing areas, app structure, data flow, and platform services. The [interactive architecture diagram](awrad-android-architecture.html) gives the high-level path; its [JSON source](awrad-android-architecture.json) is reproducible with Archify.

Treat source and tests as implementation truth. The [Android PRD index](../awrad-android/prd/README.md) describes product intent and links to historical mockups; a declared route proves navigation exists, not that every action behind it is complete.

## Start from the core idea

Awrad is a **local-first practice tracker**. Dhikr content, goals, counting, and Wird reading are usable from local app state. Compose displays that state; repositories own persistence; Room stores the durable practice data. Account and network features sit at the edge, so ordinary practice does not acquire an incidental sign-in or network requirement.

The main path is:

```text
Person → Compose screen → feature ViewModel → domain rules / repository → Room
```

Selected features branch to Android services or the API:

```text
repositories → alarms / WorkManager / Media3
Room sync state → progress sync → Retrofit / OkHttp → Awrad API
```

The [interactive diagram](awrad-android-architecture.html) shows these boundaries and links its nodes to source locations.

## First principles and boundaries

1. **Practice state belongs locally.** Goal, count, dhikr, Wird, and reading-session data flows through Room-backed repositories. Built-in dhikr content is seeded locally; stable content IDs preserve relationships.
2. **Screens render and collect state.** Compose screens collect `StateFlow` from ViewModels and send user actions back through them. Composables should not own SQL, network requests, or alarm policy.
3. **Rules live outside presentation.** Goal configuration and update rules live under `domain/`; repositories coordinate DAOs and feature data. Multi-table goal changes remain transactional.
4. **Remote access is selective.** Auth uses Retrofit/OkHttp and encrypted token storage. Community stats are API-backed. The Android client also has a progress-sync engine and sync persistence; its presence does not prove complete server or cross-platform sync parity. See the [progress-sync architecture](progress-sync-architecture.md) and [v1 contract](contracts/progress-sync/v1/).
5. **Android effects have lifecycle boundaries.** `AwradApplication` initializes reminder and sync work. Alarm/receiver and WorkManager code handles background scheduling; Media3-backed services handle audio. Planning and policy have seams separate from Android scheduling effects.

Preferences and credentials are separate from practice records: preferences use DataStore, while auth tokens use encrypted storage backed by Android Keystore. Room is versioned with forward migrations and committed schemas under `app/schemas/`.

## Repository layout

Android is one Gradle application module, `:app`, inside the umbrella repository. Platform commands run from `awrad-android/`.

| Area | Owns |
|---|---|
| `app/src/main/java/.../MainActivity.kt`, `MainViewModel.kt`, `AwradApplication.kt` | Activity/app composition, startup state, process-level service wiring |
| `ui/navigation/` | Route definitions, one Compose `NavHost`, transitions, deep-link/route helpers |
| `ui/screens/` | Feature screens grouped by home, goals, library, counting, community, auth, settings, and Wird |
| `ui/components/`, `ui/theme/` | Shared Compose components, screen shell, typography, color, and theme |
| `domain/` | Domain models, goal-creation policy, validation, and feature rules |
| `data/database/` | Room database, entities, DAOs, migrations, and sync tables |
| `data/repository/` | Feature-facing persistence and data coordination |
| `data/network/`, `data/preferences/` | Retrofit service, auth interceptors/token lifecycle, DataStore, encrypted token storage |
| `data/sync/` | Progress-sync engine, repository, workers, scheduling, and foreground coordination |
| `di/` | Hilt bindings for Room, network clients, repositories, and platform dependencies |
| `notification/`, `service/` | Alarm/notification lifecycle, counting/audio services, downloads, receivers, and workers |
| `app/src/main/assets/wird_library/`, `app/src/main/res/` | Bundled Wird content and localized Android resources |
| `app/src/test/`, `app/src/androidTest/` | JVM unit/source tests and device/emulator instrumentation tests |

The project stack is Kotlin, Jetpack Compose, Hilt, Room, Retrofit/OkHttp, WorkManager, and Media3. The scoped [Android instructions](../awrad-android/AGENTS.md) document the module and migration rules.

## App shell and navigation

`MainActivity` hosts the Compose app. `AwradApplication` supplies Hilt and WorkManager startup wiring. The app observes `MainViewModel` state, applies the app theme, and chooses onboarding or the main graph. A single `NavHost` registers the destinations; route arguments and route builders are centralized in `AwradDestination`.

The four primary roots are **Home, Goals, Library, and Community**. The bottom bar appears at those roots; deeper screens remain in the same navigation graph. Community also opens a drawer with community destinations. Notification taps and Wird reminders can enter feature destinations directly.

Useful navigation sources:

- [`MainActivity.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/MainActivity.kt#L104) — startup gate, theme, NavController, drawer, and bottom-bar composition.
- [`BottomNavItem.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/navigation/BottomNavItem.kt#L14) — four root tabs.
- [`AwradDestination.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/navigation/AwradDestination.kt#L7) — route names, arguments, and builders.
- [`AwradNavGraph.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/navigation/AwradNavGraph.kt#L53) — `NavHost` and transitions; destination wiring continues through line 687.
- [`AwradShell.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/components/AwradShell.kt#L167) — lifecycle-aware shared screen wrapper.

## Screen and feature map

The route names below come from the current `AwradDestination` declarations, grouped by the feature they serve.

| Feature area | Destinations / screens | Main building blocks |
|---|---|---|
| **Onboarding and home** | `Onboarding`, `Home` | `MainViewModel`, `HomeViewModel`, dashboard, prayer-time card, and shortcuts into practice flows. [`HomeScreen.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/home/HomeScreen.kt#L93) |
| **Goals and counting** | `Goals`, `CreateGoal`, `GoalDetail`, `EditGoal`, `EditGoalSchedule`, `EditGoalReminders`, `Counting` | Goal creation/update rules under `domain/model/goalcreation/`; `GoalRepository`; `CountingViewModel`; Room goal, slot, reminder, and count data. Counting supports sessions and slot context, with audio and Quran-reading entry points. [`CountingScreen.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt#L188) |
| **Dhikr library** | `Library`, `LibraryCollection`, `Category`, `DhikrDetail`, `CreateDhikr`, `ManageTags`, `QuranDhikrReader` | Search/filter/catalog ViewModels and `DhikrRepository`; local built-in/custom content, tags, audio preview/download, and Quran dhikr text. [`LibraryScreen.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/library/LibraryScreen.kt#L289) |
| **Wird** | `WirdList`, `WirdCreate`, `WirdEdit`, `WirdDetail`, `WirdReader` | Bundled/library content, `WirdLibraryRepository`, reader ViewModel, Room Wird/session DAOs, and reading progress. [`WirdReaderScreen.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/wird/WirdReaderScreen.kt#L149) |
| **Community** | `Community`, `CommunityStats`, `CommunityChallenges`, `CommunityCircles`, `CommunitySaved`, `CommunityProfile`, `CommunityPostDetail`, `CommunityMessages`, `CommunityNotifications` | Stats use `CommunityStatsViewModel` and `CommunityStatsRepository`. Some feed actions and social destinations are demonstrative or placeholder surfaces; inspect their current screen implementation before assuming they are API-backed. |
| **Account and authentication** | `Login`, `Signup`, `VerifyEmail`, `ForgotPassword` | Auth ViewModels/repository, `AwradApiService`, access-token refresh, encrypted token storage. These are the routes that require account/network flows. |
| **Settings** | `Settings` | `SettingsViewModel` coordinates language/theme, counting preferences, audio downloads, and reminder/system settings through existing stores and services. [`SettingsScreen.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/settings/SettingsScreen.kt#L126) |

Route registration shows navigation coverage, not equal feature completeness. In particular, Community stats are connected to the API while several social surfaces remain demo/placeholder experiences.

## Data and service paths

### Local practice

1. A screen sends an action to its feature ViewModel.
2. The ViewModel applies feature/domain rules and calls a repository.
3. The repository reads or writes through Room DAOs, exposing observable state back to the UI.

`AwradDatabase` and its Hilt module define the persistence boundary and provide DAOs for dhikr, goals/schedules/reminders, count entries, Wird/sessions, tags, and sync. `DhikrRepositoryImpl` also seeds/synchronizes the built-in catalog while preserving stable identities. Schema changes require forward migrations and a committed Room schema.

### Account, API, and sync

`NetworkModule` creates the Retrofit/OkHttp clients. `AuthInterceptor` applies bearer tokens where required; the authenticator handles refresh, and token storage is encrypted. Auth, Community stats, and progress sync are separate API consumers. `ProgressSyncEngine` coordinates local sync state with remote transfers; background startup can schedule periodic and foreground coordination. Core practice screens do not depend on those transfers to save local progress.

### Background work and media

`AwradApplication` initializes reminder scheduling and the notification-obligation engine, reconciles schedules, starts progress-sync work, and queues owned-audio cleanup. `notification/` contains the planners, stores, schedulers, Android scheduling effects, alarm receivers, and boot rescheduling. `service/` contains counting/audio services and audio download/preview logic. These are lifecycle-sensitive areas; the policies are intentionally separated from platform effects where possible.

## Where to read next

1. Start with [`AwradApplication.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/AwradApplication.kt#L20) and [`MainActivity.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/MainActivity.kt#L104) for process and UI composition.
2. Read [`AwradDestination.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/navigation/AwradDestination.kt#L7) and [`AwradNavGraph.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/navigation/AwradNavGraph.kt#L53) for the screen map.
3. Follow one local feature from a screen to its ViewModel, repository, DAO, and entity—for example Home or Counting.
4. Read [`AwradDatabase.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/database/AwradDatabase.kt#L45), [`DatabaseModule.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/di/DatabaseModule.kt#L36), and [`DhikrRepositoryImpl.kt`](../awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/DhikrRepositoryImpl.kt#L45) for persistence and catalog setup.
5. Follow `AuthRepository` and `data/sync/` separately from offline practice; use the progress-sync and cross-project contract docs to check end-to-end server coverage.

For platform workflow and validation commands, see the root [`TESTING.md`](../TESTING.md), [`COMMANDS.md`](../COMMANDS.md), and Android [`AGENTS.md`](../awrad-android/AGENTS.md).
