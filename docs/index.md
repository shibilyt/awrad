# Awrad documentation index

The navigation layer for repository knowledge. Keep the root [`AGENTS.md`](../AGENTS.md) small and stable, and put durable detail in the documents below. Code, schemas, fixtures, migrations and tests stay authoritative when docs drift.

## Start here

| Need | Read |
|---|---|
| What's being built, in what order | [`rebuild-plan.md`](rebuild-plan.md) |
| Orientation and ownership | [`STRUCTURE.md`](../STRUCTURE.md) |
| Cross-project decisions | [`DECISIONS.md`](../DECISIONS.md) |
| Domain language | [`CONTEXT.md`](../CONTEXT.md) |
| Product intent and design principles | [`PRODUCT.md`](../PRODUCT.md) |
| Work loops | [`LOOPS.md`](../LOOPS.md) |
| Validation matrix | [`TESTING.md`](../TESTING.md) |
| Copy-ready commands | [`COMMANDS.md`](../COMMANDS.md) |
| Durable facts and change log | [`MEMORY.md`](../MEMORY.md) |

## Shared contracts

| Contract | Location |
|---|---|
| Progress model v1: schemas, fixtures, built-in catalogs | [`contracts/progress-model/v1/`](../contracts/progress-model/v1/) |
| Progress sync v1: wire protocol and reducer scenarios | [`contracts/progress-sync/v1/`](../contracts/progress-sync/v1/) |
| Behaviour model v1: shared behaviour cases | [`contracts/behavior-model/v1/`](../contracts/behavior-model/v1/) |
| Wird model v1: bundled wird and generated identities | [`contracts/wird-model/v1/`](../contracts/wird-model/v1/) |
| API style guide | [`contracts/api/STYLE.md`](../contracts/api/STYLE.md) |
| API spec (OpenAPI) | Planned under `contracts/api/` (rebuild plan 0.4) |
| Current API wire contract, in prose (frozen server) | [`CONTRACTS.md`](../CONTRACTS.md). Replaced by `contracts/` slice by slice |

## New projects

### awrad-android-next
- Agent rules: [`awrad-android-next/AGENTS.md`](../awrad-android-next/AGENTS.md)
- Architecture: [`awrad-android-next/ARCHITECTURE.md`](../awrad-android-next/ARCHITECTURE.md)
- Decisions: [`awrad-android-next/docs/adr/`](../awrad-android-next/docs/adr/README.md)

### awrad-server-next, awrad-ios-next, awrad-web-next
Not created yet. See their sections in [`STRUCTURE.md`](../STRUCTURE.md) for the decided stacks.

## Reference: current behaviour of the frozen apps

Use these to learn what the old apps do before re-implementing a behaviour. Don't change the frozen projects.

| Topic | Read |
|---|---|
| Reverse-engineered Android spec: PRD, technical requirements, flows, design tokens, mockups | [`reference/android-spec/README.md`](reference/android-spec/README.md) |
| Legacy structure, commands, test matrix | [`reference/legacy-structure.md`](reference/legacy-structure.md), [`reference/legacy-commands.md`](reference/legacy-commands.md), [`reference/legacy-testing.md`](reference/legacy-testing.md) |
| Offline progress sync architecture | [`progress-sync-architecture.md`](progress-sync-architecture.md) |
| Cross-platform urgency notification engine | [`notification-obligation-engine.md`](notification-obligation-engine.md) |
| iOS–Android parity delivery ledger | [`ios-android-parity-ledger.md`](ios-android-parity-ledger.md) |
| iOS parity runtime/debugger review | [`ios-parity-debugger-review.md`](ios-parity-debugger-review.md) |

### Android (frozen)
- App map: [`awrad-android-map.md`](awrad-android-map.md)
- Agent rules: [`awrad-android/AGENTS.md`](../awrad-android/AGENTS.md)
- Product intent: [`awrad-android/prd/README.md`](../awrad-android/prd/README.md)
- Design system: [`awrad-android/docs/design-system/README.md`](../awrad-android/docs/design-system/README.md)
- Domain decisions: [`awrad-android/docs/decisions/goal-schema.md`](../awrad-android/docs/decisions/goal-schema.md)
- Content/source notes: [`awrad-android/docs/dalail-al-khayrat-source-notes.md`](../awrad-android/docs/dalail-al-khayrat-source-notes.md)

### iOS (frozen)
- Agent rules: [`awrad-ios/AGENTS.md`](../awrad-ios/AGENTS.md)
- Architecture: [`awrad-ios/awrad/docs/ios-architecture.md`](../awrad-ios/awrad/docs/ios-architecture.md)
- Network contract: `awrad-ios/awrad/awrad/Core/AuthService.swift`
- Local state: `awrad-ios/awrad/awrad/Core/AwradStore.swift`

### Phoenix server (frozen)
- Agent rules: [`awrad_server/AGENTS.md`](../awrad_server/AGENTS.md)
- Master map: [`awrad_server/memory/README.md`](../awrad_server/memory/README.md)
- Security baseline (to carry into `awrad-server-next`): [`awrad_server/memory/security.md`](../awrad_server/memory/security.md)
- Feature and pattern maps: [`awrad_server/memory/features/`](../awrad_server/memory/features/) and [`awrad_server/memory/patterns/`](../awrad_server/memory/patterns/)
- Router: `awrad_server/lib/awrad_server_web/router.ex`
