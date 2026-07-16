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
| Cross-project progress contract | `./check-mobile-model-parity` plus focused API context tests | Full native/API suites and migration checks |
| Progress sync protocol/reducer | `python3 scripts/validate_progress_sync.py` | Root parity plus Phoenix sync context tests |
| Cross-platform behavior fixture | `python3 scripts/validate_behavior_fixtures.py` plus the matching Android/iOS behavior test | `./check-mobile-model-parity` and the affected native suites |
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

For the iOS parity release, record runtime evidence in [`docs/ios-parity-debugger-review.md`](docs/ios-parity-debugger-review.md). Source inspection or a unit test does not substitute for visual/lifecycle evidence. The runtime record must name the simulator/device, OS version, build, launch state, action, and observed result. Notification delivery, audio interruptions/routes, signed App Group widget/App Intent mutation, Live Activity lifecycle, real location accuracy, and keep-awake/haptics require physical-device evidence.

## API escalation

1. Run the focused test file or line.
2. Run `mix test` with PostgreSQL available.
3. Run `mix precommit` before a release-quality handoff; note that it formats files.
4. For migrations, verify both an existing database upgrade and a clean test database.

Router/auth changes require explicit checks for public versus protected pipeline placement, success JSON, validation/error JSON, invalid/expired credentials, and token revocation/rotation behavior.

Security-sensitive API changes also require focused checks for generic account responses, per-IP and per-account rate-limit thresholds, replay/concurrency behavior, ownership swaps using another user's valid ID, cookie/CSRF behavior, and absence of secrets in responses or logs. Run `mix hex.audit` during release preparation and dependency changes; treat external WAF or mail-provider quotas as defense in depth rather than test substitutes.

## Cross-project acceptance

For progress model v1, behavior model v1, and bundled Wird model v1, the root parity command must pass. It validates the dependency-free progress schemas and golden fixtures, exact 113-entry registry parity across Android/iOS/API, generated 100-entry Asma-ul Husna invocation content, enum/default/edge-case coverage, exact persisted-field classification against Room schema, Swift models, and Ecto schemas, the shared behavior-case families, and the canonical eight-part Wird content/hash/identity/cadence fixtures. It then runs the focused Android and iOS native suites. API schema/context tests remain separate because these contracts deliberately expose no sync route.

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
