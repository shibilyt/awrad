# Slice playbook

How a slice gets built, from the first question to merged on `main`. A slice is one capability (accounts, goals, counting…) delivered across `contracts/`, the server, Android, iOS and the web (root ADR-2026-10-14). Slices are listed in [`rebuild-plan.md`](rebuild-plan.md).

This expands loop 2 in [`LOOPS.md`](../LOOPS.md). Use the brief template at [`slices/_template.md`](slices/_template.md).

## The sequence

```text
1 Brief ─► 2 Study ─► 3 Domain + fixtures ─► 4 Contract ─┬─► 5a Server
                                                         ├─► 5b Android ─┐
                                                         ├─► 5c iOS      ├─► 6 Integrate ─► 7 Close
                                                         └─► 5d Web ─────┘
```

Steps 1–4 happen once, in order: they define what every platform builds. Step 5 can run **in parallel**, one agent per project, each in its own branch or worktree, because the contract and fixtures from step 4 are already on `main`.

| Step | Output | Done when |
|---|---|---|
| **1. Brief** | `docs/slices/NN-name.md` from the template: goal, in scope, out of scope, open questions | The user has agreed the scope and answered the open questions |
| **2. Study** | Behaviour inventory in the brief: each behaviour of the frozen apps marked keep, change or drop, with evidence (file:line in frozen code and tests, or `docs/reference/android-spec/`) | Every behaviour in scope has a decision; changes and drops have a reason |
| **3. Domain + fixtures** | New terms in `CONTEXT.md`; one `awrad-fixture/1` file per rule in `contracts/<model>/v<N>/fixtures/` | `npm test` in `contracts/` passes; each rule's cases cover its boundaries |
| **4. Contract** | Operations in `contracts/api/paths/*.yaml` and schemas, bundled; ADRs for any decision the style guide doesn't already make | `npm run bundle && npm test` passes; the user has reviewed the API shape |
| **5a. Server** | Contexts and schemas behind Boundary; controllers using `AwradWeb.Problem`; a migration | `mix validate` passes; every operation has `assert_conforms` tests for success and each documented error; fixtures run in ExUnit where the server implements the rule |
| **5b. Android** | Domain rules in `:core:domain`, adapters in `:core:data`, a `:feature:<name>` module | Gradle validation passes; the fixture runner passes for every rule implemented; spec-example round-trip tests for the network classes |
| **5c. iOS** | The same in `AwradKit` | `scripts/validate` passes; fixture runner; spec-example round-trip tests |
| **5d. Web** | `src/features/<name>`, hooks on `api`, routes | `npm run validate` passes; spec-example mocks for every state shown |
| **6. Integrate** | Real runs against `mix phx.server`: Android emulator, iOS simulator, web browser | The slice's main flows work end to end in en and ar (RTL) on each platform; screenshots or notes in the brief |
| **7. Close** | Brief marked done; rebuild plan ticked; `MEMORY.md` log entry | `ci_ok` green on `main` |

## Definition of done

A slice is done only when **all** of these hold:

- [ ] The brief's in-scope items are built on every platform the slice covers, or the brief records why one is excluded.
- [ ] Every shared domain rule has fixture cases, and every implementing platform runs them.
- [ ] Every operation in the slice has spec examples, server `assert_conforms` tests and client round-trip tests or mocks.
- [ ] Each project's validation command passes locally, and `ci_ok` is green.
- [ ] Main flows have been checked on a running build in English and Arabic (RTL), with evidence in the brief.
- [ ] On mobile, the slice's core flows work signed out with the network off, with no sign-in gate and no API calls (ADR-2026-10-28, complete without an account).
- [ ] All user-facing text is in localization resources with en, ar and ml, and the translation checks pass.
- [ ] Decisions taken along the way are ADRs (root or project), and none contradicts an accepted ADR without superseding it.
- [ ] Docs that the slice made stale are updated: `CONTEXT.md`, `STRUCTURE.md`, project `ARCHITECTURE.md`, `COMMANDS.md`.
- [ ] Nothing was changed in the frozen projects.

## Working with agents

- **One agent per project in step 5**, briefed with the slice brief, the contract diff and the project's `AGENTS.md`. Each works in its own branch or worktree, and merges only with its project's validation passing.
- **Contract changes found during step 5 go back to step 4**: change the spec or fixtures first, then every affected platform. Never patch one client around the contract.
- **Use graft scoped to the project being built** (`graft ask "<question>" --in awrad-<x>-next/`). Hits labelled with a frozen project (`[awrad-android/]`, `[awrad-ios/]`, `[awrad_server/]`) are evidence of current behaviour, not code to copy or edit.
- **The user approves:** the slice scope (step 1), the API shape (step 4), anything that changes product behaviour from the frozen apps, and every push.

## Size

Aim for slices that finish in days, not weeks. If a brief's inventory grows past what one pass across five projects can deliver, split it: for example, "goals: create and view" before "goals: edit and archive".
