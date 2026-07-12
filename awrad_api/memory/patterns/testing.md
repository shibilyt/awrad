# Testing

## Framework: ExUnit

Tests run with `mix test`. Database is sandboxed per test via `Ecto.Adapters.SQL.Sandbox`.

## Test Structure

```
test/
  awrad_api/
    accounts_test.exs                      # Accounts context unit tests
  awrad_api_web/
    controllers/
      user_registration_controller_test.exs
      user_session_controller_test.exs
      user_settings_controller_test.exs
      error_json_test.exs
    user_auth_test.exs                     # Session auth plug tests
  support/
    conn_case.ex                           # ConnCase (controller/LiveView tests)
    data_case.ex                           # DataCase (context/schema tests)
    fixtures/
      accounts_fixtures.ex                 # User creation fixtures
```

## Test Helpers

### ConnCase (Controller & LiveView Tests)

```elixir
use AwradApiWeb.ConnCase

# Provides: @endpoint, conn, setup helpers
```

Includes `register_and_log_in_user` setup helper for tests that need an authenticated user:

```elixir
setup :register_and_log_in_user
# conn now has a logged-in user session
# assigns: current_scope
```

### DataCase (Context & Schema Tests)

```elixir
use AwradApi.DataCase

# Provides: Ecto sandbox, errors_on/1 helper
```

### Fixtures

```elixir
# test/support/fixtures/accounts_fixtures.ex
import AwradApi.AccountsFixtures

user = user_fixture()                    # creates user with unique email
user = user_fixture(%{email: "specific@example.com"})
```

## Running Tests

```bash
mix test                    # run all tests
mix test test/path_test.exs # run specific file
mix test --only tag         # run tagged tests
```

## Config

- `config/test.exs`: bcrypt log_rounds set to 1 (fast hashing), sandbox pool, JWT test secret
- Database: `awrad_api_test` (auto-created by `mix test`)

## Reference Files

- `test/support/conn_case.ex` — ConnCase module
- `test/support/data_case.ex` — DataCase module
- `test/support/fixtures/accounts_fixtures.ex` — test data factories
- `config/test.exs` — test environment config
