# awrad-server-next

The Awrad JSON API (Phoenix 1.8, Elixir 1.20, Postgres 18), rebuilt contract-first to replace `awrad_server/`. Start with [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`AGENTS.md`](AGENTS.md).

```bash
mise install                 # from the repo root: pinned Erlang/Elixir
mix setup                    # deps + create/migrate awrad_next_dev
mix phx.server               # http://localhost:4000
mix validate                 # the validation command CI runs
```

In development, emails (verification and password-reset codes) aren't sent: read them at http://localhost:4000/dev/mailbox, or as JSON at `/dev/mailbox/json` (`../COMMANDS.md`).
