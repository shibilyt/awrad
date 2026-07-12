# Work loops

These loops are default execution patterns. Skip a step only when it is clearly irrelevant, and explain material omissions in the handoff.

## 1. Orientation and discovery

1. Run `git status --short` at the root; identify user-owned changes.
2. Read root and nearest scoped `AGENTS.md` files.
3. Classify the task as Android, iOS, API, documentation, or cross-project.
4. Use the codebase graph to find definitions, routes, callers, and entry points. Use `rg` for literals, resources, and configuration.
5. Read the smallest set of owning files and focused tests.
6. Check [`CONTRACTS.md`](CONTRACTS.md) for a cross-project seam.
7. State the intended behavior and narrow validation before editing.

Exit condition: the owner, affected consumers, source of truth, and focused check are known.

## 2. Focused implementation

1. Reuse the current abstraction: repository/store, context, DTO, component, route group, or service.
2. Make the smallest coherent change; avoid drive-by refactors.
3. Add or update a focused test near the behavior.
4. Run the focused check immediately.
5. Inspect the diff for accidental generated files or unrelated churn.
6. Escalate validation according to [`TESTING.md`](TESTING.md).
7. Update current documentation only when a durable interface or fact changed.

Exit condition: requested behavior works, focused evidence passes, and the diff is explainable.

## 3. API contract change

1. Read the live Phoenix router/controller and both mobile client contracts.
2. Write down current and desired method, path, auth requirement, request JSON, response JSON, errors, and compatibility behavior.
3. Decide whether the change is additive, backward compatible, or coordinated/breaking. Do not leave this implicit.
4. Implement server behavior and controller/plug tests.
5. Update Android Retrofit DTOs, storage/retry behavior, and tests when affected.
6. Update iOS Codable DTOs, storage/retry behavior, and tests when affected.
7. Run focused server and client checks; perform local integration when feasible.
8. Update [`CONTRACTS.md`](CONTRACTS.md), [`MEMORY.md`](MEMORY.md), and a root decision when compatibility or ownership changed.

Exit condition: server and all affected consumers agree on the wire contract, with rollout behavior documented.

## 4. Android/iOS parity change

1. Trace the current behavior on each platform from UI through domain/persistence.
2. Compare semantics, not class names: defaults, validation, day boundary, recurrence, count cap, reminders, lifecycle, and localization.
3. Identify the intended shared rule and any deliberate platform difference.
4. Change each platform through its native architecture rather than copying implementation structure.
5. Add equivalent behavior-level tests on both platforms.
6. Run focused checks independently.
7. Record intentional differences and remaining gaps.

Exit condition: equivalent user-visible behavior is proven or the difference is explicit.

## 5. Database or persisted-schema change

### Android Room

1. Update entities/DAOs and increment the database version.
2. Add a forward migration; never rewrite an applied migration to hide a change.
3. Export and commit the new Room schema JSON.
4. Add migration and repository behavior tests.
5. Verify upgrade behavior as well as clean creation.

### API Ecto

1. Generate a timestamped migration with `mix ecto.gen.migration`.
2. Update schemas, changesets, contexts, and ownership scoping.
3. Add context/controller tests as appropriate.
4. Verify migration on an existing database and clean test database.
5. Do not expose new schema fields as API contracts accidentally.

### iOS snapshots

1. Identify the persisted Codable shape and widget/shared copies.
2. Choose explicit backward-compatible decoding, schema migration, or intentional reset behavior.
3. Update app and widget readers/writers together.
4. Add old-snapshot decoding and round-trip tests.

Exit condition: existing user data has a tested path to the new representation.

## 6. Localization or bundled-content change

1. Identify every affected locale and platform resource owner.
2. Add semantic keys rather than embedding display text in code.
3. Preserve placeholders, plural/count behavior, Unicode, and RTL layout assumptions.
4. For bundled dhikr/wird content, preserve stable logical IDs and source/version metadata.
5. Validate parsing/resource compilation and compare locale key sets.
6. Smoke-test Arabic directionality and any affected dynamic formatting when UI changed.

Exit condition: resources compile, keys and placeholders align, and content remains addressable across upgrades.

## 7. Notification, audio, widget, or background change

1. Trace lifecycle entry points, permissions, persisted state, and rescheduling/recovery paths.
2. Keep pure timing/policy calculations separate from platform effects where possible.
3. Test policy logic without sleeps; use platform integration only for the final boundary.
4. Check reboot/relaunch, cancellation, stale work, missing permission, and offline behavior.
5. For widget changes, update app and extension shared contracts together.

Exit condition: deterministic logic is covered and the platform boundary has appropriate smoke evidence.

## 8. Verification and handoff

1. Run the narrowest relevant tests, then broaden based on risk.
2. Run `git diff --check` and inspect `git status --short` and `git diff --stat`.
3. Verify no secrets, machine paths, generated builds, or unrelated changes entered the diff.
4. Update contract, memory, or decision docs only where the change made them stale.
5. Report the outcome first, then changed areas, verification, and any unrun environment-bound checks.
6. Do not commit, push, deploy, migrate shared environments, or publish unless explicitly requested.

Exit condition: another engineer or agent can continue without reconstructing hidden context.
