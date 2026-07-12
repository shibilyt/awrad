# Database

## ORM: Ecto (PostgreSQL)

Database client is `AwradApi.Repo` configured in `lib/awrad_api/repo.ex`.

## Schema Conventions

### Primary Keys

All schemas use binary UUIDs (configured globally):

```elixir
# In each schema module
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
```

This is set project-wide via `generators: [binary_id: true]` in `config/config.exs`.

### Timestamps

All timestamps use `utc_datetime`:

```elixir
timestamps(type: :utc_datetime)
```

Configured globally: `generators: [timestamp_type: :utc_datetime]`.

### Email Column

Uses PostgreSQL `citext` extension for case-insensitive email matching:

```sql
CREATE EXTENSION IF NOT EXISTS citext;
```

The `email` field is `:citext` type in migrations but `:string` in the Ecto schema (Ecto handles the mapping).

## Current Tables

| Table | Schema | Purpose |
|---|---|---|
| `users` | `AwradApi.Accounts.User` | User accounts (email, hashed_password, confirmed_at) |
| `users_tokens` | `AwradApi.Accounts.UserToken` | Auth tokens (session, refresh, magic link, change email) |

### users

```
id              :binary_id (PK)
email           :citext (unique)
hashed_password :string (nullable — magic link users may not have one)
confirmed_at    :utc_datetime
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### users_tokens

```
id               :binary_id (PK)
token            :binary         -- hashed for email/refresh tokens, raw for session
context          :string          -- "session" | "refresh" | "login" | "change:<email>"
sent_to          :string          -- email address (email tokens only)
authenticated_at :utc_datetime    -- when auth occurred (session tokens only)
user_id          :binary_id (FK → users)
inserted_at      :utc_datetime
```

Indexes: `users_email_index` (unique), `users_tokens_user_id_index`, `users_tokens_context_token_index` (unique).

## Migrations

Located in `priv/repo/migrations/`. Managed via Mix tasks:

```bash
mix ecto.gen.migration add_something   # generate migration
mix ecto.migrate                       # run pending migrations
mix ecto.rollback                      # rollback last migration
mix ecto.reset                         # drop + create + migrate + seed
```

## Contexts

Business logic is organized into contexts (bounded modules). Currently:

- `AwradApi.Accounts` — user registration, login, password/email management, token lifecycle

Each context is the public API for its domain. Controllers and LiveViews call context functions, never Repo directly.

## Changeset Pattern

Validations happen in schema changesets:

```elixir
def email_changeset(user, attrs, opts \\ []) do
  user
  |> cast(attrs, [:email])
  |> validate_required([:email])
  |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/)
  |> validate_length(:email, max: 160)
  |> unsafe_validate_unique(:email, AwradApi.Repo)
  |> unique_constraint(:email)
end
```

## Reference Files

- `lib/awrad_api/repo.ex` — Ecto Repo
- `lib/awrad_api/accounts/user.ex` — User schema + changesets
- `lib/awrad_api/accounts/user_token.ex` — Token schema + queries
- `priv/repo/migrations/` — migration files
- `config/config.exs` — generator config (binary_id, utc_datetime)
- `config/dev.exs` — dev database config
