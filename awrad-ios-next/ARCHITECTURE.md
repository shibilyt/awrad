# awrad-ios-next — architecture

The Awrad iOS app, rebuilt to replace `awrad-ios/` (root ADR-2026-10-14).
- **Stack:** SwiftUI, SwiftData and Observation on iOS 18, built with Xcode 26.2 / Swift 6.2.
- **Status:** scaffold plus the slice 1 goal rules, the slice 1b Hijri calendar and the slice 2a and 2b accounts. A placeholder onboarding screen and home screen prove the wiring; features arrive in slices (`../docs/rebuild-plan.md`).

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

## Accounts (slices 2a and 2b)

An account is optional: everything offline works without one, and signing in or out, or deleting the account, never touches local practice data (root ADR-2026-10-26, ADR-2026-07-12).

- **Input rules** (`AwradDomain/AccountInput.swift`): `AccountInput.email`, `AccountInput.emailCode` and `PasswordPolicy` implement [`contracts/account-model/v1`](../contracts/account-model/v1/README.md). Lengths are Unicode scalars (after NFC for passwords), never `String.count`; whitespace is the contract's explicit set. `AccountModelFixtures` runs the fixtures, and `FixtureRunnerTests` covers the directory.
- **Port:** `AccountService` (`AwradDomain`), with `Account`, `AccountSession` and `AccountError`. The fake is `FakeAccountService`.
- **API client** (`AwradData/Network/`, ADR 0004):
  - `APIOperation` lists every operation the app calls, by `operationId`.
  - `APIClient` attaches a bearer token only to operations that take one, an `Idempotency-Key` (lowercase UUIDv4) to every `POST`, and `Accept-Language` (the app language) where the spec declares it. An operation's `path` is the spec's template; `pathParameters` fill its `{name}`s, and `queryParameters` lists the query names it may send.
  - Nullable response fields (`AccountSession.name`, `next_cursor`) are encoded as `null`, never left out, so a round trip is exact. Unknown `kind` or `platform` values become `.other`.
  - Wire types are hand-written `Codable` structs (root ADR-2026-10-16). Problems are RFC 9457 and map to `AccountError` by `code` only.
  - Transport: an ephemeral `URLSession` without cookies or cache.
  - `OpenAPIContractTests` checks every used operation against `contracts/api/openapi.bundled.json` and round-trips every example.
- **Session** (`AwradData/Account/AuthSession.swift`, an actor, ADR 0005):

  | Concern | Behaviour |
  |---|---|
  | Storage | Installation ID and `device_session` (account, refresh token, pending refresh key) in the Keychain, `AfterFirstUnlockThisDeviceOnly`. The access token only in memory |
  | Reinstall | A `UserDefaults` marker; without it, Keychain leftovers are removed on first use |
  | Refresh | Single-flight. Sends an `Idempotency-Key` saved before sending and reused when retrying the same refresh. Drops credentials only on `refresh_token_invalid` or `refresh_reuse_detected` |
  | Authenticated calls | Refresh when there's no valid access token (60 s margin), and once more after `unauthenticated`, reusing the request's `Idempotency-Key`. A second `unauthenticated` means the session ended elsewhere: credentials cleared, `.signedOut` |
  | Settings (`AuthSession+Settings.swift`) | `list_account_sessions` follows `next_cursor` (100 per page, 10 pages at most). `delete_account` clears the credentials on `204` without calling sign-out: the server ended every session. `confirm_email_change` stores the account's new email |
  | Sign-in | `create_device_session` with the installation ID and `DeviceName.current()` (marketing name of the model, never "Apple device") |
  | Sign-out | `sign_out_device_session` with the refresh token, then credentials cleared, even offline. The installation ID stays |

- **UI** (`FeatureAccount`): one `AccountRoute` and `AccountModel` drive a `NavigationStack`, tinted `AwradColors.accent` so the back button and toolbar items are the app's green and stay readable in dark mode.
  - **Signed out:** sign in, then pushed steps for create account, verify email (resend with a 60 s cooldown, or `Retry-After`), forgot password and reset password. Verifying or resetting signs in with the password just typed.
  - **Signed in** (slice 2b): the overview shows the email, rows for Devices, Change password, Change email and Delete account, and sign out.
    - *Devices:* this device first and marked, then the others with their platform and relative last use; "Web browser" (or "Unknown device") when `name` is `null`. Each other one has Sign out, behind a confirmation; "Sign out of all other devices" too. This device signs out from the overview.
    - *Change password:* current and new password (length rule checked first). Back to the overview with a notice that other devices were signed out.
    - *Change email:* current password and new email (shape checked, and must differ), then the code sent to the new address with the resend cooldown, then the overview with the new email.
    - *Delete account:* says the account and its server data go now with no undo, and the data on this device stays; current password, then a destructive confirmation. Ends at sign in with a notice, email not prefilled.
  - **Session ended:** when any signed-in call returns `.signedOut` (revoked elsewhere, or a rejected refresh), the adapter has already cleared the credentials and the model shows sign in with "you've been signed out", the email prefilled. Local data is untouched.
  - **Local actions** (typing, navigation, asking to confirm) go through the synchronous `apply(_:)`; only server work runs in a task.
  - **Text:** numbers are format arguments, never digits inside a translation, so a screen uses the locale's digits throughout (counts, the countdown, `Date.RelativeFormatStyle` for last use). An email or device name never sits inside a sentence: it's its own `Text(verbatim:)` run (no Markdown, no link detection), wrapped in FSI…PDI (`Strings.isolated`), also where a device name fills a confirmation title.

  `AccountModel.Feedback` gives each handled error code its own localized text:

  | Code | Shown as |
  |---|---|
  | `validation_failed` | its field code: `email_invalid`, `email_unchanged`, `password_too_short`, `password_too_long`, `password_too_common`, `current_password_incorrect` |
  | `invalid_credentials`, `verification_code_invalid`, `reset_code_invalid`, `email_change_code_invalid`, `email_taken` | their own text |
  | `not_found` (revoking a device) | "already signed out", and it leaves the list |
  | `email_verification_required` | goes to the code screen, with a notice |
  | `rate_limited` | wait text, with `Retry-After` seconds when present |
  | `refresh_token_invalid`, `refresh_reuse_detected`, `unauthenticated` after a fresh token | signed out, with its message |
  | no response | can't reach Awrad |
  | anything else (`malformed_request`, `idempotency_key_reused`, `csrf_token_invalid`, unknown codes, `5xx`) | something went wrong |

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

- **Colours:** the 15 roles of [`contracts/design-tokens/v1/colors.json`](../contracts/design-tokens/v1/README.md), light and dark, following the system appearance.
  - **Generated:** `scripts/generate-colors.py` writes `AwradDesignSystem/Theme/AwradColors.swift` (one `AwradColors` property per role, `0xRRGGBBAA` so alpha is kept) and the app's `AccentColor` asset (the `accent` role, the window tint for system alerts). Never edit either; rerun the script. `scripts/validate` runs it with `--check` and fails on drift.
  - **Dynamic colours** (`AwradColors+Adaptive.swift`): the `UIColor`/`NSColor` provider is `@Sendable` and only picks between two colours made up front, because UIKit and SwiftUI resolve it off the main thread (a main-actor provider traps).
  - **Tests:** `AwradDesignSystemTests/AwradColorsTests` checks every role against the JSON in light and dark, and resolves the provider off the main thread.
  - **Use by role:** accent text, links, nav tint, cursors and icons on backgrounds are `accent` (`primary`'s `#23553C` is never text on dark); filled buttons `primary`/`onPrimary`; destructive `error`/`onError`; spinners `progress`.
- **No outlines** (the contract's rules for screens): shapes are filled, never stroked.
  - **Containers** (`AwradDesignSystem/Theme/AwradContainer.swift`): the `awradContainer` environment value says what a view sits on, `.background` by default. `awradCard()` fills a card with `surface` in the `card` shape and sets it to `.surface` for everything inside. `AwradContainer.controlFill` is the fill of a field, secondary button or unselected pill: `surface` on a background, `background` on a card.
  - **Text fields** use `awradField(isInError:)`: that fill, no border at rest or in focus (the `accent` cursor and the keyboard show focus), a placeholder in `onSurfaceVariant`, and an `error` border only while in error, always with the message. `AccountField` gets `isInError` from `Feedback.field`, the input an error is about (none for notices or wrong credentials).
  - **Rows in a card** (account overview, devices) are separated by spacing, never `Divider()`.
  - **The only lines allowed:** `outlineStrong` for a checkbox or radio box, `outline` for a progress track (neither exists yet), and the field error border. Text and link buttons stay unfilled.
- **Fonts:** the files of [`contracts/design-tokens/v1/fonts`](../contracts/design-tokens/v1/fonts/README.md), copied unchanged into `AwradDesignSystem/Resources/Fonts` and registered at launch with `AwradFonts.register()`.
  - **Interface text** is Google Sans Flex Rounded (`GoogleSansFlexRounded-Regular`/`-Medium`/`-SemiBold`/`-Bold`), the font of the frozen apps, always through a named `AwradTextStyle` (below). Each weight is its own file, never synthetic.
  - **Qur'anic and dhikr text** is Noto Naskh Arabic (`NotoNaskhArabic-…`), only through `AwradFonts.arabic`.
  - **Arabic and Malayalam interface text** uses the system font: Google Sans Flex has no glyphs for them, and Core Text falls back per glyph to the system cascade. Nothing names a font for those scripts.
  - **Checks:** `scripts/check-fonts.py` (in `scripts/validate`) fails when a bundled file is missing, extra, or differs from the contract's `SHA256SUMS`; to update, copy the contract files. `AwradDesignSystemTests/AwradFontsTests` checks that every file registers and resolves by its PostScript name, and that ar and ml text falls back to neither bundled family.
- **Shapes, spacing, type and motion:** `shape.json`, `spacing.json`, `typography.json` and `motion.json` of [`contracts/design-tokens/v1`](../contracts/design-tokens/v1/README.md). Screens use these by name, never a number.
  - **Generated:** `scripts/generate-design-tokens.py` writes four files in `AwradDesignSystem/Theme`. Never edit them; rerun the script. `scripts/validate` runs it with `--check` and fails on drift; an unknown key in a named motion fails the generator, so a new token can't be dropped silently. Scale keys with a leading digit move it to the end (`2xl` is `xl2`).

    | File | API |
    |---|---|
    | `AwradRadius.swift` | `AwradRadius` scale (`xs`…`xl3`) and roles (`card`, `tile`, `button`, `field`, `chip`, `roundButton`, `navBar`, `navPill`, `sheet`, `dialog`, `screenDepth`) as `AwradCorner` (`.radius(_)` or `.full`) |
    | `AwradSpacing.swift` | `AwradSpacing` scale (`none`…`xl5`) and roles (`pageMargin`, `sectionGap`, `cardPadding`, `rowGap`, `inlineGap`); `AwradSize` (`touchTarget`, `listRow`, `icon`, `iconSmall`, `ringSmall`, `ringStroke`) |
    | `AwradTextStyle.swift` | `AwradTextStyle.title` … `.counter`: size, line height, weight's face, Dynamic Type style, tabular digits |
    | `AwradMotion.swift` | `AwradMotion.Easing` (`AwradCurve`), `.Duration` (seconds), `.Spring` (`AwradSpring`, converted: response = 2π/√stiffness, dampingFraction = dampingRatio), the named motions iOS uses (`TabSwitch`, `NavPill`, `Press`, `CountTap`, `CountComplete`, `RingFill`, `Sheet`, `Expand`, `ListAppear`, `ContentSwap`; nested values flattened, `enter.scaleFrom` is `enterScaleFrom`), `ReducedMotion`; `AwradHaptic` (`tick`, `threshold`, `success`) with its `SensoryFeedback` |
  - **Shapes** (`AwradShapes.swift`): every corner is continuous. `AwradCorner.shape` is an `AwradShape`, a `RoundedRectangle(cornerRadius:style: .continuous)` or continuous capsule that insets concentrically (for `strokeBorder`). Cards `awradCard()` (`card`), buttons and fields `button`/`field`, sheets `awradSheet()` (`presentationCornerRadius` of `sheet`).
  - **Type** (`AwradText.swift`, `AwradTypography.swift`): `awradTextStyle(_:)` sets `AwradFonts.font(_:)` (`.custom(_:size:relativeTo:)` with the style's `iosTextStyle`, `.monospacedDigit()` for `counter`) and the line height as `lineSpacing` (line height minus the face's ascent + descent + leading, scaled with Dynamic Type). `AwradFonts.font(_:)` alone is for symbols and single-line text.
  - **Motion** (`AwradMotionPolicy.swift`, `AwradMotion+Helpers.swift`): screens read `@Environment(\.awradMotion)`, an `AwradMotionPolicy` from the system's Reduce Motion. Its `animation(_:)`, `scale(_:)`, `offset(_:)`, `transition(_:)` and `animate(_:_:)` pass motion through or, when reduced, give the 150 ms cross-fade (no scale, no offset, a fade); haptics stay. Every helper below uses it, so no screen branches on reduced motion.

    | Motion | Helper | Used |
    |---|---|---|
    | page push | the native `NavigationStack` push (decided) | yes |
    | `press` | `.buttonStyle(.awradPress(.card / .button))`, `awradPressed(_:kind:)`: scale 0.985 / 0.98 over `fade`, release `spatialFast` | settings rows, `AwradPrimaryButton` |
    | `contentSwap` | `awradContentSwap(value:)` on a `switch`: out over `fade` (accelerate), in over `color` (decelerate) | root onboarding/home, account loading/sign-in/overview, devices loading/unavailable/list |
    | `expand` | `awradExpand(value:)` on the container (`spatial`), `awradExpandingContent()` on what appears (fade, `effects`), `awradChevron(isExpanded:)` | account feedback line, a signed-out device leaving |
    | `sheet` | `awradSheet()`: the `sheet` radius; the native sheet follows the finger | account sheet |
    | haptics | `awradHaptic(_:trigger:)` (`tick` `.selection`, `threshold` medium impact, `success` `.success`) | ready |
    | `countTap` | `awradCountTap(value:)`: `.numericText` roll, 1.04 `bouncy` pop, `tick`. Change the value inside `motion.animate(AwradMotion.CountTap.spring.animation) { … }` | ready |
    | `ringFill` | `awradRingFill(value:)`: `spatial` | ready |
    | `navPill` | `awradNavPill(isSelected:)` (pill from 0.7, `bouncySoft`), `awradNavIcon(isSelected:)` (1.1 `bouncy` pop) | ready |
    | `listAppear` | `awradListAppear(index:)`: 8 pt rise and fade over `short`, `decelerate`, 40 ms stagger for the first 6 | ready |

    `AwradMotionPreviews.swift` previews the ready ones.
  - **Not expressed by the tokens** (raw values stay inside `AwradDesignSystem`, commented): field and main-button height (`listRow`), the field error border width (1.5), the disabled main button (`outline` fill, `onSurfaceVariant` text), the Qur'anic text size (`AwradFonts.arabic`), the pop's rise time (`press.pressDuration`). `counter`'s 64 pt line height is tighter than the face's own (70 pt), so it keeps the face's. `sheet`'s settle spring, overshoot, release velocity and corners-to-0 at full height belong to the native sheet, which SwiftUI doesn't expose; `tabSwitch` and `countComplete` are generated but have no helper until tabs and counting exist.
  - **Check:** `scripts/check-raw-design-values.py` (in `scripts/validate`, after its `--self-test`) rejects, outside `AwradDesignSystem`, a number in `.padding`, `spacing:`, `minLength:`, `cornerRadius:`, `.frame`, `lineWidth:`, `lineSpacing`, `.offset`, `.scaleEffect`, `.presentationCornerRadius` or `duration:`; a system or sized font (`.font(.…)`, `Font.custom`, `.fontWeight`); a raw animation (`.animation(.…)`, `withAnimation(.…)`, `.spring(…)`, `.timingCurve(…)`); and a raw `.sensoryFeedback(.…)`. **Allowlist:** a structural value that isn't a design decision ends its line with `// design-token-exempt: <reason>` (today: the 520 pt readable width of account forms, the 148 pt onboarding logo).
  - **Tests:** `AwradLayoutTokensTests` and `AwradMotionTests` check every generated value against the JSON at run time (springs through the conversion, motion references resolved), continuous shapes, line spacing, and the reduced-motion policy.
- **Logo:** plain PNGs in the package bundle.
- **Strings:** String Catalogs per module (`Bundle.module`) plus the app's own. Xcode compiles them into `en`/`ar`/`ml` resources.

Command-line `swift build` copies catalogs uncompiled, so runtime localization is only exercised in Xcode builds.

## App identity

Bundle ID `app.awrad.awrad.next` and display name "Awrad Next", so it installs next to the frozen app. iPhone and iPad. The final identity is fixed before the first release.

## Decisions

See [`docs/adr/`](docs/adr/README.md). Cross-project decisions are in the root [`DECISIONS.md`](../DECISIONS.md).
