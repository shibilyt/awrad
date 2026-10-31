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
npm run check:practice-settings   # slice 3d rules, Maghrib from adhan, the city list and its search
npm run check:goal-model     # every goal-model case against the reference rules in tools/goal-rules.mjs (slice 4a)
npm run check:sync           # the change-queue contract: examples, receipts, cascades, goals
npm run build:cities -- <dir>     # rebuild places/v1/cities.json from a GeoNames dump (cities15000.txt, admin1CodesASCII.txt)
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
./gradlew :core:data:generateCityList                         # copy contracts/places/v1/cities.json into the app (verifyCityList checks drift)

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

**Account emails in development.** Nothing is really sent: every email (verification and reset codes) lands in Swoosh's local mailbox while `mix phx.server` runs, and is lost on restart.

```bash
open http://localhost:4000/dev/mailbox                       # every sent email, newest first
curl -s http://localhost:4000/dev/mailbox/json               # the same as JSON, for scripts
curl -s http://localhost:4000/dev/mailbox/json \
  | python3 -c 'import json,re,sys; print(re.search(r"\b\d{6}\b", json.load(sys.stdin)["data"][0]["text_body"])[0])'   # the latest code
```

Email language follows the request's `Accept-Language` (`en`, `ar`, `ml`; default `en`). Account rate limits apply in development too (for example 5 registrations an hour per email); `mix ecto.reset` clears them.

**macOS 27 with Command Line Tools 27:** `argon2_elixir` compiles a NIF, and the Command Line Tools linker can't link against the macOS 27 SDK. Build it once with Xcode's toolchain: `SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" CC="$(xcrun -f clang)" mix deps.compile argon2_elixir` (once per `MIX_ENV`, e.g. also with `MIX_ENV=test`).

## awrad-ios-next

Working directory: `awrad-ios-next/`. Prerequisites: Xcode 26.2 (`.xcode-version`) and SwiftLint from `mise.toml`. A simulator is only needed for UI checks.

```bash
open AwradNext.xcodeproj                              # develop in Xcode
scripts/validate                                      # full validation (never modifies files; what CI runs)
(cd AwradKit && swift test)                           # all package tests on macOS
(cd AwradKit && swift test --filter OnboardingModelTests)
swift format -i -r AwradKit/Sources AwradKit/Tests AwradKit/Package.swift AwradNext   # fix layout
scripts/generate-colors.py                            # regenerate AwradColors.swift and AccentColor after contracts/design-tokens changes
scripts/generate-design-tokens.py                     # regenerate AwradRadius/AwradSpacing/AwradTextStyle/AwradMotion after contracts/design-tokens changes
scripts/generate-icons.py                             # regenerate Icons.xcassets and AwradIcon.swift after contracts/design-tokens/v1/icons changes
scripts/check-city-list.py --fix                      # copy contracts/places/v1/cities.json into AwradKit (validate checks drift)
```

## awrad-web-next

Working directory: `awrad-web-next/`. Prerequisite: Node 24 from `mise.toml`. Run `awrad-server-next` (`mix phx.server`) for real API calls.

```bash
npm ci                         # install pinned dependencies
npm run dev                    # http://localhost:5180; /api and /socket proxy to Phoenix on :4000 (AWRAD_API_ORIGIN overrides)
npm run validate               # full validation (what CI runs)
npm test                       # tests only
npm run api:types              # regenerate src/shared/api/schema.gen.ts after a spec change
npm run format                 # fix formatting
```

## Toolchains and local services

Pinned in one place each:

| What | Pinned in | Versions |
|---|---|---|
| Erlang, Elixir, Node, JDK, SwiftLint | `mise.toml` | OTP 29.1.2, Elixir 1.20.4, Node 24.22.0, Zulu JDK 17, SwiftLint 0.65.1 |
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
