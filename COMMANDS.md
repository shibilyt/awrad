# Commands

Run each command from the working directory shown. Start with focused checks and use full suites when the risk justifies them. Frozen-app commands live in [`docs/reference/legacy-commands.md`](docs/reference/legacy-commands.md).

## Repository root

Working directory: repository root.

```bash
git status --short
git diff --check
git diff --stat
```

### contracts/: API spec and new fixtures (Node)

Working directory: `contracts/`. Prerequisite: Node 24 (from `mise.toml`).

```bash
npm ci                       # once: install the pinned tools
npm run bundle               # regenerate api/openapi.bundled.json after editing openapi.yaml or paths/
npm test                     # bundle fresh, spec lint clean, every rule fires, fixtures valid
npm run lint:api             # just the Spectral lint
npm run check:fixtures       # just the awrad-fixture/1 files
```

### contracts/: v1 legacy folders (Python)

```bash
# Validate the v1 folders
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

Working directory: `awrad-android-next/`. Prerequisites: JDK 17 (from `mise.toml`) and the Android SDK. Point `local.properties` (`sdk.dir=…`) or `ANDROID_HOME` at the SDK. An emulator or device is only needed for instrumented tests and installs.

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

## awrad-server-next

Working directory: `awrad-server-next/`. Prerequisites: Erlang and Elixir from `mise.toml`, and Postgres 18 (the machine's own on 5432, or `compose.yaml` with `AWRAD_POSTGRES_PORT=5433`).

```bash
mix setup                       # deps, then create and migrate awrad_next_dev
mix phx.server                  # http://localhost:4000
mix test test/path/file_test.exs   # focused tests
mix validate                    # full validation (never modifies files; what CI runs)
mix precommit                   # format, then validate
```

The first `mix validate` builds Dialyzer's cache into `priv/plts/` (git-ignored, about a minute). Later runs reuse it.

## awrad-ios-next, awrad-web-next

Not created yet. Each scaffold adds its section here: prerequisites, first run, validation command, focused checks.

## Toolchains and local services

Pinned in one place each:

| What | Pinned in | Versions |
|---|---|---|
| Erlang, Elixir, Node, JDK | `mise.toml` | OTP 29.1.2, Elixir 1.20.4, Node 24.22.0, Zulu JDK 17 |
| Xcode | `.xcode-version` | 26.2 |
| Postgres | Your local server (default), or `compose.yaml` | Major 18. Local default `127.0.0.1:5432`; compose runs 18.6 on `127.0.0.1:5433` |

```bash
brew install mise            # once per machine
mise install                 # install the pinned runtimes; mise activates them inside this repo
scripts/check-toolchain      # verify this machine matches every pin (add --skip-xcode / --skip-docker)

# Postgres: use your local Postgres 18 (Postgres.app or Homebrew) on 5432 with the postgres/postgres role.
# No local Postgres? Run the container instead and point tools at it:
docker compose up -d --wait postgres   # Postgres 18.6 on 127.0.0.1:5433 (needs Docker Desktop running)
export AWRAD_POSTGRES_PORT=5433
docker compose down                    # stop it; data stays in the postgres_data volume
```

To make mise switch versions automatically, add `eval "$(mise activate zsh)"` to `~/.zshrc`. Without it, prefix commands with `mise exec --`.

`AWRAD_POSTGRES_PORT` (default 5432) tells `scripts/check-toolchain`, and later `awrad-server-next`'s dev config, where Postgres is. Credentials are `postgres`/`postgres`, dev-only. The compose container is reachable from this machine only.

The new server's databases are namespaced `awrad_next_dev` and `awrad_next_test`, so they never collide with the frozen server's `awrad_api_*` databases on a shared local Postgres.
