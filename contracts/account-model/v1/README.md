# Account model v1

The client-side input rules for accounts (slice 2a, [`docs/slices/02-accounts.md`](../../../docs/slices/02-accounts.md)). Every client (Android, iOS, web) and the server run these cases, so a value one client accepts is never rejected by another for a different reason. The server stays the authority: these rules only give early feedback.

| File | Rule | Cases |
|---|---|---|
| `fixtures/email_input.json` | A typed email: trimmed, then a basic shape check (one `@`, a dotted domain, no spaces, at most 160 characters) | 21 |
| `fixtures/password_policy.json` | 12 to 128 Unicode code points after NFC; no trimming, no composition rules | 12 |
| `fixtures/email_code_input.json` | A typed 6-digit code: spaces and hyphens removed; Arabic-Indic, Eastern Arabic-Indic and fullwidth digits converted | 14 |

## Conventions

- **Whitespace** means Unicode White_Space plus zero-width space (U+200B) and BOM (U+FEFF), as an explicit set. Don't rely on a platform's `trim()`, which differs between Kotlin, Swift, JavaScript and Elixir.
- **Length** is counted in Unicode code points, not UTF-16 units (Kotlin `String.length`, JavaScript `length`) and not grapheme clusters (Swift `String.count`, Elixir `String.length`).
- **Common passwords** (`password_too_common`) are checked by the server only, and aren't part of these cases.

The API side of these rules is in [`contracts/api/`](../../api/) (`Email`, `Password`, `EmailCode`).
