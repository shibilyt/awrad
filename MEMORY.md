# Repository memory

This file stores durable repository facts and a concise append-only change log. It is not a transcript, task list, or substitute for code and tests.

## Durable facts

- Awrad isn't released: no installed users, so there's no upgrade or data-migration compatibility to keep.
- Awrad is being rebuilt as four contract-first projects: `awrad-server-next`, `awrad-android-next`, `awrad-ios-next` and `awrad-web-next` (ADR-2026-10-14). Only `awrad-android-next` exists, as a scaffold.
- `contracts/` is the shared source of truth: schemas, behaviour fixtures and built-in content, with an OpenAPI spec planned.
- Git runs at the root; each project's toolchain runs inside its own directory.
- Mobile apps are offline-first for dhikr, goals, counting and wird. The web app is online-only.
- Browsers authenticate with Phoenix cookie sessions plus CSRF; mobile with bearer tokens bound to device sessions (ADR-2026-10-15, ADR-2026-07-12).
- `awrad-android-next` keeps Room at version 1 until the first release (its ADR 0003).
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
