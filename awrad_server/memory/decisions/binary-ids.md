# Decision: Binary UUIDs as Primary Keys

## Status

Accepted

## Date

2026-04-07

## Context

We need a primary key strategy for all tables.

## Decision

Use binary UUIDs (`Ecto.UUID`) as primary keys for all schemas, configured globally:

```elixir
# config/config.exs
config :awrad_server, generators: [binary_id: true]

# In each schema
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
```

## Rationale

- **No enumeration**: UUIDs prevent sequential ID guessing (important for an API exposed to mobile clients)
- **Merge-safe**: no conflicts when syncing data between mobile and server
- **Future sync support**: the mobile app may need offline-first with eventual sync — UUIDs make this straightforward
- **Phoenix default option**: well-supported by Ecto and Phoenix generators

## Tradeoffs

- Larger than integer IDs (16 bytes vs 4/8 bytes)
- Not human-readable in logs (mitigated by using email for user lookups)
- Slightly slower index operations than sequential integers (negligible at our scale)
