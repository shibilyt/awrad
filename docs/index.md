# Awrad documentation index

This is the navigation layer for repository knowledge. Keep the root [`AGENTS.md`](../AGENTS.md) small and stable; put durable detail in the documents below. Code, schemas, migrations, and tests remain authoritative when documentation drifts.

## Start here

| Need | Read |
|---|---|
| Orientation and ownership | [`STRUCTURE.md`](../STRUCTURE.md) |
| Cross-project API contracts | [`CONTRACTS.md`](../CONTRACTS.md) |
| Work loops | [`LOOPS.md`](../LOOPS.md) |
| Validation matrix | [`TESTING.md`](../TESTING.md) |
| Copy-ready commands | [`COMMANDS.md`](../COMMANDS.md) |
| Durable facts and gaps | [`MEMORY.md`](../MEMORY.md) |
| Decisions and compatibility choices | [`DECISIONS.md`](../DECISIONS.md) |
| Progress model v1 schemas and fixtures | [`contracts/progress-model/v1/`](../contracts/progress-model/v1/) |

## Project guides

### Android

- Agent rules: [`awrad-android/AGENTS.md`](../awrad-android/AGENTS.md)
- Current product intent: [`awrad-android/prd/README.md`](../awrad-android/prd/README.md)
- Design system: [`awrad-android/docs/design-system/README.md`](../awrad-android/docs/design-system/README.md)
- Domain decisions: [`awrad-android/docs/decisions/goal-schema.md`](../awrad-android/docs/decisions/goal-schema.md)
- Content/source notes: [`awrad-android/docs/dalail-al-khayrat-source-notes.md`](../awrad-android/docs/dalail-al-khayrat-source-notes.md)

### iOS

- Agent rules: [`awrad-ios/AGENTS.md`](../awrad-ios/AGENTS.md)
- Architecture: [`awrad-ios/awrad/docs/ios-architecture.md`](../awrad-ios/awrad/docs/ios-architecture.md)
- Network contract: `awrad-ios/awrad/awrad/Core/AuthService.swift`
- Local state: `awrad-ios/awrad/awrad/Core/AwradStore.swift`

### API

- Agent rules: [`awrad_api/AGENTS.md`](../awrad_api/AGENTS.md)
- Master map: [`awrad_api/memory/README.md`](../awrad_api/memory/README.md)
- Security baseline: [`awrad_api/memory/security.md`](../awrad_api/memory/security.md)
- Feature and pattern maps: [`awrad_api/memory/features/`](../awrad_api/memory/features/) and [`awrad_api/memory/patterns/`](../awrad_api/memory/patterns/)
- Router: `awrad_api/lib/awrad_api_web/router.ex`
- Persistence: `awrad_api/priv/repo/migrations/` and Ecto schemas under `awrad_api/lib/`

## Setup gaps to close incrementally

The current repo has a healthy code graph and documented command/test surfaces. The next harness capabilities should be added one at a time:

1. Add repo-local mechanical checks for the highest-value invariants, with remediation-oriented errors.
2. Add a repo-specific `verify` entry point that runs the smallest relevant checks from a changed-file scope.
3. Add CI wiring for those checks when a CI provider is selected for this umbrella repo.
4. Add documentation freshness checks only after the source-of-truth boundaries are stable.

Do not create placeholder lints or a broad verifier until each rule has a clear owner, command, and expected failure behavior.
