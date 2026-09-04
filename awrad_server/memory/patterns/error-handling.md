# Error Handling

## Web (HTML)

Error pages are rendered by `AwradServerWeb.ErrorHTML` (`lib/awrad_server_web/controllers/error_html.ex`). Uses Phoenix's default error template rendering.

## API (JSON)

### Fallback Controller

`AwradServerWeb.FallbackController` handles error tuples returned from controller actions:

```elixir
action_fallback AwradServerWeb.FallbackController
```

Handled patterns:
- `{:error, %Ecto.Changeset{}}` → 422 with error details
- `{:error, :not_found}` → 404

### Error JSON

`AwradServerWeb.ErrorJSON` renders JSON error responses:

```elixir
# Renders: %{errors: %{detail: "Not Found"}}
```

### Inline Error Responses

For auth-specific errors, controllers return errors directly:

```elixir
conn
|> put_status(:unauthorized)
|> json(%{error: "invalid email or password"})
```

### Changeset Error Formatting

```elixir
Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
  Enum.reduce(opts, msg, fn {key, value}, acc ->
    String.replace(acc, "%{#{key}}", to_string(value))
  end)
end)
# => %{"email" => ["has already been taken"]}
```

### Translate Error (UI)

`CoreComponents.translate_error/1` handles Ecto error tuples for HTML rendering:

```elixir
def translate_error({msg, opts}) do
  Enum.reduce(opts, msg, fn {key, value}, acc ->
    String.replace(acc, "%{#{key}}", to_string(value))
  end)
end
```

## Reference Files

- `lib/awrad_server_web/controllers/fallback_controller.ex`
- `lib/awrad_server_web/controllers/error_json.ex`
- `lib/awrad_server_web/controllers/error_html.ex`
- `lib/awrad_server_web/components/core_components.ex` — `translate_error/1`
