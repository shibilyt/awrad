# Email

## Swoosh Mailer

Email delivery uses Swoosh, configured in `lib/awrad_server/mailer.ex`:

```elixir
defmodule AwradServer.Mailer do
  use Swoosh.Mailer, otp_app: :awrad_server
end
```

### Adapters by Environment

| Environment | Adapter | Access |
|---|---|---|
| Dev | `Swoosh.Adapters.Local` | http://localhost:4000/dev/mailbox |
| Test | `Swoosh.Adapters.Test` | Assertions via `Swoosh.TestAssertions` |
| Prod | `Swoosh.Adapters.Resend` | `RESEND_API_KEY`, `MAIL_FROM`, and optional `MAIL_FROM_NAME` |

## User Notifier

`AwradServer.Accounts.UserNotifier` builds and delivers auth-related emails:

```elixir
# Magic link login
UserNotifier.deliver_login_instructions(user, magic_link_url)

# Email change confirmation
UserNotifier.deliver_update_email_instructions(user, confirmation_url)
```

Emails are plain text, delivered via `Mailer.deliver/1`. Production delivery uses
Resend's API and requires a sender address from a verified Resend domain.
Browser-facing auth links use `WEB_HOST`; mobile verification links use
`PHX_HOST`.

## Reference Files

- `lib/awrad_server/mailer.ex` — Swoosh mailer
- `lib/awrad_server/accounts/user_notifier.ex` — email templates
- `config/config.exs` — mailer adapter config
- `config/dev.exs` — Swoosh API client disabled
