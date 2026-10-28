# awrad-ios-next — architecture

The Awrad iOS app, rebuilt to replace `awrad-ios/` (root ADR-2026-10-14).
- **Stack:** SwiftUI, SwiftData and Observation on iOS 18, built with Xcode 26.2 / Swift 6.2.
- **Status:** scaffold plus the slice 1 goal rules, the slice 1b Hijri calendar, the slice 2a and 2b accounts and the slice 3a dhikr catalog and Library. A placeholder onboarding screen and home screen prove the wiring; features arrive in slices (`../docs/rebuild-plan.md`).

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

## IDs

Every ID is an `AwradID`, and every ID the app generates is a UUIDv7 ([`contracts/identity/v1`](../contracts/identity/v1/README.md), root ADR-2026-10-28): entity IDs, the installation ID and `Idempotency-Key`s.

- **Generator** (`AwradDomain/UUIDv7.swift`): `UUIDv7.uuid(unixMilliseconds:random:)` is the pure layout from a time and 10 random bytes, run against `uuid_v7_layout.json`. `UUIDv7.generate(now:using:)` takes the clock and a `RandomNumberGenerator`; production (`AwradID.random()`) uses `Date.init` and `SystemRandomNumberGenerator`, which is cryptographically secure on Apple platforms. A clock before 1970 gives time zero.
- **Validation:** `AwradID.init?(_:)` accepts only the wire form (`uuid_format.json`): lowercase, hyphenated, any version (built-in dhikrs keep their fixed UUIDv4s), never the nil or max UUID, nothing trimmed or case-folded.
- **Never by timestamp:** nothing orders, expires or authorizes by an ID's time; the device clock can be wrong.
- **Check:** `scripts/check-uuid-generation.py` (in `scripts/validate`, after its `--self-test`) rejects `UUID()`, `UUID.init()` and `NSUUID()` in `AwradKit/Sources` and `AwradNext`, since Foundation only makes v4. Tests may use them for throwaway names.
- **Runner:** `IdentityFixtures` runs `identity/v1/fixtures/`; `UUIDv7GeneratorTests` checks that consecutive IDs are valid v7 that sort by time.

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
  - `APIClient` attaches a bearer token only to operations that take one, an `Idempotency-Key` (lowercase UUIDv7) to every `POST`, and `Accept-Language` (the app language) where the spec declares it. An operation's `path` is the spec's template; `pathParameters` fill its `{name}`s, and `queryParameters` lists the query names it may send.
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

- **Entry point:** the home screen's Account button opens `AccountRoute` in a sheet (`RootView`).
- **Base URL** (`AppComposition`'s `APIEnvironment`): Debug uses `http://localhost:4000`. `Config/Debug-Info.plist` (Debug only) allows plain HTTP to `localhost`. Release has no server yet, so it points at a `.invalid` host.

## Dhikr catalog and Library (slice 3a)

The built-in dhikrs and collections of [`contracts/dhikr-catalog/v1`](../contracts/dhikr-catalog/v1/README.md), read-only and in memory (no SwiftData; custom dhikrs come in 3b).

- **Bundling:** `AwradDomain/Resources/dhikr-catalog.json` is a byte-identical copy of `catalog.json`. `scripts/check-dhikr-catalog.py` (in `scripts/validate`) fails on drift; `--fix` copies the contract's file. `DhikrCatalogTests` also compares the two. Nothing reads `contracts/` at run time.
- **Types** (`AwradDomain/Dhikr.swift`, `DhikrCatalog.swift`): `Dhikr` (`AwradID` id, key, `DhikrKind`, Arabic, `LocalizedText` title, transliteration and translation, aliases by `CatalogLanguage`, tag keys, `DhikrAudio?`, `[Reference]`, `[Virtue]`), `Reference` (an enum: `quran(id:surah:ayahs:)`, `hadith`, `book`, `shaykh`, `other`), `Virtue`, `DhikrCollection`, `CatalogTag`, `DhikrAudio`. `DhikrCatalog.bundled()` decodes the copy; the app decodes it once in `AppComposition`.
- **Decoding** (`DhikrCatalog+Decoding.swift`): every object rejects keys the schema doesn't list, and only a consistent catalog exists: `DhikrCatalog`'s initializer `throws(DhikrCatalogError)` on another `version`, a repeated key, or a collection, tag or virtue reference that resolves to nothing.
- **Display** (`Dhikr+Display.swift`): `dhikr.display(in:)` gives the title, transliteration and translation in the app language (`CatalogLanguage(languageCode:)` from `Bundle.main.preferredLocalizations`), each falling back to English; Arabic has no transliteration.
- **Search** (`DhikrSearch.swift`): `DhikrSearchNormalization.normalize` is the fixture's nine steps, on Unicode scalars (combining marks by `generalCategory`, Malayalam signs kept). `DhikrSearchIndex(dhikrs:language:)` precomputes each dhikr's compact names and fields as UTF-8 and matches bytes, so a query can end inside a Malayalam grapheme. `DhikrCatalogFixtures` runs both fixture files (`dhikr_search` over the bundled catalog); `FixtureRunnerTests` covers the directory.
- **Audio:** the `DhikrAudioPlayer` port (`@MainActor`; `play(url)`, `pause()`, `stop()`, and `onStatusChange` with `AudioPlaybackStatus`, whose `PlaybackPosition` carries the elapsed time and, once the stream knows it, the length). `AVDhikrAudioPlayer` (`AwradData/Audio`) streams `audio.url` with `AVPlayer`, sets the session to `.playback` (`.spokenAudio`) when playing and releases it on `stop()`, and reports the time every 0.25 s. `AppComposition.makeAudioPlayer` makes one per dhikr screen; the fake is `FakeDhikrAudioPlayer`. No download or cache yet.
- **UI** (`FeatureLibrary`):
  - **Shell** (`AwradNext/AppShell.swift`): Home and Library under `awradBottomBar`, switching with `awradTabSwitch`. The bar shows only on the two roots: a pushed collection or dhikr hides it (`isPresented:`). The shell owns `LibraryModel`, so Home's tiles open a collection in the Library tab and "View all" opens the Library's first screen.
  - **Home** keeps the placeholder content and adds `FeaturedCollections`: the `sectionTitle` heading with a "View all" text button, then a horizontal row of `AwradCollectionTile`s ("100 dhikrs" from the catalog's plural variants).
  - **Library** (`LibraryRoute` over `LibraryModel`): the native large title, a search field (the `search` icon in an `awradField`, a clear button), then Collections (tiles) and All dhikrs (rows). While the query isn't blank, only the results show, or the empty state. Typing goes through the synchronous `apply(_:)`.
  - **Dhikr row:** a `tile` card button with the title in `rowTitle`, one right-to-left line of the Arabic in `quranLine` (truncated, on the right in every language, exactly the style's line height so the row hugs it), and a `chevron`.
  - **Collection:** a native push with the collection's title, then its rows in order.
  - **Dhikr detail** (`DhikrDetailRoute` over `DhikrDetailModel`): a card with the Arabic, centred and right to left (`quran`: one ayah per line in `quran` and the reference label, "Qur'an 112:1–4", in `caption`; `name_of_allah`: the name in `nameOfAllah` over its meaning in `title`; other kinds: the whole text in `quran`), and at its bottom the audio player bar when there's audio (`DhikrAudioBar`: the play/pause `AwradRoundButton`, a progress indicator while loading, a `ringStroke` progress line, and "0:14 / 0:26" in `caption`, or the elapsed time alone until the length is known). Then the transliteration and translation (every kind but `name_of_allah`), the tags as chips, and the virtues in `tile` cards with their reference labels (`ReferenceLabel`: hadith collection, number and grade; book title, author, volume:page; shaykh name; other text and link). Leaving the screen stops the audio, and the app going to the background (`scenePhase`) pauses it. The player is made on the first play.
  - **Screenshots** (debug builds): `-AwradTab library`, `-AwradLibrarySearch <query>`, `-AwradLibraryCollection <key>` and `-AwradLibraryDhikr <key>` open the Library in that state; `-awrad.onboarded YES` skips onboarding.

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

- **Colours:** the 20 roles of [`contracts/design-tokens/v1/colors.json`](../contracts/design-tokens/v1/README.md), light and dark, following the system appearance, and its `states`.
  - **Generated:** `scripts/generate-colors.py` writes `AwradDesignSystem/Theme/AwradColors.swift` (one `AwradColors` property per role, `0xRRGGBBAA` so alpha is kept, and `AwradState.disabledOpacity`, 0.38) and the app's `AccentColor` asset (the `accent` role, the window tint for system alerts). Never edit either; rerun the script. `scripts/validate` runs it with `--check` and fails on drift; an unknown top-level group, a role key other than `use`/`light`/`dark`, or a state key other than `opacity` fails the generator.
  - **Disabled controls** keep their colours and are drawn at `AwradState.disabledOpacity` through `awradDisabledAppearance()`, which reads the environment's `isEnabled` (every component below). There are no disabled colours.
  - **Dynamic colours** (`AwradColors+Adaptive.swift`): the `UIColor`/`NSColor` provider is `@Sendable` and only picks between two colours made up front, because UIKit and SwiftUI resolve it off the main thread (a main-actor provider traps).
  - **Tests:** `AwradDesignSystemTests/AwradColorsTests` checks every role against the JSON in light and dark and every state's opacity, and resolves the provider off the main thread.
  - **Use by role:** accent text, links, nav tint, cursors and icons on backgrounds are `accent` (`primary`'s `#23553C` is never text on dark); filled buttons `primary`/`onPrimary`; destructive `error`/`onError`; spinners `progress`.
- **No outlines** (the contract's rules for screens): shapes are filled, never stroked.
  - **Containers** (`AwradDesignSystem/Theme/AwradContainer.swift`): the `awradContainer` environment value says what a view sits on, `.background` by default. `awradCard()` fills a card with `controlFill` (`surface` on the page, `background` on a surface such as the content sheet) and tells everything inside it sits on the other one (`inverted`). `AwradContainer.controlFill` is also a field's fill. `secondaryFill`/`onSecondaryFill` fill a secondary button, an unselected option row or segmented pill: `secondaryContainer`/`onSecondaryContainer` on the page, `background`/`onSurface` on a surface, because `secondaryContainer` is `surface` in light (orchestrator rule, 2026-10-27). Dialogs and bottom sheets count as the page.
  - **Text fields** (`AwradTextField`) use `awradField(isInError:)`: that fill, `control` height, typed text in the `input` style, no border at rest or in focus (the `accent` cursor and the keyboard show focus), a placeholder in `onSurfaceVariant`, and an `error` border (`AwradStroke.fieldError`) only while there's an error message, shown under the field. `AccountField` gets its message from `State.fieldError(_:)`, the feedback whose `Feedback.field` is that input; feedback about no single input (notices, wrong credentials) stays in the form's feedback line.
  - **Rows in a card** (account overview, devices) are separated by spacing, never `Divider()`.
  - **The only lines allowed** are shape.json's `strokes` (`AwradStroke`): `fieldError` 1.5, `checkbox` 2 in `outlineStrong` for an unticked checkbox's box, and `focusRing` (web only, generated but unused). The tick is the `check` icon, not a line. A progress track is an `outline` fill. Text buttons stay unfilled.
- **Elevation:** shape.json `elevation` becomes `AwradElevation` (`AwradShadow`: `color`, `radius` = blur / 2, `x`, `y`), applied with `awradElevation(_:)`. The colour is the `shadow` role, clear in dark, so dark mode has no shadow. Only the bottom bar uses it.
- **Fonts:** the files of [`contracts/design-tokens/v1/fonts`](../contracts/design-tokens/v1/fonts/README.md), copied unchanged into `AwradDesignSystem/Resources/Fonts` and registered at launch with `AwradFonts.register()`.
  - **Interface text** is Google Sans Flex Rounded (`GoogleSansFlexRounded-Regular`/`-Medium`/`-SemiBold`/`-Bold`), the font of the frozen apps, always through a named `AwradTextStyle` (below). Each weight is its own file, never synthetic.
  - **Qur'anic and dhikr text** is Noto Naskh Arabic (`NotoNaskhArabic-…`), only through the `quran` text style (24/44, relative to `.title2`; the dhikr detail) and `quranLine` (18/32, relative to `.body`; one line in a dhikr row), the styles with their own `fontFamily`.
  - **Arabic and Malayalam interface text** uses the system font: Google Sans Flex has no glyphs for them, and Core Text falls back per glyph to the system cascade. Nothing names a font for those scripts.
  - **Navigation bar titles:** SwiftUI's `navigationTitle` takes no font, so `AwradNavigationBarAppearance.apply()` (called once in `AwradNextApp.init`, after `AwradFonts.register()`) sets them through `UINavigationBar.appearance()`: the large title in `largeTitle`, the inline title in `rowTitle` (16 pt semibold; `title`'s 22 pt is too big for the compact bar), each scaled with `UIFontMetrics` relative to its text style. The appearance proxy is read when a bar is made, so the Dynamic Type size is the one at launch. Colours stay the system's.
  - **Checks:** `scripts/check-fonts.py` (in `scripts/validate`) fails when a bundled file is missing, extra, or differs from the contract's `SHA256SUMS`; to update, copy the contract files. `AwradDesignSystemTests/AwradFontsTests` checks that every file registers and resolves by its PostScript name, and that ar and ml text falls back to neither bundled family.
- **Icons:** the Material Symbols Rounded set of [`contracts/design-tokens/v1/icons.json`](../contracts/design-tokens/v1/README.md) (`home`, `goals`, `library`, `community`, `add`, `forward`, `back`, `more`, `check`, `notifications`, `show`, `hide`, `close`, `expand`, `streak`, `devices`, `phone`, `language`, `email`, `password`, `delete`, `chevron`, `error`, `play`, `pause`, `search`). There are no SF Symbols anywhere, the design system included.
  - **Generated:** `scripts/generate-icons.py` writes `AwradDesignSystem/Resources/Icons.xcassets` (one imageset per icon, named by its key: the SVG with Preserve Vector Data, rendered as a template so it takes the foreground style; `mirrorInRtl` icons, `back`, `forward` and `chevron`, are "Left to Right, Mirrors" and flip in right-to-left layouts, SwiftUI's `layoutDirection` included) and `Theme/AwradIcon.swift` (`AwradIcon`, a `CaseIterable` enum with `image` and `mirrorsInRightToLeft`). Never edit either; rerun the script. `scripts/validate` runs it with `--check`, which fails on a stale or extra file in the catalog; an unknown key in icons.json, a missing file or an SVG no icon names fails the generator.
  - **viewBox:** the contract's SVGs use Material's `0 -960 960 960`. The generator translates each path by the origin and writes `0 0 960 960`, so asset compilation never sees a negative origin; the drawing is unchanged (checked in the gallery's icon grid).
  - **Drawing:** `AwradIconImage(_:size:)` draws an icon resizable in a square of `AwradSize.icon` (24) or `iconSmall` (20), hidden from VoiceOver (the control carries the label). Command-line `swift build` copies the catalog uncompiled, so icons only render in Xcode builds.
  - **Tests:** `AwradIconTests` checks the enum against icons.json (every key, in order, with its file), the mirrored set, and each imageset's template, vector, direction and normalised viewBox.
- **Shapes, strokes, spacing, type and motion:** `shape.json`, `spacing.json`, `typography.json` and `motion.json` of [`contracts/design-tokens/v1`](../contracts/design-tokens/v1/README.md). Screens use these by name, never a number.
  - **Generated:** `scripts/generate-design-tokens.py` writes six files in `AwradDesignSystem/Theme`. Never edit them; rerun the script. `scripts/validate` runs it with `--check` and fails on drift; an unknown key anywhere (a file's top-level group, a role, size, style, spring, haptic, stroke, elevation, named motion or `reducedMotion`), an elevation colour that isn't a colour role, or a font family without bundled faces, fails the generator, so a new token can't be dropped silently. Scale keys with a leading digit move it to the end (`2xl` is `xl2`).

    | File | API |
    |---|---|
    | `AwradRadius.swift` | `AwradRadius` scale (`xxxs`…`xl3`) and roles (`card`, `tile`, `button`, `field`, `chip`, `roundButton`, `navBar`, `navPill`, `sheet`, `dialog`, `screenDepth`, `checkbox`, `stepDot`, `tabIndicator`, `contentSheet`) as `AwradCorner` (`.radius(_)` or `.full`) |
    | `AwradStroke.swift` | `AwradStroke` line widths (`fieldError`, `checkbox`, `focusRing`); an `offset` becomes `<name>Offset` (`focusRingOffset`) |
    | `AwradElevation.swift` | `AwradElevation.floating`, an `AwradShadow` (radius = blur / 2, colour role `shadow`) |
    | `AwradSpacing.swift` | `AwradSpacing` scale (`none`…`xl5`) and roles (`pageMargin`, `sectionGap`, `cardPadding`, `rowGap`, `inlineGap`); `AwradSize` (`touchTarget`, `listRow`, `icon`, `iconSmall`, `ringSmall`, `ringStroke`, `control`, `logo`, `contentMaxWidth`, `dialogMaxWidth`, and the component sizes `topBar`, `navBar`, `navPillWidth`/`Height`, `roundButton`, `roundButtonSmall`, `avatar`, `checkbox`, `switchWidth`/`Height`/`Thumb`, `stepDot`, `tabIndicatorWidth`/`Height`) |
    | `AwradTextStyle.swift` | `AwradTextStyle.largeTitle` … `.quran` (with `input` for typed text): size, line height, the face of its family (the interface family, or the style's own `fontFamily`) for its weight, Dynamic Type style, tabular digits |
    | `AwradMotion.swift` | `AwradMotion.Easing` (`AwradCurve`, including `linear`), `.Duration` (seconds), `.Spring` (`AwradSpring`, converted: response = 2π/√stiffness, dampingFraction = dampingRatio), the named motions with `ios` in `platforms` (`TabSwitch`, `NavPill`, `Press`, `CountTap`, `CountComplete`, `RingFill`, `Expand`, `ListAppear`, `ContentSwap`, `SegmentIndicator`, `Select`; nested values flattened, `enter.scaleFrom` is `enterScaleFrom`), `ReducedMotion` (duration and easing); `AwradHaptic` (`tick`, `threshold`, `success`) with its `SensoryFeedback`. The Android-only `sheet` motion isn't generated |
  - **Shapes** (`AwradShapes.swift`): every corner is continuous. `AwradCorner.shape` is an `AwradShape`, a `RoundedRectangle(cornerRadius:style: .continuous)` or continuous capsule that insets concentrically (for `strokeBorder`). Cards `awradCard()` (`card`), buttons and fields `button`/`field`, both `AwradSize.control` tall, sheets `awradSheet()` (`presentationCornerRadius` of the `sheet` role on the native sheet).
  - **Type** (`AwradText.swift`, `AwradTypography.swift`): `awradTextStyle(_:)` sets `AwradFonts.font(_:)` (`.custom(_:size:relativeTo:)` with the style's `iosTextStyle`, `.monospacedDigit()` for `counter`) and the line height as `lineSpacing` (line height minus the face's ascent + descent + leading, scaled with Dynamic Type). `AwradFonts.font(_:)` alone is for symbols and single-line text.
  - **Motion** (`AwradMotionPolicy.swift`, `AwradMotion+Helpers.swift`): screens read `@Environment(\.awradMotion)`, an `AwradMotionPolicy` from the system's Reduce Motion. Its `animation(_:)`, `scale(_:)`, `offset(_:)`, `transition(_:)` and `animate(_:_:)` pass motion through or, when reduced, give the 150 ms linear cross-fade (`reducedMotion`; no scale, no offset, a fade); haptics stay. Every helper below uses it, so no screen branches on reduced motion.

    | Motion | Helper | Used |
    |---|---|---|
    | page push | the native `NavigationStack` push (decided) | yes |
    | `press` | `.buttonStyle(.awradPress(.card / .button))`, `awradPressed(_:kind:)`: scale 0.985 / 0.98 over `fade` on `pressEasing` (`emphasized`), release `spatialFast` | settings rows, every tappable component |
    | `contentSwap` | `awradContentSwap(value:)` on a `switch`: out over `fade`, in over `color`, both `linear` | root onboarding/home, account loading/sign-in/overview, devices loading/unavailable/list |
    | `expand` | `awradExpand(value:)` on the container (`spatial`), `awradExpandingContent()` on what appears (fade, `effects`), `awradChevron(isExpanded:)` | account feedback line, a signed-out device leaving |
    | sheets | the native sheet (the contract's `sheet` motion is Android's); `awradSheet()` sets the `sheet` radius | account sheet |
    | haptics | `awradHaptic(_:trigger:)` (`tick` `.selection`, `threshold` medium impact, `success` `.success`) | ready |
    | `countTap` | `awradCountTap(value:)`: `.numericText` roll, 1.04 `bouncy` pop, `tick`. Change the value inside `motion.animate(AwradMotion.CountTap.spring.animation) { … }` | ready |
    | `ringFill` | `awradRingFill(value:)`: `spatial` | ready |
    | `navPill` | `awradNavPill(isSelected:)` (pill from 0.7, `bouncySoft`), `awradNavIcon(isSelected:)` (1.1 `bouncy` pop) | `AwradBottomBar` |
    | `tabSwitch` | `awradTabSwitch(value:)` on a tab's content: in from 0.985 and 0.4 opacity, out to 1.01, over `medium` on `emphasized` | gallery |
    | `segmentIndicator` | the selected pill's fill and bar move (`matchedGeometryEffect`) with `spatial` | `AwradSegmentedPills` |
    | `select` | `awradSelectColors(value:)`: colours cross-fade over `color`, `linear`; the checkbox tick draws in with `spatial` | option rows, checkbox, step indicator |
    | `listAppear` | `awradListAppear(index:)`: 8 pt rise and fade over `short`, `decelerate`, 40 ms stagger for the first 6 | ready |

    `AwradMotionPreviews.swift` previews the ready ones.
  - **Not expressed by the tokens** (raw values stay inside `AwradDesignSystem`, commented): the pop's rise time (`press.pressDuration`). `counter`'s 64 pt line height is tighter than the face's own (70 pt, on purpose in the contract), but `lineSpacing` can't be negative, so it keeps the face's. `countComplete` is generated but has no helper until counting exists; `focusRing` and the switch sizes (the native `Toggle` draws itself) are generated but unused.
  - **Check:** `scripts/check-raw-design-values.py` (in `scripts/validate`, after its `--self-test`) rejects an SF Symbol (`systemName:`, `systemImage:`, `systemSymbolName:`) in every file, `AwradDesignSystem` included, with no exemption; and, outside `AwradDesignSystem`, a number in `.padding`, `spacing:`, `minLength:`, `cornerRadius:`, `.frame`, `lineWidth:`, `lineSpacing`, `.offset`, `.scaleEffect`, `.presentationCornerRadius` or `duration:`; an `.opacity` other than 0 or 1; a system or sized font (`.font(.…)`, `Font.custom`, `.fontWeight`); a raw animation (`.animation(.…)`, `withAnimation(.…)`, `.spring(…)`, `.timingCurve(…)`); and a raw `.sensoryFeedback(.…)`. **Allowlist:** a structural value that isn't a design decision ends its line with `// design-token-exempt: <reason>` (none today: the account forms' width is `contentMaxWidth`, the onboarding logo `logo`). An exemption never covers a number that is a size token (spacing.json `sizes`).
  - **Tests:** `AwradLayoutTokensTests` and `AwradMotionTests` check every generated value against the JSON at run time (strokes, each style's family face, springs through the conversion, motion references resolved), continuous shapes, line spacing, and the reduced-motion policy.
- **Logo:** plain PNGs in the package bundle.
- **Strings:** String Catalogs per module (`Bundle.module`) plus the app's own. Xcode compiles them into `en`/`ar`/`ml` resources. `AwradDesignSystem` has its own catalog for component accessibility text (`AwradStrings`: back, more options, close, show and hide password, loading, "Step 2 of 7") and the gallery's sample text; each `LocalizedStringResource` there carries its English default value, so `swift test` reads the English.

Command-line `swift build` copies catalogs uncompiled, so runtime localization is only exercised in Xcode builds.

## Components

`AwradDesignSystem/Components` implements [`contracts/design-system/v1/components.md`](../contracts/design-system/v1/components.md) with tokens only. Every component draws disabled at `AwradState.disabledOpacity` (`.disabled(_:)`), presses with `press`, mirrors in right-to-left, scales its text with Dynamic Type (heights are minimums), and turns movement into the cross-fade with Reduce Motion.

| Component | API |
|---|---|
| Card | `AwradCard(_ corner = AwradRadius.card) { … }` (`tile` for list items), `AwradCardButton(_ corner, action:) { … }`; `cardPadding` inside, rows `rowGap` apart, fill by container |
| Content sheet | `AwradContentSheet { … }` (`surface`, `contentSheet` top corners, scrolls) with `AwradSectionTitle(_:)` |
| Bottom sheet | `.awradBottomSheet(isPresented:detents:content:)`: the native sheet, `surfaceBar`, `sheet` corners, an `outline` handle |
| Dialog | `.awradDialog(isPresented:title:message:actions:)` over a `scrim` in a transparent full-screen cover (so it dims bars too), fading in and out; `AwradDialog` is the card. Pass `layout: .row` buttons; destructive confirmations use `.error` |
| Option row | `AwradOptionRow(_:avatar:isSelected:selection: .single/.multiple, action:)`, the `check` icon (`iconSmall`) in an `onPrimary` circle when selected; read as selected, and as a toggle for `.multiple` |
| Buttons | `AwradButton(_:variant: .main/.secondary/.error/.text, layout: .fill/.row, icon:isLoading:role:action:)`: `icon` an `AwradIcon` at `iconSmall`; loading shows the platform's own `ProgressView`; the destructive role makes a text button `error` |
| Round / icon buttons | `AwradRoundButton(icon:label:size: .regular/.small, isLoading:action:)`, `AwradIconButton(icon:label:action:)`, `AwradIconButton.back`/`.more`/`.close` |
| Text field | `AwradTextField(_ label:text:prompt:isSecure:error:supportingText:)`: the label above, 56 tall, the error message (and border) or supporting text below, no icon. A secure field has a show/hide button at its end (`show`/`hide` icons, a 48 touch area inside the field), which keeps focus while it swaps the field |
| Checkbox / switch | `AwradCheckbox(_:isOn:)` (`AwradCheckboxStyle`, read as the native toggle), `AwradSwitch(_:isOn:)` (the native `Toggle` tinted `primary`) |
| Segmented pills | `AwradSegmentedPills(selection:options: [.init(value, title:)])`, read as a tab bar |
| Top bar | `AwradTopBar(_ title, onBack:) { trailing }` or `AwradTopBar(onBack:middle:trailing:)` |
| Step indicator | `AwradStepIndicator(current:total:)`: `stepDot` squares (radius `xxxs`, 2), one element read "Step 2 of 7" |
| Large title | `.awradLargeTitle(_:)` (the native large title in a `NavigationStack`), `AwradLargeTitleHeader(_:) { AwradRoundButton(…) }` outside one |
| Bottom bar | `.awradBottomBar(selection:items: [AwradBottomBarItem(tab, title:icon:)], isPresented:)` floats it in a bottom safe-area inset (none while `isPresented` is false, on pushed pages); the same outline icon selected or not (the pill shows the selection); `AwradBottomBar` is the bar; `awradTabSwitch(value:)` for the content |
| Collection tile (slice 3a) | `AwradCollectionTile(_ title:detail:action:)` (title a `String` from content or a `LocalizedStringResource`): `collectionTile` (128) wide and at least as tall, `surface` in the `tile` shape, `md` padding; the title in `rowTitle` (two lines at most, breaking only between words and ending in an ellipsis) and the count in `caption` at the top, the small round `forward` arrow (`AwradRoundIcon`, the round button's face, not a second button) at the bottom end; one button for VoiceOver, `press.cardScale`. components.md "Library components (slice 3a)" (which says `cardPadding`; iOS, Android and the web use `md`) |

- **Gallery** (`AwradDesignSystem/Gallery`, `#if DEBUG` only): `AwradComponentGallery` shows every component in every state, and every icon, with Dark and Arabic right-to-left switches on the gallery itself. Debug builds open it from the home screen's "Component gallery" button, or at launch with `-AwradGallery YES`; `-AwradGalleryDark YES`, `-AwradGalleryRTL YES`, `-AwradGallerySection <containers|buttons|inputs|navigation>`, `-AwradGalleryTab <tab>` and `-AwradGallerySheet YES` set its starting state for screenshots. The RTL switch flips SwiftUI's layout and locale; UIKit text fields only right-align their placeholder when the app language is Arabic too (`-AppleLanguages "(ar)"`).
- **Account screens** use `AwradButton` (main, error, text, row), `AwradTextField` (through `AccountField`) and `AwradCard`; the account stack keeps the native navigation bar (its back swipe and push), not `AwradTopBar`. Icons come from `AwradIcon` at `iconSmall`: settings rows lead with `devices`, `password`, `email` or `delete` (accent, or error when destructive) and end with `chevron` (flips in RTL); device rows show `phone` for an iOS or Android app and `devices` otherwise; the delete note shows `phone`; the feedback line shows `email` for a notice and `error` otherwise. Debug builds launched with `-AwradAccountScreenshot settings` or `devices` show that signed-in screen with sample state and no server (`AccountScreenshot`), for simulator screenshots.
- **Tests:** `AwradComponentsTests` (step label, steps reached, pill selection and traits, option-row traits, button heights and roles, secondary fills on a surface, the component strings in the catalog) and `AwradElevationTests`.

## App identity

Bundle ID `app.awrad.awrad.next` and display name "Awrad Next", so it installs next to the frozen app. iPhone and iPad. The final identity is fixed before the first release.

## Decisions

See [`docs/adr/`](docs/adr/README.md). Cross-project decisions are in the root [`DECISIONS.md`](../DECISIONS.md).
