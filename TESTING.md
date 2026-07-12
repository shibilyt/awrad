# Testing and validation

Validate the smallest relevant surface first, then widen checks according to risk. Environment-bound checks should be reported as not run, with the missing prerequisite named.

## Change-to-validation matrix

| Change | Minimum focused validation | Broader validation when warranted |
|---|---|---|
| Android pure model/calculator | Matching JVM test class | `:app:testDebugUnitTest` |
| Android repository/Room | Repository JVM tests plus schema/migration tests | Unit suite and relevant instrumentation tests |
| Android Compose/navigation | Compile plus focused UI/state tests | Debug build and emulator smoke flow |
| Android notification/audio/service | Focused policy tests and debug build | Device/emulator flow and log review |
| Android resources/localization | Resource build and locale-key comparison | Runtime smoke in affected locales |
| iOS pure domain/store | Matching XCTest method or class | Main XCTest target |
| iOS SwiftUI/navigation/deep link | Build-for-testing plus focused XCTest | Simulator smoke or UI test |
| iOS widget/shared mutation | Widget/shared focused XCTest | App-widget simulator integration |
| iOS localization/resources | Build plus locale-key comparison | Runtime smoke in affected locales |
| API context/schema | Focused context test and migration review | Full `mix test` |
| API controller/router/auth | Focused controller/plug tests | Full `mix test` and mobile consumer review |
| Cross-project JSON contract | API tests plus Android and iOS DTO review/tests | Local API integration on both clients |
| Documentation only | Link/path audit and `git diff --check` | Verify documented task discovery commands |

## Android escalation

1. Run the narrow test class with `--tests` when available.
2. Run `./gradlew :app:testDebugUnitTest`.
3. Run `:app:assembleDebug` or `:app:lintDebug` for resource, manifest, or packaging changes.
4. Run `:app:connectedDebugAndroidTest` only when an emulator/device is available and the change needs instrumentation.

Room changes must include a new migration, updated exported schema, migration coverage, and an upgrade-path check. Do not validate only fresh installation.

## iOS escalation

1. Build for testing with the generic simulator destination.
2. Run one XCTest method or the relevant test target on an available simulator.
3. Run the broader XCTest suite when shared domain/store behavior changes.
4. Use simulator smoke checks for navigation, deep links, widgets, notifications, locale direction, or system integrations.

Do not hard-code an old simulator UUID in repository guidance. Discover available destinations for the current machine.

## API escalation

1. Run the focused test file or line.
2. Run `mix test` with PostgreSQL available.
3. Run `mix precommit` before a release-quality handoff; note that it formats files.
4. For migrations, verify both an existing database upgrade and a clean test database.

Router/auth changes require explicit checks for public versus protected pipeline placement, success JSON, validation/error JSON, invalid/expired credentials, and token revocation/rotation behavior.

## Cross-project acceptance

For a changed contract, record all of the following in the handoff:

- server route/controller and tests;
- Android request/response and storage/retry behavior;
- iOS request/response and storage/retry behavior;
- compatibility or rollout strategy for older clients;
- integration checks actually run.

## Diff hygiene

Before handoff:

```bash
git status --short
git diff --check
git diff --stat
```

Inspect the diff for generated builds, IDE state, local paths, secrets, screenshots/logs that were not requested, stale docs, accidental formatting churn, and unrelated user changes.
