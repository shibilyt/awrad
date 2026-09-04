# Authentication

## Dual Auth Architecture

Awrad Server serves two clients with different auth mechanisms from a single `User` schema:

| Client | Mechanism | Module | Lifetime |
|---|---|---|---|
| Web (LiveView) | Session + signed cookie | `AwradServerWeb.UserAuth` | 14 days |
| Mobile API | JWT access + rotating DB refresh | `AwradServerWeb.Plugs.ApiAuth` + `AwradServer.Accounts.Token` | 15 min / 180 days |

## Web Auth (Session)

Powered by `phx.gen.auth`. Session tokens are stored in the `users_tokens` table with `context = "session"`.

### Plugs (from `AwradServerWeb.UserAuth`)

```elixir
# Runs on every browser request — reads session, assigns current_user/current_scope
plug :fetch_current_scope_for_user

# Guards — used on specific route groups
plug :require_authenticated_user       # redirects to /users/log-in if not logged in
plug :redirect_if_user_is_authenticated # redirects to / if already logged in
```

### Login Methods

1. **Magic link** (default): user enters email → receives link → clicks link → session created
2. **Password**: user enters email + password → session created

### Session Token Flow

```elixir
# Create session
{token, user_token} = UserToken.build_session_token(user)
Repo.insert!(user_token)
# token is stored in Phoenix session cookie

# Verify session (on each request)
{:ok, query} = UserToken.verify_session_token_query(token)
{user, token_inserted_at} = Repo.one(query)
```

## API Auth (JWT + Refresh)

### Access Token (JWT)

Module: `AwradServer.Accounts.Token` (uses `Joken.Config`)

```elixir
# Generate
{:ok, jwt, _claims} = Token.generate_access_token(user)

# Verify
{:ok, claims} = Token.verify_access_token(jwt)
user_id = claims["sub"]
```

JWT config: HS256, 15-minute expiry, issuer/audience = `"awrad_api"`, subject = user UUID.

Signing secret: per-environment config at `config :awrad_server, AwradServer.Accounts.Token, signing_secret: "..."`

### Refresh Token (DB-backed)

```elixir
# Generate pair (access + refresh), inserts refresh into DB
{:ok, access_token, refresh_token} = Token.generate_token_pair(user)

# Rotate (verify old, delete old, issue new pair)
{:ok, user} = Token.verify_and_rotate_refresh_token(old_refresh_token)
{:ok, new_access, new_refresh} = Token.generate_token_pair(user)

# Revoke specific token
Token.delete_refresh_token(refresh_token)

# Revoke all (logout from all devices)
Token.delete_all_refresh_tokens(user)
```

Refresh tokens are stored hashed (SHA256) in `users_tokens` with `context = "refresh"`. The client receives a base64url-encoded raw token.

### API Auth Plug

Module: `AwradServerWeb.Plugs.ApiAuth`

```elixir
# Reads Authorization: Bearer <jwt> header
# Verifies JWT signature + expiry
# Loads user from DB by sub claim
# Assigns current_user + current_scope
# Returns 401 JSON if invalid
```

Used in the `:api_auth` pipeline for protected API routes.

## Accounts Context Public API

```elixir
# Registration
Accounts.register_user(%{email: "..."})

# Login
Accounts.get_user_by_email_and_password(email, password)

# Session management
Accounts.generate_user_session_token(user)
Accounts.get_user_by_session_token(token)
Accounts.delete_user_session_token(token)

# Magic link
Accounts.deliver_login_instructions(user, url_fun)
Accounts.login_user_by_magic_link(token)

# Settings
Accounts.change_user_email(user, attrs)
Accounts.update_user_email(user, token)
Accounts.change_user_password(user, attrs)
Accounts.update_user_password(user, attrs)
```

## Reference Files

- `lib/awrad_server/accounts.ex` — Accounts context (public API)
- `lib/awrad_server/accounts/user.ex` — User schema with email/password changesets
- `lib/awrad_server/accounts/user_token.ex` — DB token schema (session, magic link, change email)
- `lib/awrad_server/accounts/token.ex` — JWT access + DB refresh token logic
- `lib/awrad_server/accounts/scope.ex` — Scope struct (wraps current user)
- `lib/awrad_server_web/user_auth.ex` — Session auth plugs (generated)
- `lib/awrad_server_web/plugs/api_auth.ex` — JWT Bearer auth plug
- `lib/awrad_server_web/controllers/api/auth_controller.ex` — JSON auth endpoints
