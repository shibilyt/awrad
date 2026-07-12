# Repository memory

This file stores durable repository facts and a concise append-only change log. It is not a transcript, task list, or substitute for code and tests.

## Durable facts

- The repository contains three independently buildable projects: `awrad-android`, `awrad-ios`, and `awrad_api`.
- Git operations run at the umbrella root; Gradle, Xcode, and Mix commands run inside their project roots.
- Both mobile apps are designed to remain useful without a network connection.
- The Phoenix API currently owns accounts, browser session authentication, and mobile JSON authentication.
- Android persists app data with Room. Exported Room schemas are committed migration evidence.
- iOS persists app state through `AwradStore` and shares selected state/mutations with its widget extension.
- The API persists server data with Ecto/PostgreSQL and uses timestamped migrations.
- User-facing content is localized in English, Arabic, and Malayalam where platform resources exist.
- Android and iOS implement similar product concepts independently; neither platform's model is automatically authoritative for the other.

## Implemented cross-project capabilities

- API registration and login return mobile token data.
- API access uses bearer JWTs; refresh tokens are database-backed and rotated.
- Forgot-password requests are implemented for both mobile clients and the API.
- Authenticated logout is implemented by the API and both mobile clients.
- Android debug builds default to the emulator host API address; release builds require an explicit HTTPS API URL.
- iOS `AuthService` defaults to a loopback development API URL and supports dependency injection of another base URL.

## Known gaps and cautions

- General cloud synchronization for goals, counts, dhikrs, and wirds is planned, not an implemented repository-wide contract.
- API dhikr/tracking schemas should not be described as a complete sync surface until routes, ownership rules, revision semantics, and mobile consumers exist.
- The iOS client stores auth tokens in `UserDefaults`; treat security-storage changes as a deliberate migration, not a documentation-only cleanup.
- Some API memory documents and Android plans are historical snapshots. Verify current routes and behavior in code before relying on them.
- Full API tests require PostgreSQL. Android instrumentation requires an emulator/device. iOS UI/runtime validation requires an available simulator.

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
