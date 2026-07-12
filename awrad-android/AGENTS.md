# Android agent instructions

These instructions apply inside `awrad-android/` and extend the repository-wide rules in [`../AGENTS.md`](../AGENTS.md).

## Architecture

- The project has one Gradle application module, `:app`, using Kotlin, Jetpack Compose, Hilt, Room, Retrofit/OkHttp, WorkManager, and Media3.
- UI screens live under `ui/screens/`; route ownership lives in `ui/navigation/`.
- Domain construction and update rules live under `domain/`; persistence behavior belongs in repositories and Room DAOs, not composables.
- `AwradDatabase` is the Room boundary. Exported schemas under `app/schemas/` are committed evidence, not disposable output.
- Network auth lives under `data/network/`, `data/preferences/`, and `data/repository/AuthRepository.kt`.
- Notifications, alarms, workers, counting service, and audio are lifecycle-sensitive boundaries. Keep their scheduling/policy logic testable outside Android effects.

## Working rules

- Prefer state hoisting and existing ViewModels/repositories. Do not put database, network, or scheduling work directly in composables.
- Use Hilt bindings already present under `di/`; avoid service locators or manually constructed production graphs.
- Keep app behavior local-first. Auth can use the API, but counting, goals, dhikrs, and wird reading must not acquire an incidental network requirement.
- Preserve stable IDs for built-in content and relationships. Review goal/count/wird migrations when changing ID semantics.
- Treat `prd/` as product intent and accepted decisions, but verify implementation truth in code and tests.
- Treat `docs/superpowers/plans/` as historical implementation plans. Paths and intermediate designs there may be stale.

## Room and data changes

- Increment the Room database version for a persisted schema change.
- Add a forward migration in the migration registry; never rewrite an already shipped migration.
- Export and commit the new schema JSON in `app/schemas/`.
- Add migration coverage and verify upgrade behavior, not only fresh database creation.
- Keep multi-table goal updates transactional. Do not rewrite count history as a side effect of editing goal configuration unless explicitly required.

## Compose and resources

- Reuse the design system and shared components under `ui/theme/` and `ui/components/`.
- Put user-facing text in `res/values/strings.xml` and corresponding `values-ar`/`values-ml` resources.
- Preserve placeholders and verify RTL behavior for Arabic when layout or dynamic text changes.
- Use navigation helpers and defined destinations; avoid ad hoc route strings in feature code.

## Notifications, audio, and background work

- Check permission, reboot/reschedule, cancellation, stale work, and exact-alarm/battery behavior when touching reminders.
- Prefer WorkManager for deferrable work and existing alarm/receiver seams for exact occurrences.
- Validate downloaded audio metadata and safe storage paths; keep logical content state separate from cache/download state.
- Never use blocking sleeps in tests to wait for background behavior.

## Validation

Run from `awrad-android/`:

```bash
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
./gradlew :app:lintDebug
```

Use `--tests 'fully.qualified.TestClass'` for focused JVM checks. Run `:app:connectedDebugAndroidTest` only with an available emulator/device and when instrumentation is relevant. See [`../TESTING.md`](../TESTING.md).

<!-- opensrc:start -->

## Source Code Reference

Source code for dependencies is available in `opensrc/` for deeper understanding of implementation details.

See `opensrc/sources.json` for the list of available packages and their versions.

Use this source code when you need to understand how a package works internally, not just its types/interface.

### Fetching Additional Source Code

To fetch source code for a package or repository you need to understand, run:

```bash
npx opensrc <package>           # npm package (e.g., npx opensrc zod)
npx opensrc pypi:<package>      # Python package (e.g., npx opensrc pypi:requests)
npx opensrc crates:<package>    # Rust crate (e.g., npx opensrc crates:serde)
npx opensrc <owner>/<repo>      # GitHub repo (e.g., npx opensrc vercel/ai)
```

<!-- opensrc:end -->
