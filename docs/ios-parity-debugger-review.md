# iOS parity debugger review

Runtime and automated evidence for the iOS parity implementation against Android baseline `2f56aa4`. This complements [`ios-android-parity-ledger.md`](ios-android-parity-ledger.md). Simulator evidence does not close physical-device integration work.

## Review identity

| Field | Value |
|---|---|
| Reviewer | Codex, using the `ios-debugger-agent` CLI fallback because XcodeBuildMCP was unavailable |
| Review date/time zone | 2026-07-15, Asia/Kolkata |
| Android baseline | `2f56aa4` |
| iOS revision | Parity working tree based on `2f56aa4` |
| Toolchain | Xcode 26.2 (17C52), Swift 6.2.3 |
| iOS 26 simulator | iPhone 17 Pro Max, iOS 26.2, `0AC09F65-32DF-49AC-B8E8-52740ADA65F4` |
| iOS 18 simulator | iPhone 16 Pro, iOS 18.4, `286389FD-F05E-4CB0-812D-32752FCFFE52` |
| Physical device | Not available; the owner explicitly deferred the device-only matrix for later testing |
| Build/auth configuration | Debug simulator build; unsigned generic `iphoneos` build; auth UI tests use an ephemeral loopback server through the Debug-only `--awrad-auth-base-url` argument. No repository-level development team is configured, so device signing must use the developer's local Xcode team. |
| Evidence | `/tmp/awrad-debugger-review/ios26`, `/tmp/awrad-debugger-review/ios18`, `/tmp/awrad-debugger-review/ios18-final`, and the result bundles listed below |

## Build and contract evidence

| Check | Result | Evidence |
|---|---|---|
| Generic simulator build-for-testing | **Pass** | `xcodebuild -project awrad.xcodeproj -scheme awrad -destination 'generic/platform=iOS Simulator' build-for-testing` |
| Generic physical-device compile | **Pass** | `xcodebuild ... -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`; app and widget compile for arm64 iOS 18+, embedded widget validation passes, Live Activity/background-audio keys are present, and App Intents metadata is generated. |
| Shared model/content parity | **Pass** | `./check-mobile-model-parity`: 100 Asma, 113 built-ins, one canonical Wird with 8 parts and 452 segments, 18 behavior cases across 7 calculators; Android 12/12 and iOS parity 15/15 |
| Full iOS unit/integration target | **Pass** | 174 tests in 17 suites; `/tmp/awrad-final-derived/Logs/Test/Test-awrad-2026.07.15_12-03-25-+0530.xcresult` |
| Full non-performance UI target | **Pass** | 10/10 tests; `/tmp/awrad-final-derived/Logs/Test/Test-awrad-2026.07.15_07-07-21-+0530.xcresult` |
| Localization parse/key parity | **Pass** | App `en`/`ar`/`ml`: 856 unique keys each and no key differences. Widget: 15 unique keys each and no key differences. All six strings files parse with `plutil`. |
| Diff hygiene | **Pass** | `git diff --check`; the working tree remains intentionally dirty with the parity implementation and no generated build products. |
| Logs | **Pass with simulator limitation** | Latest iOS 26 smoke evidence: `/tmp/awrad-debugger-review/ios26/system-integration-smoke.png` and `.idb.json`. The final iOS 18 review used a fresh locally signed build with its simulated App Group entitlement. No crash, hang, blank screen, SwiftData fault, or actionable app error was observed. CoreUI/app-launch measurement noise is simulator-framework output. |

## Vertical-slice acceptance

| Slice | Status | Evidence and boundary |
|---:|---|---|
| 0 — Baseline and ledger | **Pass** | Root parity gate and native contract suites pass; each destination is owned by the parity ledger. |
| 1 — Schema and canonical content | **Automated pass** | SwiftData migration, rollback/retry/future-version, transaction, repository, widget mutation, and content-remap tests are included in the 174-test result. Signed extension concurrency remains device-only. |
| 2 — Shell and onboarding | **Pass** | UI reset/seed flows cover launch, ten-step onboarding, first-goal completion, and four-tab shell; simulator navigation was reviewed on both OS versions. |
| 3 — Library, Dhikr, Quran, audio | **Pass with device audio hold** | Library tabs, search/detail/custom flows, Quran routing, canonical 113 records, and unavailable-audio behavior are covered by model/UI tests and simulator review. Interruption, unplugged-route, and media-service reset handling is implemented and its decision logic is tested; hardware behavior remains below. |
| 4 — Goal lifecycle | **Pass** | Goal grouping, recurrence, slot/history preservation, scheduling compensation, pause/resume/complete/reset/delete, and editor routes pass unit/UI coverage. |
| 5 — Counting | **Pass with device integration hold** | Count policies, slots, boundaries, history, coach marks, text controls, no-audio state, widget mutations, and completion pass tests. Live Activity compact presentation starts at 0, updates to 1 after a count, and disappears after leaving Counting. The iOS 26 Lock Screen authorization prompt and post-authorization card are readable. Hardware haptics and real-device presentation remain below. |
| 6 — Wird lifecycle | **Pass** | Canonical eight-part content, deterministic IDs, migration, cadence, reader modes, resume, streak, and custom lifecycle pass native and shared-fixture tests. |
| 7 — Home | **Pass** | Simulator review covered light/dark, localized dynamic sections, RTL, Malayalam expansion, large type/contrast, and reduced transparency. A simulated Makkah location reverse-geocodes to Mecca and refreshes Home to the Dhuhr prayer rhythm with the expected location accessibility hint. GPS/prayer accuracy remains device-only. |
| 8 — Settings and device integration | **Pass with device integration hold** | Section order, preference persistence/side effects, transactional notification reconciliation, backup logic, deep links, and destructive confirmations are tested. The iOS 26 notification prompt, Allowed status, successful daily-reminder toggle, and relaunch persistence pass. Actual delivery/sharing/system-extension rows remain below. |
| 9 — Authentication and Community | **Pass** | Auth service and UI tests cover validation, verification/reset, sessions, logout, single-flight refresh/retry, and offline-local boundary using an isolated loopback server. |
| 10 — Liquid Glass and closure | **Simulator pass; device hold** | iOS 26 Liquid Glass and iOS 18 fallback were visually reviewed. Localization and simulator accessibility checks pass. VoiceOver gestures and device integrations still require hardware acceptance. |

## Presentation and accessibility

| Environment | Light/dark | Locales | Large text/contrast | Accessibility services | Result and evidence |
|---|---|---|---|---|---|
| iOS 26.2 — Liquid Glass | **Pass** | English, Arabic RTL, Malayalam **Pass** | Large Dynamic Type and Increase Contrast **Pass** | Accessibility tree **Pass**; Reduce Motion and Reduce Transparency **Pass**; physical VoiceOver gestures **Pending** | Home, Goals, Library, Wird, Settings, dense/empty surfaces, tab chrome, notification authorization, location/prayer refresh, Dynamic Island, and Lock Screen Live Activity reviewed. Fresh Arabic: `home-arabic-rtl-final.png`; Malayalam: `home-malayalam-final.png`; reduced settings: `home-reduced-motion-transparency.png`. Devotional content remains on readable surfaces and glass is limited to chrome/interactive controls. |
| iOS 18.4 — fallback | **Pass** | English, Arabic RTL, Malayalam visual **Pass** | Layout/contrast **Pass** | idb/Maestro accessibility tree **Pass**; Reduce Motion and Reduce Transparency **Pass**; physical VoiceOver gestures **Deferred** | Home, Goals, Library Dhikr/Wird tabs, Wird detail, and full Settings order were reviewed under light/dark. Final locale and accessibility evidence is under `/tmp/awrad-debugger-review/ios18-final`: `home-arabic-rtl.png`, `home-malayalam-adaptive.png`, and `home-reduce-motion-transparency.png`. No iOS 26 API path leaked into runtime. |

The iOS 26 and iOS 18 reduced-motion/reduced-transparency relaunches retained every label and action, removed unnecessary translucency, and showed no overlap or hidden meaning. The overrides were reset after capture. Android deliberately formats the Gregorian Home date with `Locale.ENGLISH`; the English weekday/month in Arabic and Malayalam therefore matches the frozen baseline.

## Findings resolved during review

| Finding | Resolution | Retest |
|---|---|---|
| Home collection and `Today's goals` headings were not localized dynamically. | Moved to localized keys in all three languages. | Fresh Arabic RTL and Malayalam screenshots/accessibility trees pass. |
| `Keep screen awake` was missing from Arabic and Malayalam. | Added matching keys and a localization parity assertion. | Arabic accessibility tree now exposes the translated label and hint. |
| Dhikr detail used a static navigation title. | Title now follows the selected Dhikr. | UI route test passes. |
| Counting coach `Skip` could be outside the safe interactive region. | Overlay moved into the safe area. | Full UI suite passes. |
| Secure-field AutoFill/focus and the system password-update prompt made auth UI tests nondeterministic. | Added a Debug-only UI-test AutoFill bypass, explicit focus dismissal, and system interruption handling. | Full auth UI flow passes. |
| Port 4000 was already occupied by a local Phoenix process. | UI auth server now binds an ephemeral port and injects it through a Debug-only argument. | Auth UI tests pass without changing production API defaults. |
| Two redundant `#require` expressions produced compiler warnings. | Replaced them with direct optional assertions. | `AwradDomainTests` passes without those warnings; `/tmp/awrad-final-derived/Logs/Test/Test-awrad-2026.07.15_11-55-32-+0530.xcresult`. |
| Audio playback had no explicit interruption, output-route loss, or media-services reset coordination. | Added notification-driven pause/resume, fail-safe pause when an old route disappears, observer cleanup, and audio-session reconfiguration after media service reset. | Four lifecycle decision tests pass as part of the 174-test suite; hardware route behavior remains in the device matrix. |
| A Live Activity retained by ActivityKit after process termination could coexist with a replacement. | Startup now ends stale activities for the same goal before requesting the replacement, with an operation token preventing creation after a quick screen exit. | iOS 26 compact presentation start/update/end passes: `counting-live-activity-home.png`, `counting-live-activity-updated-home.png`, and `counting-live-activity-ended-home.png`. Generic `iphoneos` compilation also passes; termination/Lock Screen presentation remains in the device matrix. |
| The Malayalam `Today's goals` title competed with `View all` and truncated on the iOS 18 fallback. | Replaced the rigid one-line header with `ViewThatFits`: compact locales retain the horizontal header, while expanded locales place the action below the full title. | Fresh iOS 18 Malayalam capture `home-malayalam-adaptive.png` shows the complete title and action with no overlap. |

## Accepted platform differences

| Difference | Accepted iOS behavior |
|---|---|
| Visual chrome | Native SwiftUI navigation, sheets, toolbars and tabs; Liquid Glass on iOS 26+, deliberate material/opaque fallback on iOS 18–25. |
| Reminder reliability controls | Notification authorization/status, transactional reconciliation, and system Settings deep link replace Android exact-alarm/battery-optimization surfaces. |
| Extension model | WidgetKit, App Intents, App Group projection/relational mutation, and ActivityKit replace Android widget/service mechanisms. |
| Custom Dhikr editing | iOS additionally supports editing/deleting custom records using the same fields; built-ins remain immutable and canonical. |
| Offline/community boundary | Local devotional features remain available offline; account/community operations require the API. No progress synchronization was added. |

## Physical-device release matrix

These checks cannot be closed by simulator or source inspection. The owner deferred them until an iPhone is available; they are retained here as the later device-test checklist rather than treated as an implementation blocker.

| Integration | Required scenario | Status |
|---|---|---|
| Notification delivery | Permission branches; fixed/prayer/window, daily, and Wird reminders; edit/delete reconciliation; background and time-zone changes | **Simulator authorization/scheduling/relaunch passed; actual delivery pending — physical device** |
| Audio session | Local/remote/unavailable media; backgrounding, interruption, route changes, silent mode and Bluetooth | **Pending — physical device** |
| Widget projection and App Intent | Signed App Group timeline reload, concurrent mutation, caps/warnings, stale entities, sizes and locales | **Pending — physical device** |
| Live Activity | Start/update/end, completion, Lock Screen, Dynamic Island variants, termination/relaunch | **Simulator compact and Lock Screen authorization/presentation passed; remaining scenarios pending — physical device** |
| Location/prayer | Real authorization transitions, current location, prayer recalculation and reset boundary | **Simulator Makkah authorization/location/recalculation passed; GPS accuracy and real transitions pending — physical device** |
| Backup sharing | Share-sheet export, valid/corrupt/future import, cancellation and rollback | **Pending — physical device** |
| Keep-awake/haptics/VoiceOver | Hardware haptics, background/session completion, VoiceOver gestures and focus order | **Pending — physical device** |

## Final decision

**Implementation and simulator acceptance: Pass. Physical-device release acceptance: Deferred by the owner.**

All parity slices have implementation and automated or simulator evidence. No known simulator defect blocks the app. The implementation goal is complete; release sign-off remains open only for the explicitly deferred physical-device matrix above, and those rows must not be inferred from simulator results.
