# Awrad Android Next — architecture

A proof-of-concept rebuild of the Android app that tests stricter, **build-enforced** structure. It uses the same stack as `awrad-android`: Kotlin 2.0, Compose, Hilt, Room, DataStore and Navigation. Versions are pinned to match so lessons transfer directly.

Status: **scaffold only.** One placeholder screen proves the wiring end to end. Real feature slices come next.

## Why this exists

The architecture review of `awrad-android` found these problems:

- Domain rules copied across UI, repositories and notifications.
- Single files of 3,000–4,000 lines.
- Logic that can only be "tested" by reading source text.

This project checks whether module boundaries plus build-time rules prevent that. It will **replace `awrad-android`** (ADR 0003). Neither app is released, so there is no user data to carry over.

## Modules

```mermaid
flowchart TD
  app[":app<br/>shell, nav host, Hilt root"]
  feat[":feature:*<br/>screens + ViewModels"]
  domain[":core:domain<br/>pure Kotlin: types, rules, ports"]
  data[":core:data<br/>adapters + Hilt bindings"]
  db[":core:database<br/>Room"]
  ds[":core:designsystem<br/>theme + shared components"]
  testing[":core:testing<br/>one fake per port"]

  app --> feat & data & ds & domain
  feat --> domain & ds
  data --> domain & db
  testing --> domain
  feat -. test .-> testing
  domain -. test .-> testing
```

| Module | Plugin | May depend on |
|---|---|---|
| `:app` | `awrad.android.application` | anything |
| `:feature:*` | `awrad.android.feature` | `:core:domain`, `:core:designsystem` (and `:core:testing` in tests) |
| `:core:domain` | `awrad.jvm.library` (no Android) | nothing |
| `:core:data` | `awrad.android.library` + `hilt` | `:core:domain`, `:core:database` |
| `:core:database` | `awrad.android.library` + Room | nothing |
| `:core:designsystem` | `awrad.android.library` + `compose` | nothing |
| `:core:testing` | `awrad.jvm.library` | `:core:domain` |

**The key seam:** features never see adapters. A feature asks for a port, such as `OnboardingStatusStore` or `GoalRepository`. `:core:data` binds the real adapter in `DataModule`, and tests use the fake from `:core:testing`. That gives two adapters per port, which is the reason the seam exists.

## What the build enforces

| Standard | Mechanism | Problem in awrad-android it targets |
|---|---|---|
| Module graph above | `ModuleRulesConventionPlugin` fails configuration | No boundaries; anything imports anything |
| Explicit visibility | Kotlin explicit API mode in all library modules | Accidental public surface |
| No warnings | Kotlin `allWarningsAsErrors`, lint `warningsAsErrors` | Deprecations and lint debt pile up |
| Static analysis | detekt with compose-rules and ktlint formatting, `warningsAsErrors` | Inconsistent Compose and state patterns |
| ≤ 400 lines per file | `verifySourceFileSize` (part of `check`) | `CountingScreen.kt` at 4,341 lines |
| Committed schemas | Room Gradle plugin → `core/database/schemas/` | Same rule as today, now automatic |

Every rule lives in `build-logic/` or `config/detekt/detekt.yml`, so changing a standard is a reviewed diff.

## Patterns

- **Feature interface:** one `@Serializable` destination and one `NavGraphBuilder` extension. See `feature/onboarding/OnboardingDestination.kt`.
- **Screens:** a stateful `…Route` (ViewModel and side effects) wraps a stateless `…Screen(state, onAction, modifier)`. The stateless screen is previewable and can be UI-tested without Hilt.
- **ViewModels:** one `StateFlow<…UiState>` in, one `onAction(…Action)` out. A sealed `Action` type is the whole interface the screen uses.
- **Colours:** screens read roles from `MaterialTheme.colorScheme`. The raw palette is private to the design system, and nothing picks colours by checking whether the theme is dark.
- **Errors:** typed (enums or sealed types) and mapped to string resources at the UI edge.
- **Startup:** `AppShellViewModel` picks the start destination. `MainActivity` only hosts.

## Running it

```bash
./gradlew :app:installDebug                       # installs next to the real app
./gradlew assembleDebug testDebugUnitTest :core:domain:test detekt verifySourceFileSize lintDebug
```

The working app id is `app.awrad.awrad_dhikrgoalstracker.next`, so it installs next to awrad-android for side-by-side comparison. The final id is fixed before the first release.

## Decisions

Accepted ADRs live in [`docs/adr/`](docs/adr/README.md):

- One module per feature (0001).
- Plain Kotlin/JVM domain, no Kotlin Multiplatform (0002).
- **Replaces awrad-android** (0003). The schema is designed fresh and stays at Room version 1 until the first release. API, content IDs and domain behaviour stay shared with iOS and the server.
- Conventions are enforced by the build (0004).

## Open questions

- How the account/auth port maps onto the existing API contract (`CONTRACTS.md`). There is no network module yet.
- Final `applicationId` and the switch to forward migrations. These go in an ADR before the first release.
