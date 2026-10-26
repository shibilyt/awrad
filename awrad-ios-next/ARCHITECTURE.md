# awrad-ios-next — architecture

The Awrad iOS app, rebuilt to replace `awrad-ios/` (root ADR-2026-10-14).
- **Stack:** SwiftUI, SwiftData and Observation on iOS 18, built with Xcode 26.2 / Swift 6.2.
- **Status:** scaffold plus the slice 1 goal rules, the slice 1b Hijri calendar and the slice 2a accounts. A placeholder onboarding screen and home screen prove the wiring; features arrive in slices (`../docs/rebuild-plan.md`).

## Modules

All code lives in one local Swift package, `AwradKit`. The Xcode project holds only a thin app target (ADR 0003).

```mermaid
flowchart TD
  app["AwradNext app target<br/>composition root, root routing"]
  feat["Feature* targets<br/>Route + Screen + @Observable model"]
  domain["AwradDomain<br/>Foundation only: types, rules, ports"]
  data["AwradData<br/>SwiftData, UserDefaults, Keychain, API client"]
  ds["AwradDesignSystem<br/>colours, fonts, components"]
  testing["AwradTesting<br/>one fake per port"]
  app --> feat & data & ds & domain
  feat --> domain & ds
  data --> domain
  testing --> domain
```

| Target | May depend on | Isolation |
|---|---|---|
| `AwradDomain` | nothing (Foundation) | nonisolated |
| `AwradData` | `AwradDomain` | nonisolated (actors for state) |
| `AwradDesignSystem` | nothing | `@MainActor` by default |
| `Feature*` | `AwradDomain`, `AwradDesignSystem` | `@MainActor` by default |
| `AwradTesting` | `AwradDomain` | nonisolated |
| Test targets | whatever they test, plus `AwradTesting` | as tested |

**Enforcement:** the compiler blocks imports a target doesn't declare, and `scripts/check-module-rules.py` blocks declarations outside this table (ADR 0001).

**Platforms:** the package targets **iOS 18 and macOS 15**, so `swift test` runs domain, data and model tests on the Mac in milliseconds. Only app-level checks need a simulator.

## Goal model and rules (slice 1)

`AwradDomain` models the goal of [`contracts/goal-model/v1`](../contracts/goal-model/v1/README.md) as Sendable value types in `Goal.swift`: `Schedule`, `ActivePeriod`, `PausedRange`, `CountPolicy` (with its `CountThreshold` streak threshold), `GoalSession`, `Requirement`, `CompletionPolicy` and `CountEntry`.
- **Days** are `CalendarDay` (year, month, day), not `Date` or `DateComponents`. All day arithmetic goes through one Gregorian calendar fixed to UTC, never `Calendar.current`. `CalendarDay` is `Strideable`, so a window is a walkable `ClosedRange<CalendarDay>`.
- **Only valid goals exist.** `Goal`'s properties are read-only and its initializer `throws(GoalValidationError)`, whose `codes` are the contract's error codes in alphabetical order (`Goal+Validity.swift`, run against `goal_validity.json`). Every caller (fixture decoding, tests, later sync and import) goes through it, so the rules never handle a missing target.
- **One file per rule**, all pure: `EffectivePracticeDay.resolve`, `Goal.isDue(on:)`, `Goal.standing(on:counts:weekStart:)`, `Goal.daysPerPeriodStanding(…)`, `Goal.isCompleted(on:counts:)` and `Goal.currentStreak(…)`. They share `GoalEvaluation.swift`, the only place that decides whether a window meets its numbers (each session its own).
- **Fixture runner:** `AwradTesting/FixtureLoader.swift` reads `contracts/<model>/v<N>/fixtures/<rule>.json` from the repository (found by walking up from `#filePath`) and fails on a missing file, zero cases or a case that won't decode. `GoalModelFixtures` decodes each rule's `given` into domain values. `AwradDomainTests/GoalModelFixtureTests` runs every case as a parameterized test named by case ID.

The fixtures are the spec. Persistence of the full goal is slice 3; `GoalRecord` stores only a placeholder subset until then.

## Hijri calendar (slice 1b)

Hijri dates come from the shared Umm al-Qura table of [`contracts/hijri-calendar/v1`](../contracts/hijri-calendar/v1/README.md) (root ADR-2026-10-26), never from Foundation's `.islamicUmmAlQura`.
- **Bundling:** `scripts/generate-hijri-table.py` compiles `umm-al-qura.json` into `AwradDomain/UmmAlQuraTable.swift` (month starts as days since 1970-01-01), so the app works offline and nothing reads `contracts/` at runtime. Never edit the generated file; rerun the script.
- **Freshness check:** `scripts/validate` runs the script with `--check`, which fails when the Swift file differs from what the contract generates. `UmmAlQuraTableTests` also checks every decoded month start against the JSON.
- **Corrections:** `HijriCorrections` is a valid set of month-start corrections. Its initializer `throws(HijriCorrectionsValidationError)` with the contract's codes, so an invalid set can't exist. Its `calendar` (a `HijriCalendar`) is the table with them applied: `date(of:)` and `month(containing:)` return `nil` outside the table.
- **Rules:** the schedule kinds `hijriMonthDays` and `yearly` (Gregorian or Hijri `YearlyRange`s) and the period `hijriMonth`. Every rule that reads Hijri dates takes `hijriCorrections:` (default `.none`).
- **Runner:** `HijriCalendarFixtures` runs `hijri-calendar/v1/fixtures/`. `FixtureRunnerTests` fails if either fixture directory has a file no rule runs.

## Accounts (slice 2a)

An account is optional: everything offline works without one, and signing in or out never touches local practice data (root ADR-2026-10-26, ADR-2026-07-12).

- **Input rules** (`AwradDomain/AccountInput.swift`): `AccountInput.email`, `AccountInput.emailCode` and `PasswordPolicy` implement [`contracts/account-model/v1`](../contracts/account-model/v1/README.md). Lengths are Unicode scalars (after NFC for passwords), never `String.count`; whitespace is the contract's explicit set. `AccountModelFixtures` runs the fixtures, and `FixtureRunnerTests` covers the directory.
- **Port:** `AccountService` (`AwradDomain`), with `Account` and `AccountError`. The fake is `FakeAccountService`.
- **API client** (`AwradData/Network/`, ADR 0004):
  - `APIOperation` lists every operation the app calls, by `operationId`.
  - `APIClient` attaches a bearer token only to operations that take one, an `Idempotency-Key` (UUIDv4) to every `POST`, and `Accept-Language` (the app language) where the spec declares it.
  - Wire types are hand-written `Codable` structs (root ADR-2026-10-16). Problems are RFC 9457 and map to `AccountError` by `code` only.
  - Transport: an ephemeral `URLSession` without cookies or cache.
  - `OpenAPIContractTests` checks every used operation against `contracts/api/openapi.bundled.json` and round-trips every example.
- **Session** (`AwradData/Account/AuthSession.swift`, an actor, ADR 0005):

  | Concern | Behaviour |
  |---|---|
  | Storage | Installation ID and `device_session` (account, refresh token, pending refresh key) in the Keychain, `AfterFirstUnlockThisDeviceOnly`. The access token only in memory |
  | Reinstall | A `UserDefaults` marker; without it, Keychain leftovers are removed on first use |
  | Refresh | Single-flight. Sends an `Idempotency-Key` saved before sending and reused when retrying the same refresh. Drops credentials only on `refresh_token_invalid` or `refresh_reuse_detected` |
  | Authenticated calls | Refresh when there's no valid access token (60 s margin), and once more after `unauthenticated` |
  | Sign-in | `create_device_session` with the installation ID and `DeviceName.current()` (marketing name of the model, never "Apple device") |
  | Sign-out | `sign_out_device_session` with the refresh token, then credentials cleared, even offline. The installation ID stays |

- **UI** (`FeatureAccount`): one `AccountRoute` and `AccountModel` drive a `NavigationStack`: sign in, then pushed steps for create account, verify email (resend with a 60 s cooldown, or `Retry-After`), forgot password and reset password. Signed in, it shows the email and sign out. Verifying or resetting signs in with the password just typed. `AccountModel.Feedback` gives each handled error code its localized text:

  | Code | Shown as |
  |---|---|
  | `validation_failed` | its field code: `email_invalid`, `password_too_short`, `password_too_long`, `password_too_common` |
  | `invalid_credentials`, `verification_code_invalid`, `reset_code_invalid` | their own text |
  | `email_verification_required` | goes to the code screen, with a notice |
  | `rate_limited` | wait text, with `Retry-After` seconds when present |
  | `refresh_token_invalid`, `refresh_reuse_detected` | signed out |
  | no response | can't reach Awrad |
  | anything else (`malformed_request`, `idempotency_key_reused`, `unauthenticated`, unknown codes, `5xx`) | something went wrong |

- **Entry point:** the placeholder home screen's Account button opens `AccountRoute` in a sheet (`RootView`).
- **Base URL** (`AppComposition`'s `APIEnvironment`): Debug uses `http://localhost:4000`. `Config/Debug-Info.plist` (Debug only) allows plain HTTP to `localhost`. Release has no server yet, so it points at a `.invalid` host.

## Screens

- **`…Route`** is stateful. It owns the model (`@State`) and the exit callbacks.
- **`…Screen(state:send:)`** is stateless and previewable.
- **The model** is `@Observable`, with `private(set) var state` and `func send(_ action:) async`. The action enum is the screen's whole interface to the model.

See `FeatureOnboarding`.

## Persistence (ADR 0002)

- **Goals:** SwiftData behind the `GoalRepository` port, through `SwiftDataGoalRepository`, a `@ModelActor` (a placeholder subset until slice 3).
- **Small flags:** `UserDefaults` behind ports, through actors.
- **Secrets:** the Keychain through `KeychainStore` (ADR 0005); only the account session uses it.
- **Pre-release schema policy:** one schema, edited in place. If the stored schema can't be opened, `AwradStore.persistent()` deletes and recreates the dev store. Both the fallback and the single-version policy end at the first release.

## Resources

- **Fonts:** Manrope for interface text, Noto Naskh Arabic for Qur'anic and dhikr text. They're bundled in `AwradDesignSystem` and registered at launch with `AwradFonts.register()`.
- **Logo:** plain PNGs in the package bundle.
- **Strings:** String Catalogs per module (`Bundle.module`) plus the app's own. Xcode compiles them into `en`/`ar`/`ml` resources.

Command-line `swift build` copies catalogs uncompiled, so runtime localization is only exercised in Xcode builds.

## App identity

Bundle ID `app.awrad.awrad.next` and display name "Awrad Next", so it installs next to the frozen app. iPhone and iPad. The final identity is fixed before the first release.

## Decisions

See [`docs/adr/`](docs/adr/README.md). Cross-project decisions are in the root [`DECISIONS.md`](../DECISIONS.md).
