# awrad-server-next — agent instructions

Applies inside `awrad-server-next/` and extends [`../AGENTS.md`](../AGENTS.md). Read [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`docs/adr/`](docs/adr/README.md) first.

## Rules the build enforces

- **Warnings are errors.** This covers compilation (including Elixir 1.20's type checker) and tests.
- **Boundaries** (ADR 0001):
  - `Awrad` (the domain) never references `AwradWeb`.
  - Contexts only use each other's exported modules.
  - A forbidden reference fails `mix validate`.
- **Contract** (ADR 0002): every `/api/v1` route must be in `contracts/api/openapi.yaml`, and the reverse. Responses are tested against the spec with `AwradWeb.Contract.assert_conforms/2`.
- **Static checks:**
  - `mix format`;
  - Credo strict, including the 400-line file limit (`credo/file_length.ex`);
  - Sobelow;
  - Dialyzer.

## Working rules

- **Contract first.** Add or change the operation in `contracts/api/` (then `npm run bundle` there) before writing the route.
- **Every API test of an endpoint calls `assert_conforms(conn, "<operation_id>")`**, for success and for each documented error.
- **Errors go through `AwradWeb.Problem`**, as RFC 9457 problems with a stable `code`. Never `json(conn, %{error: ...})`.
- **Ownership comes from the authenticated scope**, never from request parameters (`contracts/api/STYLE.md` §4).
- **Progress writes (goals, counts, custom dhikr, tags) go only through the progress command ledger** (STYLE.md §2). Web resource endpoints translate into ledger commands.
- **New contexts** are sub-modules of `Awrad` (`Awrad.Accounts`, …) with `use Boundary, exports: [...]`, and are added to `Awrad`'s deps.
- **Migrations:** timestamped Ecto migrations (`mix ecto.gen.migration`). Never expose a schema field as API by accident; map explicitly in the view or JSON module.
- **Security:** carry over `../awrad_server/memory/security.md` deliberately, slice by slice. Don't assume it.

## Validation

```bash
mix validate      # never modifies files; this is what CI runs
mix precommit     # local convenience: formats, then validates
```

`mix validate` needs Postgres 18. The machine's own server on 5432 is the default; for the `compose.yaml` one, set `AWRAD_POSTGRES_PORT=5433`. Sobelow prints "quoted keyword" warnings while reading `mix.lock` under Elixir 1.20. That's upstream noise, not a failure.
