# Work loops

Default execution patterns for the rebuild. Skip a step only when it clearly doesn't apply, and explain material omissions in the handoff.

## 1. Orientation

1. Run `git status --short` at the root and note changes you didn't make.
2. Read the root and nearest scoped `AGENTS.md`, plus the project's `ARCHITECTURE.md` and `docs/adr/` when they exist.
3. Classify the task: contract, one `-next` project, a whole slice, docs, or research on a frozen app.
4. Use graft for definitions, callers and routes; use `rg` for literals, resources and config.
5. Check [`docs/rebuild-plan.md`](docs/rebuild-plan.md) for where the task sits, and [`DECISIONS.md`](DECISIONS.md) for constraints.
6. State the intended behaviour and the focused check before editing.

Exit condition: the owning project, the affected contracts and consumers, and the focused check are known.

## 2. Slice delivery

A slice is one capability (for example accounts or goals) delivered end to end. Each step builds on the one before it.

1. **Study:** run loop 3 on the frozen apps for this capability, and record keep / change / drop decisions.
2. **Domain:** update `CONTEXT.md` terms; add or extend behaviour fixtures in `contracts/` for every rule.
3. **Contract:** update the API spec and schemas in `contracts/` (loop 4).
4. **Server:** implement against the spec; contract tests and fixture tests pass.
5. **Android, then iOS:** domain rules pass the shared fixtures; data adapters match the spec; screens follow the project's UI pattern.
6. **Web:** generated client from the spec; online-only screens.
7. **Close:** tick the slice in the rebuild plan, add a `MEMORY.md` log entry, and record any decisions as ADRs.

Exit condition: every project in the slice passes its validation command and the shared fixtures, and the contract describes exactly what was built.

## 3. Study a frozen app (behaviour research)

1. Find the behaviour in the frozen code and its tests: start from [`docs/reference/`](docs/reference/) and graft.
2. Compare platforms by semantics, not class names: defaults, validation, day boundary, recurrence, count caps, reminders, lifecycle, localization.
3. Write down the rule in domain language, citing the old code and tests as evidence.
4. Decide keep, change or drop. "Change" and "drop" need a reason in the slice notes or an ADR.
5. Never edit the frozen project, even to fix a bug you found; carry the fix into the new implementation.

Exit condition: each behaviour in scope has a written rule, evidence and a decision.

## 4. Contract change

1. Read the current spec, schemas and fixtures in `contracts/`, and every consumer that exists.
2. Write down method, path, auth scheme (cookie or bearer), request and response JSON, errors, and idempotency behaviour.
3. Update the spec or schema and its fixtures first; validators must pass.
4. Implement the server, then each existing client. Generated clients are regenerated, not hand-edited.
5. Once a slice has shipped across all projects, its contract binds every consumer: changes must be additive, or coordinated with a decision record.

Exit condition: spec, fixtures, server and every affected client agree, and the validators pass.

## 5. Focused implementation (one project)

1. Reuse the project's existing patterns and modules; don't add abstractions the project's architecture doc doesn't call for.
2. Make the smallest coherent change, with no drive-by refactors.
3. Add or update a focused test next to the behaviour; domain rules also get fixture cases.
4. Run the focused check, then the project's validation command from [`TESTING.md`](TESTING.md).
5. Inspect the diff for generated files or unrelated churn.

Exit condition: the behaviour works, the build-enforced standards pass, and the diff is explainable.

## 6. Persisted-schema change

Nothing is released, so the policy is set per project:

- **Android Room:** stays at version 1 until the first release. Edit version 1 and re-export the schema; no migrations (Android ADR 0003).
- **Server Ecto:** timestamped migrations as usual (`mix ecto.gen.migration`). They're cheap and keep dev databases reproducible. Never expose schema fields as API contract by accident.
- **iOS SwiftData:** decided by the iOS scaffold ADR. Until then, ask before choosing.

Exit condition: the schema change and its exported or migrated form are committed together.

## 7. Localization or bundled content

1. Add semantic keys in every locale (en, ar, ml) together; never embed display text in code.
2. Preserve placeholders, plural handling and RTL layout.
3. Built-in dhikr and wird content comes from `contracts/`, keeping stable catalog keys and UUIDs (ADR-2026-07-13).
4. Validate resource compilation and compare key sets across locales.

Exit condition: resources compile, keys and placeholders align, and content identity is unchanged.

## 8. Notifications, audio, widgets, background work

1. Keep timing and policy logic pure and testable, separate from platform effects.
2. Test policy without sleeps; reserve device or simulator runs for the platform boundary.
3. Check relaunch or reboot, cancellation, stale work, missing permission and offline behaviour.

Exit condition: deterministic logic is covered, and the platform boundary has appropriate smoke evidence.

## 9. Verification and handoff

1. Run the narrowest relevant checks, then broaden based on risk.
2. Run `git diff --check`, and inspect `git status --short` and `git diff --stat`.
3. Make sure no secrets, machine paths, generated builds or unrelated changes are in the diff.
4. Update `contracts/`, `MEMORY.md`, the rebuild plan or ADRs only where the change made them stale.
5. Report the outcome first, then changed areas, verification, and any checks you couldn't run.
6. Don't commit, push, deploy or publish unless asked.

Exit condition: another engineer or agent can continue without reconstructing hidden context.
