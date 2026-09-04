# Commands

Run each command from the working directory shown. Start with focused checks; use full suites when risk justifies them.

## Repository root

Working directory: repository root

```bash
git status --short
git diff --check
git diff --stat

# Regenerate native/API Asma-ul Husna seeds after editing the canonical JSON.
./scripts/generate_asma_ul_husna.py

# Regenerate both native bundled Wird assets and their identity manifest.
./scripts/generate_wird_model.py

# Verify the canonical Wird content hash, behavior fixture, identities, and native assets only.
./scripts/generate_wird_model.py --check

# Validate progress/Wird contracts, generated registries/assets, and both native suites.
./check-mobile-model-parity

# Validate shared behavior fixtures and malformed-case rejection only.
python3 scripts/validate_behavior_fixtures.py --self-test

# Validate Android urgency resource keys/placeholders across en/ar/ml.
python3 scripts/validate_android_urgency_resources.py --self-test

# Validate only the progress-sync protocol examples and reference count reducer.
python3 scripts/validate_progress_sync.py

# Validate Phoenix ordering, idempotency, and immutable count-ledger behavior.
(cd awrad_server && mix test test/awrad_server/progress_sync_test.exs test/awrad_server/progress_sync_count_ledger_test.exs)

# Validate capability-gated dhikr tag entities, coalescing, cascades, and transfer filtering.
(cd awrad_server && mix test test/awrad_server/progress_sync_document_test.exs test/awrad_server/progress_sync_dhikr_tags_test.exs test/awrad_server/progress_sync_entity_transfer_test.exs)
```

The root is not itself a build project. The parity command intentionally enters the Android and iOS projects. Set `AWRAD_IOS_TEST_DESTINATION` to an `xcodebuild` destination string when automatic iPhone Simulator selection is not appropriate.

## Android

Working directory: `awrad-android/`

Prerequisites: Android SDK, JDK 11-compatible Gradle runtime, and an emulator/device only for instrumentation tasks.

```bash
# Discover tasks and confirm the Gradle project loads
./gradlew tasks

# Focused JVM tests
./gradlew :app:testDebugUnitTest

# One test class
./gradlew :app:testDebugUnitTest --tests 'fully.qualified.TestClass'

# Compile/package a debug APK
./gradlew :app:assembleDebug

# Static Android lint
./gradlew :app:lintDebug

# Emulator/device tests
./gradlew :app:connectedDebugAndroidTest
```

Debug API default: `http://10.0.2.2:4000/`, which maps the Android emulator to the host machine.

Override it with either a Gradle property or environment variable:

```bash
AWRAD_DEBUG_API_BASE_URL=http://192.168.1.10:4000/ ./gradlew :app:assembleDebug
```

Release builds require an HTTPS API URL and explicit version values:

```bash
AWRAD_RELEASE_API_BASE_URL=https://example.com/ \
AWRAD_VERSION_CODE=2 \
AWRAD_VERSION_NAME=1.1.0 \
./gradlew :app:assembleRelease
```

Release signing additionally requires the ignored `keystore.properties` and referenced keystore. Never commit either file.

## iOS

Working directory: `awrad-ios/awrad/`

Prerequisites: the repository's selected Xcode installation. Simulator tests require an available simulator runtime.

```bash
# Confirm targets, configurations, and shared schemes
xcodebuild -list -project awrad.xcodeproj

# Compile app and test bundles without selecting a particular simulator
xcodebuild \
  -project awrad.xcodeproj \
  -scheme awrad \
  -destination 'generic/platform=iOS Simulator' \
  build-for-testing

# Show available simulator destinations
xcodebuild \
  -project awrad.xcodeproj \
  -scheme awrad \
  -showdestinations

# Run tests on a selected available simulator
xcodebuild \
  -project awrad.xcodeproj \
  -scheme awrad \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  test

# Run one XCTest method
xcodebuild \
  -project awrad.xcodeproj \
  -scheme awrad \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  -only-testing:awradTests/awradTests/<testMethod> \
  test
```

The widget also has the shared scheme `AwradWidgetExtension`. Use the main `awrad` scheme for app integration and test targets.

The default development API URL is `http://127.0.0.1:4000/` in `AuthService`. Tests and composition code may inject another URL.

## Phoenix server

Working directory: `awrad_server/`

Prerequisites: Elixir compatible with `mix.exs` and PostgreSQL reachable with the development/test configuration.

```bash
# Fetch dependencies, prepare assets, create/migrate DB, and seed
mix setup

# Start Phoenix at http://localhost:4000
mix phx.server

# Inspect a Mix task before using it
mix help test

# Run one test file or line
mix test test/path/to/file_test.exs
mix test test/path/to/file_test.exs:42

# Run the full test suite (creates/migrates the test DB)
mix test

# Compile with warnings as errors, remove unused locks, format, and test
# Note: this command may rewrite formatting.
mix precommit
```

Production runtime requires `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, the
mobile app-link values, the auth secrets, `RESEND_API_KEY`, and `MAIL_FROM`.
See `awrad_server/config/runtime.exs` for the authoritative list and
constraints, and `awrad_server/.env.example` for the deployment-facing
template.

Release image, built by CI and pulled by Dokploy. See `awrad_server/memory/deployment.md`.

```bash
# Build the production image locally (context is awrad_server/)
docker build --platform linux/amd64 -t awrad-api:local .

# Run it against a reachable Postgres, then probe the healthcheck
docker run --rm -p 4000:4000 --env-file .env awrad-api:local
curl -fsS http://localhost:4000/up

# Apply migrations inside a running release (Dokploy pre-deploy command)
/app/bin/migrate
```

## Local integration

1. Start PostgreSQL.
2. From `awrad_server/`, run `mix setup` once and then `mix phx.server`.
3. Android emulator builds use `10.0.2.2:4000` by default.
4. iOS Simulator builds use `127.0.0.1:4000` by default.
5. A physical device needs a host address reachable from that device; inject/override the mobile base URL instead of changing production defaults casually.
