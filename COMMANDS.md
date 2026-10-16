# Commands

Run each command from the working directory shown. Start with focused checks and use full suites when the risk justifies them. Frozen-app commands live in [`docs/reference/legacy-commands.md`](docs/reference/legacy-commands.md).

## Repository root

Working directory: repository root.

```bash
git status --short
git diff --check
git diff --stat
```

### contracts/

```bash
# Validate everything in contracts/ (the contracts validation command)
python3 scripts/validate_progress_contract.py && python3 scripts/validate_progress_sync.py && python3 scripts/validate_behavior_fixtures.py && python3 scripts/generate_wird_model.py --check && python3 scripts/generate_asma_ul_husna.py --check

# Individual validators
python3 scripts/validate_progress_contract.py     # progress-model v1 schemas, fixtures, 113 built-in identities
python3 scripts/validate_progress_sync.py         # progress-sync v1 protocol examples and count reducer
python3 scripts/validate_behavior_fixtures.py     # shared behaviour cases (add --self-test for malformed-case rejection)

# Regenerate derived content after editing the canonical JSON
python3 scripts/generate_asma_ul_husna.py
python3 scripts/generate_wird_model.py
```

`generate_wird_model.py` and `generate_asma_ul_husna.py` still write and check generated assets inside the frozen apps. Point them at the `-next` projects as each project starts using the content pipeline (rebuild plan, "Content pipeline").

## awrad-android-next

Working directory: `awrad-android-next/`. Prerequisites: JDK 17 and the Android SDK. Point `local.properties` (`sdk.dir=…`) or `ANDROID_HOME` at the SDK. An emulator or device is only needed for instrumented tests and installs.

```bash
# Full validation: build, unit tests, detekt, file-size limit, lint (warnings are errors)
./gradlew assembleDebug testDebugUnitTest :core:domain:test detekt verifySourceFileSize lintDebug

# Focused
./gradlew :core:domain:test                                   # pure-Kotlin domain tests (JVM)
./gradlew :feature:onboarding:testDebugUnitTest               # one feature's unit tests
./gradlew :feature:onboarding:testDebugUnitTest --tests 'fully.qualified.TestClass'
./gradlew detekt                                              # static analysis, all modules
./gradlew help                                                # quick check of the module dependency rules

# Run it (installs next to the frozen app; separate app id)
./gradlew :app:installDebug
```

## awrad-server-next, awrad-ios-next, awrad-web-next

Not created yet. Each scaffold adds its section here: prerequisites, first run, validation command, focused checks.

## Toolchains

The pinned toolchains (`mise.toml` for Erlang, Elixir, Node and JDK; the Xcode version; Docker Compose for Postgres) are rebuild plan item 0.5. Until then, use the versions in each project's own config.
