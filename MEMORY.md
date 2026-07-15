# Repository memory

This file stores durable repository facts and a concise append-only change log. It is not a transcript, task list, or substitute for code and tests.

## Durable facts

- The repository contains three independently buildable projects: `awrad-android`, `awrad-ios`, and `awrad_api`.
- Git operations run at the umbrella root; Gradle, Xcode, and Mix commands run inside their project roots.
- Both mobile apps are designed to remain useful without a network connection.
- The Phoenix API currently owns accounts, browser session authentication, and mobile JSON authentication.
- Android persists app data with Room. Exported Room schemas are committed migration evidence.
- iOS exposes app state through `AwradStore`, persists the product graph in an App Group SwiftData repository, and shares a compact projection plus relational mutations with its widget extension. Snapshot v5 is migration/backup input.
- The API persists server data with Ecto/PostgreSQL and uses timestamped migrations.
- User-facing content is localized in English, Arabic, and Malayalam where platform resources exist.
- Android and iOS retain native implementations. Android commit `2f56aa4` is the frozen behavior baseline for the current iOS parity release; later Android changes require a separately reviewed delta.

## Implemented cross-project capabilities

- Mobile registration is verification-first and creates a revocable device session only after email verification.
- API access JWTs are bound to active device sessions; refresh rotation is transactional and detects replay.
- API JSON and browser registration, password-login, magic-link, and password-reset routes have explicit repository-owned IP/account abuse limits; browser registration returns a generic response for existing and unused emails.
- Forgot-password requests are implemented for both mobile clients and the API.
- Authenticated logout is implemented by the API and both mobile clients.
- Android credentials use an Android Keystore-backed AES-GCM store and refresh is serialized across concurrent failures.
- Android debug builds default to the emulator host API address; release builds require an explicit HTTPS API URL.
- iOS `AuthService` defaults to a loopback development API URL and supports dependency injection of another base URL.
- iOS credentials are stored in Keychain, and protected requests use single-flight refresh-and-retry while local devotional workflows remain available offline.

## Known gaps and cautions

- General cloud synchronization for goals, counts, dhikrs, and wirds is planned, not an implemented repository-wide contract.
- API dhikr/tracking schemas should not be described as a complete sync surface until routes, ownership rules, revision semantics, and mobile consumers exist.
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
- Evidence: `awrad_api/memory/security.md`, `awrad_api/lib/awrad_api_web/browser_auth_protection.ex`, browser-auth controller tests, `TESTING.md`
- Commit: uncommitted

### 2026-07-15 — Implemented the iOS Android-parity architecture

- Area: iOS | Cross-project | Documentation
- Change: Froze Android `2f56aa4` as the iOS behavior baseline; added the App Group SwiftData repository/migration boundary, canonical progress/behavior/Wird contracts, Android-equivalent iOS route families, Keychain authentication with single-flight refresh, and an explicit runtime/physical-device acceptance ledger.
- Evidence: `awrad-ios/awrad/awrad/Core/Persistence/`, `awrad-ios/awrad/awrad/Core/AwradStore.swift`, `awrad-ios/awrad/awrad/Features/`, `contracts/behavior-model/v1/`, `contracts/wird-model/v1/`, `docs/ios-android-parity-ledger.md`, `docs/ios-parity-debugger-review.md`
- Commit: uncommitted
