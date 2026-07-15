# Awrad iOS architecture

## Product boundary

The iOS app is the native SwiftUI implementation of the offline-first Awrad product. Android commit `2f56aa4` is the frozen behavior baseline for the parity release. Parity means the same domain meaning, workflow, section order, actions, and observable states; iOS still uses native navigation, sheets, controls, gestures, accessibility, and system integrations.

Local dhikr, goal, counting, history, Wird, and preference workflows never require authentication. Phoenix owns accounts and device sessions, while progress synchronization and new Community capabilities remain outside this release.

The app currently includes:

- the ten-step first-run journey and four-tab shell;
- the canonical 113 built-in dhikrs, including the generated 100-entry Asma-ul Husna collection;
- custom dhikr, Quran reading context, and local/remote audio states;
- the full goal lifecycle, recurrence, schedule, slot, reminder, and count-policy model;
- manual/audio counting, history adjustment, coach marks, Live Activity, widget, and App Intent counting;
- the canonical eight-part bundled Wird plus custom Wird lifecycle;
- Android-ordered Home and Settings surfaces;
- Keychain-backed authentication, verification/reset flows, and revocable sessions;
- English, Arabic RTL, and Malayalam resources.

## Composition and state

`awradApp` creates three long-lived MainActor objects:

- `AwradStore` is the observable view facade and owns product mutations.
- `AppRouter` owns the selected tab, one navigation path per tab, global sheets, and deep-link dispatch.
- `AppServices` owns authentication, notifications, prayer calculation, audio, location, and other platform facades.

Views read these objects through the SwiftUI environment. Domain and persistence rules stay in the store, repositories, calculators, or services rather than view bodies.

`AppRootView` restores the selected tab and all four navigation stacks through a Codable scene payload. Restoration validates every identifier-backed route and replaces the first stale destination with a recoverable unavailable page instead of silently dropping the path or substituting unrelated content. Verification tokens are redacted and password-reset routes are excluded from scene storage. A pending deep link is applied after bootstrap and takes precedence over restored navigation.

`AppRoute` covers goal detail/edit/schedule/reminders, contextual counting, contextual Quran reading, the full Wird lifecycle, email verification, password-reset completion, and device-session management. Root Home, Goals, Library, and Community destinations remain `AppTab` values.

## Domain semantics

`AwradDomain.swift` contains the platform value model. `AwradCalculators.swift` and feature-specific pure helpers own effective-day, recurrence, due-date, period, cap, slot, progress, streak, prayer, and Wird cadence calculations. Shared fixtures and focused XCTest lock these interpretations to Android.

The logical persistence graph matches Android even though its native implementation differs:

- Dhikr;
- Goal, recurrence weekday/month-day/specific-date children, slots, and reminders;
- season templates and template days;
- count entries with one semantic row per `(goalID, dateKey, slotID)`;
- Wird definitions and sessions with one semantic row per `(wirdID, partID, occasionKey, dateKey)`.

Goal edits preserve count history. Removed slots are archived when history still references them. Persistence failure restores the in-memory value for every facade mutation and exposes failure to the initiating view. Count changes update the aggregate, count entry, widget projection, and completion state as one repository transaction. Reminder scheduling is an observable follow-up outcome and its coordinator reports denied authorization or request failure instead of swallowing it.

## Persistence and migration

Production persistence is an App Group SwiftData store named `AwradRelational`. `AwradSchemaV1` is a `VersionedSchema`, and `AwradSchemaMigrationPlan` is the forward-migration boundary for later releases. `SwiftDataAwradRepository` implements the `DhikrRepository`, `GoalRepository`, and `WirdRepository` interfaces used by `AwradStore`. Normal preferences use App Group `UserDefaults`; authentication credentials use Keychain.

The old snapshot-v5 JSON file is migration input and recovery material, not the normal database:

1. Decode and reject corrupt or unsupported versions.
2. Validate identifiers, references, numeric ranges, and semantic uniqueness.
3. Preserve an immutable backup envelope.
4. Import the complete graph into an empty SwiftData store.
5. Reload, validate, and compare a canonical semantic checksum.
6. Mark migration complete only after verification.

The marker records the source snapshot checksum. It does not compare later legitimate user mutations to the historical import checksum. Migration is idempotent, and a failed import rolls the relational store back.

The app never silently reseeds after a corrupt snapshot, unknown future version, or failed migration. A valid legacy snapshot can run through a protected working fallback while the original remains unchanged. The recovery UI offers retry and export. Corrupt/future data remains blocked from destructive replacement and can still be exported for support.

Backup import validates before replacing the current graph and restores the previous relational state if the import cannot commit.

## Canonical content

`contracts/progress-model/v1` owns cross-platform progress wire compatibility. `contracts/behavior-model/v1` owns deterministic recurrence, effective-day, cap, slot, streak, reminder, and Wird-cadence cases consumed by both native suites. `contracts/wird-model/v1` owns the reviewed bundled Wird, its eight-part weekday assignment, deterministic structural identifiers, manifest, and content fixture. `scripts/generate_wird_model.py` emits byte-identical Android and iOS assets and verifies their hash in check mode.

During content reconciliation, old iOS random nested IDs are mapped by a unique stable content signature. An ambiguous or unresolved in-progress session remains pinned and reachable from a dedicated resume section until that cycle is complete; content is never attached to a guessed identifier.

Built-in dhikr reconciliation uses immutable catalog-key/UUID identities. User-created content retains its original UUID and survives relaunch, backup, and content upgrades.

## Widgets, App Intents, and Live Activity

The app publishes a compact `PersistenceWidgetSnapshot` after committed repository transactions. Widget timelines render from that projection rather than decoding the entire product graph.

Interactive count intents use `SharedAwradWidgetMutationCoordinator`. After relational migration has started, the intent opens the same App Group SwiftData store, applies the goal/slot/effective-day count policy, commits the semantic count row and goal aggregate together, refreshes the projection, and reloads timelines. Direct legacy JSON mutation exists only as a guarded pre-migration compatibility path.

The app refreshes its observable state when it returns active. Counting Live Activities use the same selected goal, slot, progress, and completion results as the main counting surface.

## Authentication

`AuthService` reuses the Phoenix mobile endpoints. Access/refresh/session credentials live in Keychain and old UserDefaults credentials migrate once. Protected requests use single-flight refresh-and-retry so concurrent 401 responses trigger one refresh operation. A transient network/server failure preserves local credentials; definitive rejection clears the revoked session safely.

The service supports login, registration, verification resend/completion, password-reset request/completion, session listing, revoke-one, revoke-all, and logout. Authentication state never gates local counting or reading.

## Navigation and first run

The onboarding order is fixed: Opening, Language, Account, Name, Location, Notifications, Reminder Presets, Audio, Goal Intro, First Goal. The current draft step and values persist between launches. The final action commits preferences and the first goal atomically, then routes to contextual counting.

Home, Goals, Library, and Community each retain a separate navigation stack. Focused destinations hide the tab bar while the root is preserved. Re-selecting a tab returns that stack to its root. `awrad://` parsing is centralized in `AwradDeepLink` and waits for store bootstrap before resolving identifier-backed routes.

## Page organization

- Library owns Android-ordered search, filters, featured collections, category, detail, custom dhikr, Quran reader, and audio states.
- Goals groups items as Today, Upcoming, Completed, and Other. Same-day completed recurring goals remain in Today after unfinished items; paused/inactive goals belong to Other.
- Counting owns slot routing, effective-day boundaries, minimum/target/maximum rules, targetless display, target/max confirmations, history, session count/timer, text presentation preferences, audio, haptics, and completion handling.
- Wird owns list, detail, reader, create, and edit; list/page reading modes and resume all use deterministic part/segment identity.
- Home derives its queue and progress from the shared calculators and presents Android's header, focus, prayer/location state, today's goals, featured collections, and active featured Wird order.
- Settings follows Android's Profile, Appearance, Counting Preferences, Date & Calendar, Notifications, Prayer Times, Audio Library, Language, Data Management, and About order. Android exact-alarm/battery-management actions map to iOS notification status and a system Settings link.

## Design and accessibility

The sage/gold visual identity remains intact. The design system keeps primary devotional text on high-readability surfaces.

- On iOS 26 and later, standard SwiftUI bars, tabs, sheets, and controls receive system Liquid Glass automatically.
- Custom `.glassEffect` is limited to interactive controls and related effects may share a `GlassEffectContainer`.
- Noninteractive cards use readable material or opaque surfaces.
- iOS 18–25 use deliberate material/opaque fallbacks.
- Reduce Transparency disables custom glass; Reduce Motion avoids relying on motion to communicate state.

All user-facing strings belong in `en.lproj`, `ar.lproj`, and `ml.lproj`. The selected app language drives locale and layout direction independently from device language. Dynamic Type, VoiceOver labels/values, RTL ordering, and minimum interactive target sizes are part of the page acceptance contract.

## Verification boundary

The root `./check-mobile-model-parity` command validates the progress, behavior, and bundled-Wird contracts, generated content, registry parity, fixtures, and focused native model suites. Persistence tests exercise valid migration, duplicate/broken data, corruption, future versions, rollback, retry, relaunch, import/export, and widget mutation. Focused feature tests exercise goals, counting, Library/Quran/audio, Wird, auth, Home, Settings, deep links, and localization. Test existence is not runtime acceptance; command results belong in the handoff and debugger review.

Runtime review is recorded in `docs/ios-parity-debugger-review.md` for iOS 26 Liquid Glass and iOS 18 fallback. Notification delivery, audio sessions, widgets, App Intents, Live Activity, and physical-device-only behavior remain explicitly reported when the simulator cannot prove them.

## Deliberate non-parity

- iOS local notifications replace Android exact alarms; notification status and the iOS Settings deep link replace exact-alarm and battery-optimization management.
- Native iOS chrome and interaction patterns replace Material pixels while retaining Android hierarchy and actions.
- Progress synchronization and new Community/social features are not introduced by this parity release.
- Final devotional wording and translations still require human scholarly/language review; structural parity does not claim that review has occurred.
