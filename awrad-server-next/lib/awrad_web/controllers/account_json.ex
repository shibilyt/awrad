defmodule AwradWeb.AccountJSON do
  @moduledoc """
  The account schemas of `contracts/api/openapi.yaml` (`Account`,
  `AccountSession`, `DeviceSession`, `DeviceSessionGrant`), mapped field by field so no
  internal field (password hash, installation hash, revocation) leaks.
  """

  alias Awrad.Accounts.{DeviceSession, Grant, User}

  @doc "`Account`."
  @spec account(User.t()) :: map()
  def account(%User{} = user) do
    %{id: user.id, email: user.email, created_at: instant(user.inserted_at)}
  end

  @doc "`DeviceSession`."
  @spec device_session(DeviceSession.t()) :: map()
  def device_session(%DeviceSession{} = session) do
    %{
      id: session.id,
      device_name: session.device_name,
      platform: Atom.to_string(session.platform),
      created_at: instant(session.inserted_at),
      last_seen_at: instant(session.last_seen_at),
      idle_expires_at: instant(session.idle_expires_at),
      absolute_expires_at: instant(session.absolute_expires_at)
    }
  end

  @doc "`AccountSession`: one entry of the account's session list."
  @spec account_session(Awrad.Accounts.account_session()) :: map()
  def account_session(%{kind: kind, platform: platform} = item) do
    %{
      id: item.id,
      kind: Atom.to_string(kind),
      name: item.name,
      platform: Atom.to_string(platform),
      created_at: instant(item.created_at),
      last_seen_at: instant(item.last_seen_at),
      is_current: item.is_current
    }
  end

  @doc "`DeviceSessionGrant`."
  @spec grant(Grant.t()) :: map()
  def grant(%Grant{} = grant) do
    %{
      account: account(grant.user),
      session: device_session(grant.session),
      access_token: grant.access_token,
      access_token_expires_at: instant(grant.access_token_expires_at),
      refresh_token: grant.refresh_token
    }
  end

  # RFC 3339 in UTC with `Z`, whole seconds (STYLE §6).
  defp instant(%DateTime{} = datetime),
    do: datetime |> DateTime.truncate(:second) |> DateTime.to_iso8601()
end
