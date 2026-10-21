# Slice NN: <name>

Status: Draft | Agreed | In progress | Done
Plan entry: [`docs/rebuild-plan.md`](../rebuild-plan.md), slice NN
Playbook: [`docs/slice-playbook.md`](../slice-playbook.md)

## Goal

One or two sentences: what a user can do after this slice that they couldn't before.

## Scope

| In scope | Out of scope (and where it goes instead) |
|---|---|
| … | … |

Platforms: server ☐ · Android ☐ · iOS ☐ · web ☐ (say why if a platform is excluded)

## Open questions

Questions for the user, answered before step 3.

1. …

## Behaviour inventory (step 2)

Each behaviour of the frozen apps in scope: what it does today, the decision, and the evidence.

| Behaviour | Today (frozen apps) | Decision | Evidence |
|---|---|---|---|
| … | … | keep / change: … / drop: … | `awrad-android/…:L12`, `awrad-ios/…`, `docs/reference/android-spec/…` |

## Domain and fixtures (step 3)

- New or changed terms in `CONTEXT.md`: …
- Fixture files (one per rule): `contracts/<model>/v<N>/fixtures/<rule>.json`: …

## Contract (step 4)

- Operations added or changed: `<operation_id>` `<METHOD> /api/v1/...`
- Schemas: …
- ADRs: …

## Platform work (step 5)

| Project | Work | Validation | Status |
|---|---|---|---|
| awrad-server-next | … | `mix validate` | ☐ |
| awrad-android-next | … | Gradle validation | ☐ |
| awrad-ios-next | … | `scripts/validate` | ☐ |
| awrad-web-next | … | `npm run validate` | ☐ |

## Integration evidence (step 6)

| Flow | Android | iOS | Web | Notes |
|---|---|---|---|---|
| … (en) | ☐ | ☐ | ☐ | |
| … (ar, RTL) | ☐ | ☐ | ☐ | |

## Definition of done

Copy the checklist from the playbook and tick it here before closing.
