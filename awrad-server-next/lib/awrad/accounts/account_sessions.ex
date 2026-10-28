defmodule Awrad.Accounts.AccountSessions do
  @moduledoc """
  The account's session list (slice 2b, `CONTEXT.md` "Account session"):
  mobile device sessions and browser sessions together.

    * `list/3` pages through the live sessions, most recently used first
      (`last_seen_at`, then ID, both descending), with the caller's own marked.
      The cursor is opaque to clients: the last item's `last_seen_at` and ID.
    * `revoke/2` ends one session of the account; `revoke_others/1` ends every
      session except the caller's.
  """

  import Ecto.Query

  alias Awrad.Accounts.{BrowserSessions, DeviceSessions, Scope}
  alias Awrad.Repo

  @default_limit 50
  @max_limit 100

  @type item :: %{
          id: Ecto.UUID.t(),
          kind: :device | :browser,
          name: String.t() | nil,
          platform: :android | :ios | :web,
          created_at: DateTime.t(),
          last_seen_at: DateTime.t(),
          is_current: boolean()
        }
  @type page :: %{items: [item()], next_cursor: String.t() | nil}

  @doc """
  One page of the account's live sessions. `cursor` is `nil` or the previous
  page's `next_cursor`; `limit` is `nil` (50) or 1 to 100.
  """
  @spec list(Scope.t(), String.t() | nil, pos_integer() | nil) ::
          {:ok, page()} | {:error, :cursor_invalid}
  def list(%Scope{user: user} = scope, cursor, limit)
      when is_nil(limit) or (is_integer(limit) and limit in 1..@max_limit) do
    limit = limit || @default_limit

    with {:ok, position} <- decode_cursor(cursor) do
      now = DateTime.utc_now(:second)

      devices =
        user
        |> DeviceSessions.live_query(now)
        |> page_query(position, limit)
        |> Repo.all()
        |> Enum.map(&device_item(&1, scope))

      browsers =
        user
        |> BrowserSessions.live_query(now)
        |> page_query(position, limit)
        |> Repo.all()
        |> Enum.map(&browser_item(&1, scope))

      sorted = Enum.sort_by(devices ++ browsers, &sort_key/1, :desc)
      {items, rest} = Enum.split(sorted, limit)

      next_cursor =
        case {rest, List.last(items)} do
          {[], _last} -> nil
          {_more, last} -> encode_cursor(last)
        end

      {:ok, %{items: items, next_cursor: next_cursor}}
    end
  end

  @doc """
  Ends the account's live session `session_id`, of either kind. Revoking the
  caller's own session signs it out. `:not_found` for an ID that isn't one of
  the account's live sessions.
  """
  @spec revoke(Scope.t(), String.t()) :: :ok | :not_found
  def revoke(%Scope{user: user} = scope, session_id) when is_binary(session_id) do
    if Awrad.ID.valid?(session_id) do
      reason = if Scope.current_session_id(scope) == session_id, do: "signed_out", else: "revoked"

      with :not_found <- DeviceSessions.revoke(user, session_id, reason) do
        BrowserSessions.delete(user, session_id)
      end
    else
      :not_found
    end
  end

  @doc "Ends every session of the account except the caller's own."
  @spec revoke_others(Scope.t()) :: :ok
  def revoke_others(%Scope{} = scope) do
    {:ok, :ok} = Repo.transact(fn -> {:ok, end_others(scope, "revoked")} end)
    :ok
  end

  @doc "Ends every session of the account except the caller's, with `reason` for device sessions."
  @spec end_others(Scope.t(), String.t()) :: :ok
  def end_others(%Scope{user: user} = scope, reason) do
    keep_device = scope.device_session && scope.device_session.id
    :ok = DeviceSessions.revoke_all(user, reason, keep_device)
    BrowserSessions.delete_all(user, scope.browser_session_id)
  end

  # The rows after the cursor, in list order: up to `limit + 1` from each kind,
  # so the merged page knows whether more follow.
  defp page_query(query, position, limit) do
    query = from(s in query, order_by: [desc: s.last_seen_at, desc: s.id], limit: ^(limit + 1))

    case position do
      nil ->
        query

      {seen_at, id} ->
        where(
          query,
          [s],
          s.last_seen_at < ^seen_at or (s.last_seen_at == ^seen_at and s.id < ^id)
        )
    end
  end

  defp device_item(session, scope) do
    %{
      id: session.id,
      kind: :device,
      name: session.device_name,
      platform: session.platform,
      created_at: session.inserted_at,
      last_seen_at: session.last_seen_at,
      is_current: Scope.current_session_id(scope) == session.id
    }
  end

  defp browser_item(token, scope) do
    %{
      id: token.id,
      kind: :browser,
      name: token.name,
      platform: :web,
      # A reissue renews `inserted_at`; the sign-in time stays in `authenticated_at`.
      created_at: token.authenticated_at || token.inserted_at,
      last_seen_at: token.last_seen_at,
      is_current: Scope.current_session_id(scope) == token.id
    }
  end

  # UUIDs compare in the same order as strings here and as `uuid` in Postgres.
  defp sort_key(item), do: {DateTime.to_unix(item.last_seen_at), item.id}

  defp encode_cursor(item) do
    Base.url_encode64("#{DateTime.to_unix(item.last_seen_at)}:#{item.id}", padding: false)
  end

  defp decode_cursor(nil), do: {:ok, nil}

  defp decode_cursor(cursor) when is_binary(cursor) and byte_size(cursor) <= 512 do
    with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
         [unix, id] <- String.split(decoded, ":", parts: 2),
         {unix, ""} <- Integer.parse(unix),
         {:ok, seen_at} <- DateTime.from_unix(unix),
         true <- Awrad.ID.valid?(id) do
      {:ok, {seen_at, id}}
    else
      _invalid -> {:error, :cursor_invalid}
    end
  end

  defp decode_cursor(_cursor), do: {:error, :cursor_invalid}
end
