# Auth Scope

## What is Scope?

`AwradApi.Accounts.Scope` is a struct that represents the identity of the current caller. It wraps the `User` and flows through the system via `conn.assigns.current_scope` (web) or `socket.assigns.current_scope` (LiveView).

```elixir
defstruct user: nil

def for_user(%User{} = user), do: %__MODULE__{user: user}
def for_user(nil), do: nil
```

## How Scope Flows

### Web (Browser Pipeline)

```
Request → fetch_current_scope_for_user plug → assigns current_scope → Controller/LiveView
```

The `fetch_current_scope_for_user` plug (from `UserAuth`):
1. Reads session token from cookie
2. Looks up user in DB
3. Assigns `current_scope` = `Scope.for_user(user)` or `nil`

### API Pipeline

```
Request → ApiAuth plug → assigns current_scope → Controller
```

The `ApiAuth` plug:
1. Reads Bearer JWT from Authorization header
2. Verifies JWT and extracts user ID from `sub` claim
3. Loads user from DB
4. Assigns `current_scope` = `Scope.for_user(user)`

### Accessing the Current User

```elixir
# In a controller
user = conn.assigns.current_user
scope = conn.assigns.current_scope

# In a LiveView
user = socket.assigns.current_scope.user
```

## Extending Scope

The Scope struct is designed to be extended. Future additions might include:

- `role` — for RBAC if needed
- `device_id` — for per-device tracking
- `sudo_mode?` — for sensitive operations (already exists via `Accounts.sudo_mode?/2`)

## Sudo Mode

Users are in "sudo mode" when their last authentication was within 20 minutes. Used to gate sensitive actions (email change, password change) without re-login:

```elixir
Accounts.sudo_mode?(user)          # default: 20 minutes
Accounts.sudo_mode?(user, -30)     # custom: 30 minutes
```

## Reference Files

- `lib/awrad_api/accounts/scope.ex` — Scope struct
- `lib/awrad_api_web/user_auth.ex` — `fetch_current_scope_for_user` plug
- `lib/awrad_api_web/plugs/api_auth.ex` — API scope assignment
