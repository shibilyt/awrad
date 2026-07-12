# Router & Pipelines

## Pipelines

Three pipelines handle different request types:

| Pipeline | Purpose | Plugs |
|---|---|---|
| `:browser` | Web pages (LiveView + controllers) | accepts HTML, session, flash, CSRF, secure headers, `fetch_current_scope_for_user` |
| `:api` | Public API endpoints | accepts JSON |
| `:api_auth` | Protected API endpoints | accepts JSON, `AwradApiWeb.Plugs.ApiAuth` (JWT verification) |

```elixir
# lib/awrad_api_web/router.ex

pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {AwradApiWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug :fetch_current_scope_for_user    # from UserAuth
end

pipeline :api do
  plug :accepts, ["json"]
end

pipeline :api_auth do
  plug :accepts, ["json"]
  plug AwradApiWeb.Plugs.ApiAuth        # JWT Bearer verification
end
```

## Route Groups

### Browser Routes

```elixir
# Public
scope "/", AwradApiWeb do
  pipe_through :browser
  live "/", HomeLive
end

# Auth pages (redirect if already logged in)
scope "/", AwradApiWeb do
  pipe_through [:browser, :redirect_if_user_is_authenticated]
  get/post "/users/register"
end

# Protected pages (require login)
scope "/", AwradApiWeb do
  pipe_through [:browser, :require_authenticated_user]
  get/put "/users/settings"
end

# Session management (public)
scope "/", AwradApiWeb do
  pipe_through [:browser]
  get/post "/users/log-in"
  delete "/users/log-out"
end
```

### API Routes

```elixir
# Public auth endpoints
scope "/api/auth", AwradApiWeb.Api do
  pipe_through :api
  post "/register",  AuthController, :register
  post "/login",     AuthController, :login
  post "/refresh",   AuthController, :refresh
  post "/forgot-password", AuthController, :forgot_password
  post "/reset-password",  AuthController, :reset_password
end

# Protected endpoints
scope "/api", AwradApiWeb.Api do
  pipe_through :api_auth
  delete "/auth/logout", AuthController, :logout
  # Future protected endpoints go here
end
```

### Dev Routes (dev only)

```elixir
scope "/dev" do
  live_dashboard "/dashboard"
  forward "/mailbox", Plug.Swoosh.MailboxPreview
end
```

## Adding a New Protected API Endpoint

1. Create a controller in `lib/awrad_api_web/controllers/api/`
2. Add routes inside the `scope "/api"` block that uses `pipe_through :api_auth`
3. Access the user via `conn.assigns.current_user` or `conn.assigns.current_scope`

## Reference Files

- `lib/awrad_api_web/router.ex` — all routes and pipelines
- `lib/awrad_api_web/user_auth.ex` — browser auth plugs
- `lib/awrad_api_web/plugs/api_auth.ex` — API auth plug
