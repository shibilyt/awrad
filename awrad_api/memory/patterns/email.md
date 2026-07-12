# Email

## Swoosh Mailer

Email delivery uses Swoosh, configured in `lib/awrad_api/mailer.ex`:

```elixir
defmodule AwradApi.Mailer do
  use Swoosh.Mailer, otp_app: :awrad_api
end
```

### Adapters by Environment

| Environment | Adapter | Access |
|---|---|---|
| Dev | `Swoosh.Adapters.Local` | http://localhost:4000/dev/mailbox |
| Test | `Swoosh.Adapters.Test` | Assertions via `Swoosh.TestAssertions` |
| Prod | Configure in `config/runtime.exs` | (e.g., Mailgun, SES, Resend) |

## User Notifier

`AwradApi.Accounts.UserNotifier` builds and delivers auth-related emails:

```elixir
# Magic link login
UserNotifier.deliver_login_instructions(user, magic_link_url)

# Email change confirmation
UserNotifier.deliver_update_email_instructions(user, confirmation_url)
```

Emails are plain text, delivered via `Mailer.deliver/1`.

## Reference Files

- `lib/awrad_api/mailer.ex` — Swoosh mailer
- `lib/awrad_api/accounts/user_notifier.ex` — email templates
- `config/config.exs` — mailer adapter config
- `config/dev.exs` — Swoosh API client disabled
