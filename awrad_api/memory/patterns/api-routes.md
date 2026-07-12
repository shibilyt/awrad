# API Routes

## Controller Pattern

API controllers live in `lib/awrad_api_web/controllers/api/` and use the JSON format.

```elixir
defmodule AwradApiWeb.Api.SomeController do
  use AwradApiWeb, :controller

  action_fallback AwradApiWeb.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user
    # ... fetch data ...
    json(conn, %{data: data})
  end
end
```

### Conventions

- Namespace: `AwradApiWeb.Api.*`
- Response format: always JSON via `json(conn, data)`
- Error handling: return `{:error, changeset}` and let `FallbackController` handle it, or explicitly set status + render JSON
- Auth: protected routes get `current_user` and `current_scope` from `conn.assigns` (set by `ApiAuth` plug)

## Fallback Controller

`AwradApiWeb.FallbackController` handles common error tuples:

```elixir
# {:error, %Ecto.Changeset{}} → 422 with error details
# {:error, :not_found}         → 404
```

## Changeset Error Formatting

```elixir
defp format_changeset_errors(changeset) do
  Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end)
end
```

Returns a map like `%{"email" => ["has already been taken"], "password" => ["should be at least 12 character(s)"]}`.

## Adding a New API Endpoint

1. Create controller in `lib/awrad_api_web/controllers/api/my_controller.ex`
2. Add route in `router.ex`:
   - Public: inside `scope "/api", pipe_through :api`
   - Protected: inside `scope "/api", pipe_through :api_auth`
3. Access user: `conn.assigns.current_user`

## Reference Files

- `lib/awrad_api_web/controllers/api/auth_controller.ex` — canonical API controller example
- `lib/awrad_api_web/controllers/fallback_controller.ex` — error fallback
- `lib/awrad_api_web/router.ex` — route definitions
