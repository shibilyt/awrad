# Feature: Authentication

## Overview

The auth system provides identity management for two clients:

- **Web app** (Phoenix LiveView): session + cookie based, with magic link and password login
- **Mobile apps** (Android and iOS): JWT access token + rotating refresh token over REST API

Both share a single `User` schema and `Accounts` context.

## System Context

```mermaid
graph TB
    subgraph Clients
        Mobile["Awrad Mobile Apps<br/>(Android + iOS)"]
        Web["Awrad Web App<br/>(Phoenix LiveView)"]
    end

    subgraph "Awrad Server (Phoenix 1.8.5)"
        API["/api/auth/* endpoints<br/>JSON + JWT"]
        LV["LiveView + Controllers<br/>Session + Cookie"]
        Accounts["Accounts Context"]
        DB[(PostgreSQL)]
    end

    Mobile -->|"REST + Bearer Token"| API
    Web -->|"WebSocket + HTTP"| LV
    API --> Accounts
    LV --> Accounts
    Accounts --> DB
```

## User Schema

| Field | Type | Notes |
|---|---|---|
| `id` | binary UUID | Primary key |
| `email` | citext | Unique, case-insensitive |
| `hashed_password` | string | Nullable (magic link users may not have one) |
| `confirmed_at` | utc_datetime | Set on first magic link confirmation |
| `authenticated_at` | utc_datetime (virtual) | Set from session token, used for sudo mode |
| `inserted_at` | utc_datetime | |
| `updated_at` | utc_datetime | |

## Sub-Features

| Feature | Description | Doc |
|---|---|---|
| Web registration | Email-based registration; password is optional for magic-link users | Built into phx.gen.auth |
| Magic link login | Passwordless login via email link (15 min expiry) | Built into phx.gen.auth |
| Password login | Email + password login | Built into phx.gen.auth |
| Settings | Change email, set/change password | Built into phx.gen.auth |
| API registration | `POST /api/auth/register` with email + password | `auth_controller.ex` |
| API login | `POST /api/auth/login` returns a token pair, or `password_setup_required` for confirmed passwordless web accounts | `auth_controller.ex` |
| Token refresh | `POST /api/auth/refresh` with rotation | [token-design.md](token-design.md) |
| API forgot password | `POST /api/auth/forgot-password` sends reset instructions without revealing account existence | `auth_controller.ex` |
| API reset password | `POST /api/auth/reset-password` consumes a reset token and new password | `auth_controller.ex` |
| API logout | `DELETE /api/auth/logout` revokes tokens | `auth_controller.ex` |

## Password Rules

- Minimum: 15 characters
- Maximum: 128 characters
- Hashing: Argon2id; existing bcrypt hashes are upgraded after successful login
- Password reset tokens are single-use and expire all existing account tokens when consumed

## Key Files

- `lib/awrad_server/accounts.ex` — public context API
- `lib/awrad_server/accounts/user.ex` — user schema + changesets
- `lib/awrad_server/accounts/user_token.ex` — DB token schema + queries
- `lib/awrad_server/accounts/token.ex` — JWT + refresh token logic
- `lib/awrad_server/accounts/scope.ex` — caller scope
- `lib/awrad_server/accounts/user_notifier.ex` — email templates
- `lib/awrad_server_web/user_auth.ex` — session auth plugs
- `lib/awrad_server_web/plugs/api_auth.ex` — JWT auth plug
- `lib/awrad_server_web/controllers/api/auth_controller.ex` — JSON endpoints
- `lib/awrad_server_web/controllers/user_*_controller.ex` — web controllers
- `priv/repo/migrations/*_create_users_auth_tables.exs` — migration
- `test/awrad_server/accounts_test.exs` — context tests
- `test/awrad_server_web/controllers/user_*_test.exs` — controller tests
- `test/awrad_server_web/user_auth_test.exs` — plug tests
