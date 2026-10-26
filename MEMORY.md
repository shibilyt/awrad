# Repository memory

This file stores durable repository facts and a concise append-only change log. It is not a transcript, task list, or substitute for code and tests.

## Durable facts

- Awrad isn't released: no installed users, so there's no upgrade or data-migration compatibility to keep.
- Awrad is being rebuilt as four contract-first projects: `awrad-server-next`, `awrad-android-next`, `awrad-ios-next` and `awrad-web-next` (ADR-2026-10-14). All four rebuild projects exist as scaffolds: `awrad-server-next`, `awrad-android-next`, `awrad-ios-next`, `awrad-web-next`.
- `contracts/` is the shared source of truth: schemas, behaviour fixtures and built-in content, with an OpenAPI spec planned.
- Git runs at the root; each project's toolchain runs inside its own directory.
- Mobile apps are offline-first for dhikr, goals, counting and wird. The web app is online-only.
- Browsers authenticate with Phoenix cookie sessions plus CSRF; mobile with bearer tokens bound to device sessions (ADR-2026-10-15, ADR-2026-07-12).
- `awrad-android-next` keeps Room at version 1 until the first release (its ADR 0003).
- Toolchains are pinned at the root: `mise.toml` (OTP 29.1.2, Elixir 1.20.4, Node 24.22.0, Zulu JDK 17, SwiftLint 0.65.1), `.xcode-version` (26.2), and `compose.yaml` (Postgres 18.6 on port 5433, the fallback). Postgres major 18 is the target for local, CI and the Dokploy database. The default local database is the machine's own Postgres 18 on 5432; new-server databases are `awrad_next_dev` / `awrad_next_test`.
- Content is localized in English, Arabic and Malayalam.

## Frozen apps (reference)

`awrad-android/`, `awrad-ios/` and `awrad_server/` are read-only. The facts below describe their current behaviour and are the evidence base for the rebuild.

### Facts

- The repository contains three independently buildable projects: `awrad-android`, `awrad-ios`, and `awrad_server`.
- Git operations run at the umbrella root; Gradle, Xcode, and Mix commands run inside their project roots.
- Both mobile apps are designed to remain useful without a network connection.
- The Phoenix server currently owns accounts, browser session authentication, and mobile JSON authentication.
- Android persists app data with Room. Exported Room schemas are committed migration evidence.
- iOS exposes app state through `AwradStore`, persists the product graph in an App Group SwiftData repository, and shares a compact projection plus relational mutations with its widget extension. Snapshot v5 is migration/backup input.
- The API persists server data with Ecto/PostgreSQL and uses timestamped migrations.
- User-facing content is localized in English, Arabic, and Malayalam where platform resources exist.
- Android and iOS retain native implementations. Android commit `2f56aa4` is the frozen behavior baseline for the current iOS parity release; later Android changes require a separately reviewed delta.

### Implemented cross-project capabilities


- Mobile registration is verification-first and creates a revocable device session only after email verification.
- API access JWTs are bound to active device sessions; refresh rotation is transactional and detects replay.
- API JSON and browser registration, password-login, magic-link, and password-reset routes have explicit repository-owned IP/account abuse limits; browser registration returns a generic response for existing and unused emails.
- Forgot-password requests are implemented for both mobile clients and the API.
- Confirmed passwordless web accounts return a structured `password_setup_required` mobile-login state; web settings and Android guide users through the existing generic password-reset flow without a schema migration.
- Authenticated logout is implemented by the API and both mobile clients.
- Android credentials use an Android Keystore-backed AES-GCM store and refresh is serialized across concurrent failures.
- Android debug builds default to the emulator host API address; release builds require an explicit HTTPS API URL.
- iOS `AuthService` defaults to a loopback development API URL and supports dependency injection of another base URL.
- iOS credentials are stored in Keychain, and protected requests use single-flight refresh-and-retry while local devotional workflows remain available offline.
- Practice settings synchronization is implemented additively for Android and iOS: account-wide day reset/calculation method/madhab use optimistic server revisions, while timezone and location are stored per installation. Anonymous non-default local choices can seed only a new server-default account; established-account conflicts resolve server-first.

### Known gaps and cautions


- General cloud synchronization for goals, counts, dhikrs, and wirds is planned, not an implemented repository-wide contract.
- API dhikr/tracking schemas outside progress and practice settings should not be described as a complete sync surface until routes, ownership rules, revision semantics, and mobile consumers exist.
- Some API memory documents and Android plans are historical snapshots. Verify current routes and behavior in code before relying on them.
- Full API tests require PostgreSQL. Android instrumentation requires an emulator/device. iOS UI/runtime validation requires an available simulator.
- Notification delivery, audio-route interruptions, signed App Group widget/App Intent mutation, Live Activity lifecycle, real location accuracy, and keep-awake/haptics require physical-device validation; simulator evidence is not equivalent.
- Production TLS correctness depends on origin isolation and trusted forwarding-header overwrite. Keep the load-balancer/origin ACL and proxy-header contract documented with deployment configuration.

## Maintenance rules

- Update durable facts only when the repository's current behavior changes.
- Add a log entry only for a meaningful merged or completed change.
- Keep entries factual and link evidence by repository-relative path.
- Never record secrets, credentials, personal data, raw logs, or speculative architecture as fact.
- If a fact becomes false, correct the fact and add a log entry explaining the transition; do not preserve misleading text for chronology.

## Change log

Use this format:

```text
### YYYY-MM-DD — Short change title
- Area: Android | iOS | API | Cross-project | Documentation
- Change: What became true.
- Evidence: `path/to/code-or-test`
- Commit: short-hash or `uncommitted`
```

### 2026-07-12 — Unified repository documentation established

- Area: Documentation
- Change: Added root orientation, structure, workflow, contract, command, test, decision, and memory guidance with scoped platform instructions.
- Evidence: `AGENTS.md`, `STRUCTURE.md`, `LOOPS.md`, `CONTRACTS.md`
- Commit: uncommitted

### 2026-07-12 — Added progressive documentation map

- Area: Documentation
- Change: Reduced root agent guidance to a compact map with hard invariants and added `docs/index.md` for progressive project and subsystem navigation.
- Evidence: `AGENTS.md`, `docs/index.md`, `README.md`
- Commit: uncommitted

### 2026-07-13 — Added API security baseline

- Area: API | Documentation
- Change: Documented API trust boundaries, authentication/session invariants, public-auth abuse controls, authorization rules, production proxy requirements, endpoint review steps, and current security follow-up items; implemented shared browser-auth abuse limits and generic registration responses.
- Evidence: `awrad_server/memory/security.md`, `awrad_server/lib/awrad_server_web/browser_auth_protection.ex`, browser-auth controller tests, `TESTING.md`
- Commit: uncommitted

### 2026-07-15 — Implemented the iOS Android-parity architecture

- Area: iOS | Cross-project | Documentation
- Change: Froze Android `2f56aa4` as the iOS behavior baseline; added the App Group SwiftData repository/migration boundary, canonical progress/behavior/Wird contracts, Android-equivalent iOS route families, Keychain authentication with single-flight refresh, and an explicit runtime/physical-device acceptance ledger.
- Evidence: `awrad-ios/awrad/awrad/Core/Persistence/`, `awrad-ios/awrad/awrad/Core/AwradStore.swift`, `awrad-ios/awrad/awrad/Features/`, `contracts/behavior-model/v1/`, `contracts/wird-model/v1/`, `docs/ios-android-parity-ledger.md`, `docs/ios-parity-debugger-review.md`
- Commit: uncommitted

### 2026-09-07 — Added password setup handoff for passwordless web accounts

- Area: Cross-project | Documentation
- Change: Mobile password login now identifies confirmed web accounts without a password, while web settings explains the requirement and Android opens the existing reset flow with the email prefilled. The additive error code keeps existing clients compatible.
- Evidence: `awrad_server/lib/awrad_server_web/controllers/api/auth_controller.ex`, `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/auth/LoginScreen.kt`, `CONTRACTS.md`
- Commit: c576514

### 2026-09-09 — Added cross-client practice settings synchronization

- Area: Android | iOS | API | Cross-project | Documentation
- Change: Added verified mobile GET/PUT practice settings routes, revision-checked account policy writes, per-installation device-context writes, and native reconciliation on authentication/foreground sync. Existing progress-sync routes and envelopes remain unchanged.
- Evidence: `awrad_server/lib/awrad_server_web/controllers/api/practice_settings_controller.ex`, `awrad-android/app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/sync/PracticeSettingsRepository.kt`, `awrad-ios/awrad/awrad/Core/PracticeSettingsSync.swift`, `CONTRACTS.md`
- Commit: uncommitted

### 2026-09-09 — Added browser Maghrib effective-day resolution

- Area: Web | API | Documentation
- Change: The authenticated web companion now calculates Maghrib locally with bundled Adhan JS, resolves the per-device effective practice date, uses it across read models and counting, and validates the claimed date in `WebSync`; missing location or unavailable prayer times fall back explicitly to midnight.
- Evidence: `awrad_server/assets/js/practice_day.js`, `awrad_server/lib/awrad_server/practice_day.ex`, `awrad_server/lib/awrad_server/web_sync.ex`, `docs/progress-sync-architecture.md`
- Commit: uncommitted

### 2026-10-15 — Started the four-project rebuild

- Area: Cross-project | Android | Documentation
- Change:
  - Decided to rebuild Awrad as four contract-first projects in vertical slices, with the old three frozen as reference.
  - Recorded the stack: Phoenix API-only, Compose, SwiftUI/SwiftData, React.
  - Browsers use Phoenix cookie sessions.
  - Added the `awrad-android-next` scaffold with build-enforced standards.
  - Cleaned up the repo root.
- Evidence: `DECISIONS.md` (ADR-2026-10-14 ×2, ADR-2026-10-15), `docs/rebuild-plan.md`, `awrad-android-next/`, `docs/reference/android-spec/`
- Commit: dd2a944, af8fcb6, e06bd7b, c787b32

### 2026-10-15 — Root docs rewritten for the rebuild

- Area: Documentation
- Change:
  - `AGENTS.md`, `STRUCTURE.md`, `LOOPS.md`, `TESTING.md`, `COMMANDS.md`, `README.md` and `docs/index.md` now describe the rebuild.
  - Frozen-app maps moved to `docs/reference/legacy-*.md`.
  - `CONTRACTS.md` is labelled as the frozen server's contract.
- Evidence: `AGENTS.md`, `STRUCTURE.md`, `LOOPS.md`, `docs/reference/`
- Commit: 5e2b905

### 2026-10-16 — API style guide adopted

- Area: Cross-project | Documentation
- Change:
  - `contracts/api/STYLE.md` defines the rules for every `awrad-server-next` endpoint: one `/api/v1` prefix; one ledger write path for progress; RFC 9457 errors with stable codes; `expected_revision` conflicts; whole-number counts as JSON integers; cursor pagination; `Idempotency-Key`.
  - The new API defines its own schemas; `contracts/*/v1` stay as frozen reference.
- Evidence: `contracts/api/STYLE.md`, `DECISIONS.md` (ADR-2026-10-16)
- Commit: see git log

### 2026-10-16 — Contract tooling for the API spec and fixtures

- Area: Cross-project | Documentation
- Change:
  - Added the OpenAPI 3.1 skeleton (`contracts/api/openapi.yaml`, bundled into `openapi.bundled.json`), plus a Spectral ruleset enforcing `STYLE.md` with tests proving each rule fires.
  - Added the `awrad-fixture/1` format with its checker.
  - Recorded how clients get types: the web generates them; mobile hand-writes classes covered by spec-example contract tests.
- Evidence: `contracts/api/`, `contracts/FIXTURES.md`, `contracts/package.json`, `DECISIONS.md` (ADR-2026-10-16, client types)
- Commit: see git log

### 2026-10-16 — Pinned toolchains and local Postgres

- Area: Cross-project | Documentation
- Change:
  - Added the root `mise.toml` (Erlang 29.1.2, Elixir 1.20.4, Node 24.22.0, Zulu JDK 17), `.xcode-version` (26.2), and `compose.yaml` (Postgres 18.6 on 5433, the fallback when there's no local Postgres 18).
  - Added `scripts/check-toolchain`.
  - `contracts/` and `awrad-android-next/` validation pass on the pinned runtimes.
- Evidence: `mise.toml`, `compose.yaml`, `scripts/check-toolchain`, `COMMANDS.md`
- Commit: see git log

### 2026-10-16 — CI skeleton for the rebuild projects

- Area: Cross-project | Documentation
- Change:
  - Added `.github/workflows/ci.yml`: change detection, per-project jobs (`contracts`, `contracts_v1`, `android_next`) running each validation command on `mise.toml` toolchains, and a `ci_ok` gate job.
  - The frozen server's `api-image.yml` used to auto-deploy to Dokploy on any `awrad_server/**` push, including docs. A run triggered by the frozen-project banner commit was cancelled before anything was built. The workflow is now **manual-deploy only** (`workflow_dispatch` from `main`); pull requests still test and build.
- `main` is protected: `ci_ok` required, no force pushes or deletion; admins may push directly.
- Evidence: `.github/workflows/ci.yml`, `docs/rebuild-plan.md`
- Commit: see git log

### 2026-10-17 — awrad-server-next scaffold

- Area: API | Cross-project | Documentation
- Change:
  - Added `awrad-server-next/`: API-only Phoenix 1.8.15 on Elixir 1.20.4 / OTP 29, enforced by `mix validate` (warnings as errors, Boundary, Credo strict plus the 400-line limit, Sobelow, Dialyzer, format check).
  - RFC 9457 errors and standard headers on every response; the session cookie is `_awrad_session`.
  - `get_browser_csrf_token` is contract-tested against `contracts/api/openapi.bundled.json`.
  - CI `server_next` job added.
- Evidence: `awrad-server-next/`, `.github/workflows/ci.yml`
- Commit: see git log

### 2026-10-17 — awrad-ios-next scaffold

- Area: iOS | Cross-project | Documentation
- Change:
  - Added `awrad-ios-next/`: a thin Xcode project plus the local `AwradKit` package (domain, data, design system, features, testing), with the module graph enforced by the compiler and a rules check.
  - Swift 6 with complete concurrency checking and warnings as errors; `swift format` plus SwiftLint strict; an en/ar/ml translation check; the SwiftData pre-release policy.
  - Placeholder flow verified on an iOS 26.2 simulator in English and Arabic.
  - CI `ios_next` job on `macos-26`.
- Evidence: `awrad-ios-next/`, `.github/workflows/ci.yml`
- Commit: see git log

### 2026-10-21 — awrad-web-next scaffold

- Area: Web | Cross-project | Documentation
- Change:
  - Added `awrad-web-next/`: React 19, TypeScript 6.0, Vite 8 with the React Compiler, TanStack Router and Query, `openapi-fetch` on generated spec types, React Aria plus Tailwind tokens, i18next en/ar/ml.
  - Enforced by `npm run validate`: types fresh, translations, typecheck, lint (strict type-checked, a11y, no hard-coded text, 400 lines), Prettier, dependency-cruiser module rules, tests, build.
  - Verified in a browser against `awrad-server-next` (401 problem, RTL).
  - Web ADR 0001 fixes one-origin hosting through a reverse proxy.
- Evidence: `awrad-web-next/`, `.github/workflows/ci.yml`
- Commit: see git log

### 2026-10-21 — Slice playbook and agent workflow

- Area: Documentation
- Change:
  - Added `docs/slice-playbook.md` (the procedure from brief to closed slice, the definition of done, parallel per-project agents, approval points) and the brief template `docs/slices/_template.md`.
  - `AGENTS.md` now scopes graft queries to `-next` projects and treats frozen-project hits as evidence only.
  - Phase 0 complete.
- Evidence: `docs/slice-playbook.md`, `docs/slices/_template.md`, `AGENTS.md`
- Commit: see git log

### 2026-10-26 — Slice 1a: goal rules as shared fixtures

- Area: Cross-project
- Change:
  - The goal rules (effective practice day, due, requirement standing, days per period, completion, streak, validity) are 125 `awrad-fixture/1` cases in `contracts/goal-model/v1/`. Android (`:core:domain`), iOS (`AwradDomain`) and the server (`Awrad.Goals.Rules`) all pass them.
  - Invalid goals can't be constructed on any platform. The error codes are `target_required`, `session_target_required` and `streak_threshold_value_required`.
  - Comparing the three implementations found unspecified choices. Each was settled as a new case (see the brief's reconciliation section).
  - Server `plug_crypto` moved to 2.2.1 (CVE-2026-105963).
- Evidence: `contracts/goal-model/v1/`, `docs/slices/01-domain-foundation.md`
- Commit: see git log

### 2026-10-26 — Slice 1b: Hijri calendar, yearly schedules, goal presets

- Area: Cross-project
- Change:
  - Hijri dates come from one shared Umm al-Qura table (`contracts/hijri-calendar/v1/`, 1400–1500 AH) plus the account's month-start corrections for moon sighting (at most 2 days from the table; every month 29 or 30 days). No platform uses a Hijri library for rules (root ADR-2026-10-26).
  - Each platform bundles the table and fails validation if its copy drifts: generated Kotlin (`verifyUmmAlQuraTable`), generated Swift (`scripts/validate`), a `priv/` copy compiled in (server ADR 0004).
  - New schedules `hijri_month_days` and `yearly` (Gregorian or Hijri), and the `hijri_month` period. Seasons are label-only presets (`contracts/goal-presets/v1/`), not a schedule kind.
  - 211 shared cases, passed by Android, iOS and the server.
  - CI now re-runs Android, iOS and the server when `contracts/goal-model/` or `contracts/hijri-calendar/` change.
- Evidence: `contracts/hijri-calendar/v1/`, `docs/slices/01b-domain-hijri.md`
- Commit: see git log

### 2026-10-26 — Slice 2a: accounts

- Area: Cross-project
- Change:
  - Email and password accounts on the server, Android, iOS and the web. Verification and password reset use 6-digit emailed codes, with no links. Mobile uses device sessions with rotating refresh tokens (refresh needs `Idempotency-Key`; sign-out takes the refresh token). The web uses a Phoenix cookie session plus CSRF. Reset revokes every session.
  - Shared input rules (`contracts/account-model/v1/`): email trimming, password length in code points after NFC, and code digits in any script.
  - Checked end to end on the emulator, the simulator and the browser in en and ar.
  - Two iOS bugs found and fixed: a main-actor colour-provider crash, and dropped keystrokes from async edits.
  - Arabic and Malayalam texts still need native review.
- Evidence: `docs/slices/02-accounts.md`, root ADR-2026-10-26 (accounts)
- Commit: see git log

### 2026-10-26 — Slice 2b: account settings

- Area: Cross-project
- Change:
  - One device list for phones and browsers. Any one can be revoked, or all others at once.
  - Changing the password signs the others out. The email changes by a code to the new address, with a notice to the old one.
  - Account deletion is immediate. Server data and every session are removed; device data stays.
  - The server now stores `Idempotency-Key` results per account, fixing a 2a cross-account replay bug.
  - Checked live with one account signed in on all three clients.
  - One iOS bug found and fixed: a leaving form's field wrote its old text back into the model.
- Evidence: `docs/slices/02-accounts.md` (Slice 2b), server ADR 0008
- Commit: see git log

### 2026-10-26 — Design system: colour tokens

- Area: Cross-project
- Change:
  - Colours come only from `contracts/design-tokens/v1/colors.json`: the design palette (`#23553C`, `#B7D6B6`, `#E8EDE9`, `#F9FBFA`, `#E3E5E3`, `#121412`, `#313B34`), white and black (also translucent), and one error red per theme.
  - `npm test` rejects off-palette values and checks 21 contrast pairs per theme.
  - Each app generates its colours and fails validation on drift. Android and the web also reject raw colours outside the generated files.
  - Dark accent text is `#B7D6B6`, because `#23553C` on dark is 2.2:1. Headings use `onSurface`. Light dividers are black at 10%. `scrim` is black at 40%.
- Evidence: `contracts/design-tokens/v1/README.md`
- Commit: see git log
