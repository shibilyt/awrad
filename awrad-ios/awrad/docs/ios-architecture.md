# Awrad iOS Architecture

## Scope

This first native iOS implementation focuses on the offline devotional core:

- onboarding and settings
- seeded dhikr library and bundled wird content
- Android-aligned 13-item built-in dhikr seed set with structured benefits and suggested goals
- custom dhikr creation, editing, and deletion with offline persistence
- template-driven daily, prayer-based, one-time, weekly, seasonal, tracker, and custom goal creation
- active, paused, completed, resumed, reset, and deleted goal lifecycle handling
- counting with persisted progress, count history, and per-sitting session targets
- audio preview/counting with centralized offline-audio download status in Settings reminders
- daily wird reading progress
- local daily, fixed-goal, and prayer-relative reminder scheduling
- PRD-aligned Settings profile editing, prayer-location change, and debug notification test flows
- destructive Settings data-management flows for resetting progress and deleting all goals
- App Shortcuts entry points for opening goals, counting, today's wird, and selected dhikr workflows
- `awrad://` deep links, widget tap targets, and an interactive today's-goal `+1` widget action for home, goals, library, settings, counting, and today's wird workflows
- English, Arabic, and Malayalam app/widget localization groundwork with Arabic RTL behavior

Network auth, community features, and cloud sync are intentionally kept behind service boundaries so they can be added without reshaping the SwiftUI feature layer.

## Shape

The app uses a small MV-style SwiftUI architecture:

- `Core/` contains domain types, calculators, the app store, router, and service facades.
- `DesignSystem/` contains shared visual primitives and bundled image loading.
- `Features/` contains focused SwiftUI screens grouped by workflow.
- `AppIntents/` exposes a narrow system surface for opening Awrad, selecting dhikr entities, and starting focused workflows.
- `AwradWidgetExtension/` contains WidgetKit surfaces for today's goal focus and daily wird.
- `Resources/` carries Android-sourced fonts, images, and wird JSON.
- `*.lproj/` resources localize app, widget, and Info.plist copy for English, Arabic, and Malayalam.

Shared state lives in `AwradStore`, an `@Observable` root model injected through SwiftUI environment. Navigation state lives in `AppRouter`, with one `NavigationStack` path per tab. Nested route destinations hide the tab bar while root Home, Goals, and Library screens keep it visible, preserving per-tab back stacks without exposing the main scaffold inside focused workflows. Tapping the already-selected tab pops that tab back to its root as the PRD refresh behavior. This keeps view state explicit and avoids global singleton routing.

Goal creation uses a Swift `GoalDraft` value model that mirrors the Android draft/mapper shape: presets resolve into a normalized `GoalCreationConfiguration`, and `AwradStore.createConfiguredGoal` owns final goal ID, slot, reminder, duration, and persistence normalization. Cumulative one-time goals auto-complete when their all-time count reaches the target and are only considered due on their start date; recurring and period goals remain active unless explicitly completed or outside their configured date window. The create screen is split into focused SwiftUI subviews for dhikr selection, template selection, and review controls, keeping view logic separate from target/recurrence mapping.

Goal lifecycle state is intentionally represented by two stored fields rather than a broader enum migration: `isActive` controls due/countable status, while `completedAt` distinguishes completed goals from paused goals. This keeps existing snapshots readable while making paused goals visible and recoverable from the Goals screen.

Settings profile editing uses display mode by default, with a local inline draft for Save/Cancel behavior. The persisted name is normalized in `AwradStore`, and the Home greeting reads the same preference so profile updates take effect immediately. Appearance and language are separate preference sections, with app-selected language driving SwiftUI locale/layout direction independently from the device language. The Notifications & Reminders section owns the daily reminder toggle, native hour/minute `DatePicker`, full reminder refresh action, and offline audio status/download controls. The Settings prayer-location control reuses the onboarding search/GPS component but collapses to a city display with a Change action once a location is set.

Onboarding keeps `isOnboarded` false until the final completion step, but the name step still writes the normalized name immediately so a restarted onboarding flow can resume the draft greeting data. The audio-library step selects all downloadable dhikrs by default, supports individual/all selection, and treats Skip as a direct move to prayer-location setup.

Settings data-management actions mirror the Android repository behavior. Reset Progress removes all count entries, resets lifetime counts, clears completion timestamps, and reactivates goals while preserving the goal definitions. Delete All Goals removes goals and their count entries and cancels goal reminders after user confirmation. Development builds include a debug-only notification section for immediate notification delivery, a 30-second scheduled notification, and full reminder rescheduling.

Goal list rows include PRD target badges, date-first history ordering, and destructive confirmation before deleting a single goal. Active, paused, and completed lists sort by creation date newest-first; completed goals are shown in a collapsible section that defaults closed when active goals exist.

The library flow now supports user-created dhikrs using the same `Dhikr` domain model as seeded content. Seeded dhikrs are merged by stable text identity on reload so future bundled additions can be introduced without overwriting locally created entries or breaking existing goal UUIDs. The default Library view groups populated dhikr categories with pinned section headers, search/category filtering falls back to explicit empty states, category routes show localized category descriptions, and Library/Category rows expose the shared singleton audio-preview controls with inline progress. Custom dhikrs can be edited from their detail screen, while seeded dhikrs remain read-only.

Dhikr detail uses a runtime `DhikrGuidanceRegistry` for structured benefits and suggested goals. The registry can localize benefit prose and quick-add goal labels/descriptions for the selected app language while preserving canonical target counts, target policies, recurrence values, and source references. Suggested goals create normalized app goals through `AwradStore.createConfiguredGoal`, so quick-add cards share the same target-policy and recurrence model as the full goal wizard.

Built-in dhikr titles and meaning text resolve through a stable seed-keyed `DhikrDisplayContentRegistry`. This keeps persisted `Dhikr` snapshots backward-compatible while letting Library, goal creation, Counter, Goals, notifications, audio metadata, and WidgetKit snapshots render Arabic/Malayalam display strings from the active app language.

The Counter keeps per-sitting session targets as local view state rather than persisted domain state. Persisted count entries remain the source of truth for total and historical progress, while the session baseline lets a user aim for common sitting counts such as 33 or 100 without changing the underlying goal target. The main count display and explicit `+1` button both use the same manual increment path. Manual count adjustment uses the same `AwradStore.addCount` mutation path as taps and audio counting, so add/subtract changes keep the existing cap, floor, slot, effective-date, and persistence rules. Single-slot goals persist with a nil slot ID, while prayer/time-window split goals keep their selected slot ID; the store normalizes reads and writes so widget, Home, and Counter progress agree. Count history is exposed through `AwradStore.countHistory(for:)`, scoped to one goal and sorted by date descending, then latest update within the same date, for the history sheet.

The Today Focus widget now publishes enough stable metadata for a focused `+1` App Intent: goal ID, slot ID, effective date key, count, target, and remaining count. The widget action mutates the shared snapshot file directly, updates its compact widget payload optimistically, and reloads WidgetKit timelines. The app reloads the snapshot when it becomes active so widget-side count changes become visible in the in-app Counter, Home progress, streaks, and history.

The Home streak contribution grid is produced by `ContributionGridCalculator` rather than view-local date math. It emits exactly 15 Monday-based week columns, keeps Monday-to-Sunday row ordering stable, and marks future days as hidden cells so the grid width remains fixed while preserving the Android/PRD visual semantics. Home overall completion is the average progress across goals due today, not just the fraction of fully completed goals. Home resume-counting cards are whole-card navigation targets and show due-goal count, target, and progress without nested action menus. The Explore grid is derived from current library contents, hides empty categories, and displays per-category dhikr counts.

Wird collection and section labels resolve through language-aware display helpers rather than hardcoded English fields. The Library, Home daily-wird cards, Wird list/detail/reader screens, and WidgetKit snapshot generation all use the same helpers so Arabic/Malayalam titles and weekday subtitles render consistently across app and widget surfaces. Collection descriptions use a seed-keyed display helper for bundled content, preserving imported source text for unknown slugs. Bundled Wird collections merge by slug on load: newer bundled versions replace stale saved content while preserving the collection UUID used by progress records, and missing bundled slugs are inserted next to imported/custom collections.

Wird reading progress is summarized through `WirdProgressSummary` and `WirdCalculator` rather than recomputed inside individual views. The list, detail, reader, and widget surfaces use the same repeat-aware section progress semantics: an item only counts as read after its repeat target is met, and store helpers scope progress to the current effective date. Wird streaks are schedule-aware: daily and morning/evening collections count consecutive completed days from today, weekly collections count consecutive completed weeks, and free collections count distinct completion dates. The reader supports list and page modes, persists the last same-day item position, resumes the reader from that item, auto-advances pager mode after a repeat target is completed, shows section completion feedback, and exposes previous/next section navigation from the same route model used by the rest of the app.

## Persistence

The current store persists a versioned Codable snapshot. In app builds with the `group.app.awrad.awrad` App Group entitlement, the canonical snapshot lives in the App Group container under `Store/awrad-snapshot.json`; older Application Support snapshots are copied into the App Group location on first use. If the App Group container is unavailable, tests and unsupported environments fall back to the legacy Application Support path.

The snapshot decoder is migration-tolerant for missing legacy keys, rejects future schema versions with a clear error, and supports JSON backup import/export from Settings. The shared App Group file gives the app extension a durable write path for small widget actions without opening the app, while preserving the public `AwradStore` methods that views already use. Before adding sync or complex relational queries, replace the store internals with SwiftData or a repository-backed store behind the same public surface.

## Services

Service facades isolate platform APIs:

- `NotificationService` requests notification permission only after the user opts into reminders.
- `NotificationService` uses a pure reminder planner, then maps planned daily and goal reminders into local notifications.
- `AudioSessionService` handles preview, audio-assisted counting loops, offline files, streamed audio sources, background audio, and Now Playing remote controls.
- `PrayerTimeService` calculates offline daily prayer summaries for location-aware day context and reminders.
- `AwradWidgetSnapshotPublisher` writes a small App Group widget payload, while the shared App Group snapshot file remains the durable app/widget state boundary.

## Localization

The app language preference is applied through SwiftUI locale and layout-direction environment values, so Arabic renders right-to-left without relying on the device language. Bundled Noto Naskh Arabic font files are registered in the app bundle; Arabic devotional text and Arabic default UI text use Noto Naskh Arabic while localized SwiftUI strings resolve from the selected app language. Shared UI primitives accept `LocalizedStringKey` for reusable titles, subtitles, pills, and empty states.

Localized resources currently cover the primary app shell, onboarding, settings options, tab labels, common actions, permission copy, reminder notification copy, dynamic count summaries, localized dates/times, advanced goal-editor dynamic labels, built-in dhikr display titles/meaning text, dhikr guidance benefit/suggested-goal prose, bundled wird collection descriptions, and widget copy in English, Arabic, and Malayalam. Widget snapshot fallback copy is generated from the selected app language before being written to the App Group, so widgets do not need to decode the full store.

Goal slot labels are derived from structured slot metadata instead of persisted English labels. This lets "After Fajr" and similar prayer slots render in the active app language while keeping backup data stable.

Wird collection and section titles now choose Arabic source fields when the selected app language is Arabic. Bundled section titles and weekday subtitles have Malayalam display mappings until Malayalam source fields exist in the bundled wird JSON. Bundled collection descriptions resolve through localized slug mappings while imported or future unknown collections fall back to their stored description.

Seeded devotional content remains intentionally data-driven: Malayalam wird item translation/source fields and final scholarly wording review still need a content-localization pass before declaring full Arabic/Malayalam parity.

## Review Notes

The implementation avoids Android-specific assumptions:

- iOS reminders use local notifications rather than exact alarm semantics.
- Notification permission is user-initiated from onboarding/settings.
- Goal and prayer-relative reminders are scheduled as due-date-aware dated one-shot notifications for the current scheduling window and refreshed when the app opens, becomes active, or prayer/reminder settings change. Past times for the current day are skipped instead of firing immediately.
- Background audio setup, Now Playing metadata, and remote playback controls are separated from counting state.
- Manual count feedback is preference-gated: haptics and a short iOS system tick are emitted only for positive applied count deltas, while audio-assisted counting owns its own playback state.
- App metadata is explicit in `awrad/Info.plist` so the `awrad://` deep links, location usage copy, and `audio` background mode are present in the built product.
- Raw PNG assets are loaded from the app bundle rather than assuming asset-catalog names.
- The design system centralizes the PRD sage, gold, neutral, surface, and background colors as light/dark-aware SwiftUI tokens. Manrope, Plus Jakarta Sans, and Noto Naskh Arabic are registered in `Info.plist`; headings use Manrope, default Latin/Malayalam text uses Plus Jakarta Sans, and Arabic mode applies Noto Naskh Arabic across the app.
- The language setting applies locale, localized strings, and Arabic right-to-left layout at runtime; Hijri dates include a localized AH suffix, and Home refreshes its effective date when Maghrib-related prayer calculation preferences change. Remaining localization work is content/data coverage rather than the UI shell.
- User-created dhikrs are marked separately from seeded content and survive app relaunch/backup through the snapshot store.
- Deleting a custom dhikr removes linked goals, count entries, and scheduled goal reminders so no orphaned progress remains after the source dhikr is gone.
- The current built-in seed list now matches the Android PRD's 13 dhikrs, including Swalath for Debt and the Ramadan first/second ten-night dhikrs. Existing local snapshots preserve earlier seeded entries until a deliberate cleanup migration is introduced.
- App Intents use stable title-based slugs for dhikr selection so system shortcuts are not tied to local persistence UUIDs.
- WidgetKit is implemented with an embedded `AwradWidgetExtension`, App Group entitlements, and a small snapshot payload for today's Awrad and daily wird progress.
- The Today Focus widget includes an interactive `+1` App Intent backed by the App Group snapshot, so simple counting can complete from the widget without requiring an app launch.
- Prayer-split goals distribute remainder counts across prayer slots, preserving the user's requested total target instead of truncating when the target is not divisible by five.
- Weekly and other period-total goals now sum counts across their current period window instead of only the current date.
- Seasonal goals use the iOS Islamic Umm al-Qura calendar to resolve built-in devotional seasons such as Ramadan, white days, Ashura, Arafah, and Dhul Hijjah 1-10.
- Paused goals are no longer treated as completed goals; the Goals screen now exposes active, paused, and completed sections with resume, complete, reset, and delete actions.
- Empty notification schedules return without requesting notification authorization, so resuming a non-reminder goal does not trigger a permission prompt.
- Daily-wird app and widget labels use shared language-aware collection/section display helpers, preventing Arabic/Malayalam mode from falling back to English on bundled wird metadata.
- Daily-wird list, detail, reader, and widget progress now use shared repeat-aware summaries instead of view-local calculations, so completion badges, progress bars, and widget payloads follow the same rules.
- Home Daily Wird lists every collection in sort order with today's section progress, schedule-aware streak context, completion state, and card-to-detail navigation.
- Home Resume Counting, Wirds for Today, and Explore sections now use PRD-aligned whole-card navigation: due goals open Counting directly, View All returns to the Goals tab root, completed Wird cards swap the progress bar for a Complete badge, category cards show only populated categories with counts, and Wird View All opens the Wird list.
- Progress calculations now average due-goal progress for Home completion, sort count history by date then latest update, and keep one-time cumulative goals due only on their start date while still auto-completing at the all-time target.
- Nested routes hide the bottom tab bar, so Counting, creation, detail, category, Settings, and Wird flows render as focused screens while tab root state remains preserved.
- Wird detail now displays a schedule-aware streak calculated by `WirdCalculator`, matching daily/morning-evening, weekly split, and free-reading PRD semantics.
- Bundled Wird collections now update by slug/version on load and insert missing bundled slugs without dropping imported/custom collections or changing existing collection IDs.
- Deep links are parsed through a small core `AwradDeepLink` type. The root view defers store-dependent links such as counting and today's wird until bootstrap finishes, while WidgetKit snapshots publish optional workflow-specific URLs with static fallbacks for older snapshot payloads.
- The Wird reader now has list/page reading modes, same-day item-position resume, pager auto-advance on repeat completion, section completion feedback, and previous/next section navigation while keeping section routing in `AppRouter`.
- Bundled wird collection descriptions are localized by slug while preserving fallback behavior for imported/custom collections.
- Advanced goal-editor stepper labels use explicit localized format strings rather than interpolated English-only SwiftUI text.
- Built-in dhikr display strings are localized by seed key rather than by local UUID, so restored backups and merged seed updates keep stable IDs while still rendering in the selected language.
- Dhikr guidance localization transforms only display prose and quick-add labels, keeping the underlying suggested-goal counts and recurrence policies stable for persistence and matching.
- Settings includes centralized offline-audio controls inside Notifications & Reminders backed by `AudioLibraryCalculator`, so onboarding, Library detail, Counter, and Settings all agree on which seeded audio files are available or downloaded.
- Counter session targets intentionally reset when the view/session changes; durable devotional progress remains in count entries, and the history sheet reads those entries without adding a second persistence model.
- Counter manual adjustment is a sheet-level workflow with add/subtract modes and a destructive confirmation for subtraction, but the actual count mutation remains centralized in the store.
- Counter audio counting is tied to the active goal/slot: switching slots stops the loop, reaching the target stops playback, and navigating back while audio is running asks the user to either stop and exit or continue counting.
- Home contribution-grid date alignment is centralized in `ContributionGridCalculator`, including calendar/time-zone-aware date-key generation for tests and future non-default calendar inputs.
- Settings destructive data actions require confirmation and explain the irreversible effect before resetting progress or deleting all goals.
- Settings profile editing now matches the PRD display/edit/save/cancel workflow instead of leaving the name as an always-live text field.
- Settings reminder time uses a native time picker while preserving the existing stored hour/minute preference model and reminder rescheduling behavior.
- Settings prayer location now collapses to the selected city plus a Change action, while onboarding still shows the full search/current-location controls inline.
- Settings debug notification controls are compiled only in DEBUG builds and use explicit user actions before requesting notification authorization.

## Verification

- `xcodebuild -project awrad.xcodeproj -scheme awrad -destination 'generic/platform=iOS Simulator' build-for-testing` succeeds.
- Focused XCTest for custom dhikr persistence and edit/delete referential integrity succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for the Android-aligned built-in dhikr seed set and structured guidance registry succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for Arabic/Malayalam wird display names and section metadata succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for bundled wird collection description localization succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for repeat-aware wird progress summaries, effective-date scoping, weekly section selection, and widget wird progress succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for deep-link parsing, widget workflow URLs, and the Settings audio-library summary succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for widget Arabic daily-wird subtitles and advanced goal-editor localized format strings succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for seeded dhikr display content localization and widget localized goal titles succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for dhikr guidance benefit and suggested-goal localization succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for prayer-based goal drafts, open trackers, and weekly period counts succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for capped count behavior and goal-scoped count-history sorting succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for Monday-based contribution-grid layout and streak continuity succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for Settings Reset Progress semantics and capped count behavior succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for Settings profile name normalization/persistence and backup import/export succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for Settings debug notification compilation path and fixed reminder planning succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for Settings location-related compilation and Maghrib effective-date behavior succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for the Settings reminder-time picker compile path and fixed reminder planning succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for shared widget count mutation and app reload-from-disk behavior succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- Focused XCTest for paused/completed goal lifecycle succeeds on iPhone 16e Simulator (`E9A7B204-C772-483B-BF09-2ED50F43A8B2`).
- The built app bundle contains localized app and widget `Localizable.strings` and `InfoPlist.strings` resources for `en`, `ar`, and `ml`.
- Manual Simulator install/launch succeeds on iPhone 16 Pro iOS 18.4.
- Arabic runtime verification shows translated onboarding copy, right-to-left layout, and localized navigation controls.
- A later parity pass verified Arabic runtime launch after adding localized dynamic count/date/reminder strings and structured prayer-slot labels.
- A custom-dhikr Simulator smoke check opens Library, launches Create Dhikr, saves a new item, edits it from the detail action menu, verifies the updated detail text, and deletes it through confirmation back to Library.
- A dhikr-guidance Simulator smoke check opens Tahleel detail, verifies structured benefit and suggested-goal cards, opens the Add Suggested Goal confirmation, and confirms Daily 100x into the Counter screen.
- A goal lifecycle Simulator smoke check opens Goals, shows the active goal action menu, pauses the goal into a visible Paused section, resumes it back to Active, and confirms the rebuilt Goals screen renders the action menu/status pill layout.
- A system-surface Simulator smoke check opens `awrad://todays-wird` directly into the Reader, `awrad://counting?dhikr=surah-ikhlas` into the Surah Ikhlas goal flow, and `awrad://settings` into Settings with the Audio Library section visible.
- A counter Simulator smoke check opens `awrad://counting`, sets a 100-count session target, increments the counter, verifies `1 of 100 this session`, and opens Count History showing the new dated `+1` entry.
- A manual-adjustment Simulator smoke check opens `awrad://counting`, uses Adjust in add mode to move the count from 0 to 1, switches to subtract mode, verifies the destructive subtraction confirmation, and returns the count to 0.
- A count-feedback Simulator smoke check enables Settings > Sound on count, opens `awrad://counting`, taps `+1`, and verifies the counter advances without runtime errors through the tick-sound path.
- A main-counter tap Simulator smoke check opens `awrad://counting`, taps the count display cluster, and verifies it increments independently of the explicit `+1` button.
- A Home contribution-grid Simulator smoke check launches the app, verifies the streak card renders, and inspects the accessibility hierarchy for the 15-week Monday-based grid through the current week ending Sunday, May 31, 2026.
- A Settings data-management Simulator smoke check opens Settings, scrolls to Data, and verifies Reset Progress and Delete All Goals each present destructive confirmation copy before execution.
- A Settings profile Simulator smoke check opens display mode, enters edit mode, saves a changed name, verifies Home greeting updates, and verifies Cancel discards a draft edit.
- A Settings debug Simulator smoke check verifies the DEBUG-only notification controls are visible and confirms Reschedule all reminders reports success.
- A Settings prayer-location Simulator smoke check searches for Mecca, applies the result, verifies the collapsed city/coordinate display with Change, and verifies Change expands the search controls again.
- Full XCTest launch was retried against the booted simulator UUID, but the runner hung after build/sign and was interrupted after more than two minutes without test output.

## Goal Count Policy (Android parity)

Goals now carry an explicit count-rule axis alongside the existing schedule/timing/target-policy
axes. `Goal.countPolicy` (`CountPolicy`) holds `minimumCount`, `targetCount`, `maximumCount`, the
streak/reminder/completion thresholds, and a `CapBehavior`; goals also store a `SlotCountingPolicy`
and a `CompletionPolicy`. Slots gained `minimumCount`, `maximumCount`, `capBehavior`, `isActive`, and
`archivedAt`. The effective target remains the slot-target sum (`Goal.totalTarget`) so existing
progress math is unchanged; `minimumCount` drives the minimum-for-streak rule
(`GoalProgressCalculator.streak(for:entries:todayKey:)`) and the counting chip.

`AwradStore.applyCount` replaces the blanket clamp with `CapBehavior` handling and returns a
`CountApplyResult { appliedDelta, capEvent }` so the counting UI can surface warn/block events;
`addCount` is now a thin `Int`-returning wrapper for existing callers and the widget. The legacy
`createGoal` helper sets `blockAtTarget` to preserve prior capping behavior, while the default for
configured goals is the Android-aligned `allowOverTarget`. Snapshot schema version is bumped to 3;
`loadSnapshot` already degrades a stale snapshot to a clean re-seed via `try?`.

## Goal Creation — count-rule axis

The Advanced goal editor now exposes the full count-rule axis on the Custom preset:
`GoalDraft.countRuleMode` (Tracker/Minimum/Target/Stretch/Exact/Bounded) plus `minimumText`,
`maximumText`, `capBehavior`, and `slotCountingPolicy`. `GoalDraft.configuration` builds a
`CountPolicy` (and resolves a `CompletionPolicy`) into `GoalCreationConfiguration`, which
`createConfiguredGoal` persists. Count-rule validation enforces the PRD ordering rules
(`min < target < max` for Bounded, target > min for Stretch, positive exact, tracker-has-no-target).
Quick Create chip presets and defaults follow the PRD (Daily 33·70·100·313 default 33, One-Time
100·1000·10000 default 1000). New count-rule labels are localized in en/ar (ml falls back).

## Goal Counting — Android parity behaviors

The Counter now consumes `AwradStore.applyCount`'s `CountApplyResult`: `WarnOverTarget` shows
`count_over_target_warning`, hard caps show `count_hard_cap_reached`. A `Minimum: N` chip
(`counting_min_for_streak`) renders when `goal.minimumForStreak` is set. Slot timing is enforced
through `SlotStatusCalculator` (time-window slots resolve ACTIVE/UPCOMING/ENDED from their minutes;
prayer slots are permissive pending live prayer times) gated by the goal's `SlotCountingPolicy`:
STRICT blocks non-active counts, WARN_AND_ALLOW confirms once per slot (remembered in-memory), SILENT
allows. A 60-second ticker refreshes the slot status and drives timer-session completion. Sessions
support both Count and Timer modes (`SessionTargetType`) with PRD presets (33/100/500/1000 and
5/10/15/30 minutes); a goal-completion alert (`goal_reached_*`) fires on full completion, and a
slot-complete banner (`counting_slot_complete`) appears when the active slot is done but others
remain. New counting string keys are localized in en/ar.

## Counting coach marks & Live Activity

First-run coach marks (`Features/Counting/CountingCoachMarks.swift`) overlay the Counter when
`UserPreferences.hasSeenCountingGuide` is false: a dimmed scrim that does not capture hits (so the
COUNT button stays live), a hint card per step, and gating — the tap step requires 3 real taps
("X of 3"), conditional steps (audio) are appended only when applicable. "Skip" or finishing marks
the guide seen via `AwradStore.updatePreferences`.

A counting Live Activity is defined in `Shared/AwradCountingActivity.swift`
(`AwradCountingActivityAttributes`, shared by app + widget), rendered by `CountingLiveActivity` in
`AwradWidgetBundle` (Lock Screen + Dynamic Island compact/expanded/minimal), and driven by
`CountingLiveActivityController` (started on Counter appear, updated on each count, ended on
completion/disappear). `NSSupportsLiveActivities` is set in `awrad/Info.plist`. All ActivityKit calls
no-op gracefully when unavailable.

## Bottom-sheet selects & single-page goal creation

Select controls open a **bottom sheet** instead of a system menu/popup. The reusable
`AwradBottomSheetPicker` (`DesignSystem/AwradBottomSheetPicker.swift`) renders a row (title +
current value + chevron) that presents its options in a sheet with a checkmark on the active one.
Settings uses it for Day reset, Calendar, Calculation method, Madhab, Appearance, and Language. In
goal creation, `AdvancedPickerRow` was reworked to present its existing `Picker` content inside a
sheet, so every dropdown (Repeat, Calendar, Month, Season, Relation, count Rule, cap behavior, slot
policy) became a bottom sheet with no call-site changes.

Goal creation is now a **single progressive-disclosure page** (`Features/Goals/CreateGoalView.swift`)
driven entirely by the `GoalDraft` value type — no steps, no Next buttons. The page stacks: a live
**goal-sentence hero** (`GoalSentenceBuilder`), a dhikr card whose "Change ›" opens the searchable
picker as a sheet, a `GoalTypeChoice` select (Daily/One-Time/Tracker/Advanced), a per-type config
block that swaps with a spring animation, and a Fine-tune section, over a pinned `GoalCreateBar`
that stays disabled (showing the current `validationMessage`) until `draft.configuration` is valid.
"Advanced" reveals the Schedule + Count-rule editors inline rather than navigating. Selecting a new
dhikr resets the draft to defaults (PRD §3.1). The former wizard step views remain in the file but
are no longer referenced (slated for cleanup).

## Next Parity Work

1. Move persistence from the shared Codable snapshot to SwiftData or a repository-backed store when sync, indexing, or complex migrations require it.
2. Add auth/community modules once the backend contract is confirmed.
3. Complete localization for Malayalam wird item translation fields and final devotional wording review.
4. Extend inline interactive WidgetKit controls beyond today's-goal `+1` to Wird item progress once the widget UI is designed for that denser interaction.
5. Add richer audio artwork, playlists, and reciter selection after the media catalog is finalized.
