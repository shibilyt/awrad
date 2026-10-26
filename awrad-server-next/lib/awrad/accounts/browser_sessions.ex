defmodule Awrad.Accounts.BrowserSessions do
  @moduledoc """
  Browser session tokens (`users_tokens`, `phx.gen.auth`, ADR-2026-10-15).

    * `create/2` signs a browser in and returns the token for its cookie.
    * `identify/1` turns a token into its account and session, and updates
      `last_seen_at` at most every 5 minutes.
    * `reissue/2` replaces an old token in place: the session (its row, ID,
      name and sign-in time) stays, the replaced token works for 60 more
      seconds, so concurrent requests carrying the old cookie aren't signed out.
    * `delete_token/1`, `delete/2` and `delete_all/2` end sessions.
  """

  import Ecto.Query

  alias Awrad.Accounts.{User, UserToken}
  alias Awrad.Repo

  @touch_after_seconds 300
  @grace_seconds 60

  @typedoc "A live browser session: its ID, its current token and when that was issued."
  @type session :: %{id: Ecto.UUID.t(), token: binary(), inserted_at: DateTime.t()}

  @doc "Stores a new session token for `user` on a browser called `name`; returns the token."
  @spec create(User.t(), String.t() | nil) :: binary()
  def create(%User{} = user, name) do
    {token, user_token} = UserToken.build_session_token(user, name)
    Repo.insert!(user_token)
    token
  end

  @doc """
  The account and session a token belongs to, or `nil`. The token may be the
  session's current one or, for 60 seconds after a reissue, the one it replaced;
  `session.token` is always the current one.
  """
  @spec identify(binary()) :: {User.t(), session()} | nil
  def identify(token) when is_binary(token) do
    now = DateTime.utc_now(:second)

    query =
      from t in live_query(now),
        join: u in assoc(t, :user),
        where:
          t.token == ^token or
            (t.previous_token == ^token and t.previous_token_valid_until > ^now),
        select: {%{u | authenticated_at: t.authenticated_at}, t}

    case Repo.one(query) do
      {user, row} ->
        touch(row, now)
        {user, %{id: row.id, token: row.token, inserted_at: row.inserted_at}}

      nil ->
        nil
    end
  end

  @doc """
  Replaces the session's token `presented` with a new one, keeping the session,
  and returns the token to use. If a concurrent request already reissued it,
  returns that request's token instead.
  """
  @spec reissue(Ecto.UUID.t(), binary()) :: binary() | nil
  def reissue(session_id, presented) when is_binary(presented) do
    now = DateTime.utc_now(:second)
    token = UserToken.generate()

    {count, _} =
      Repo.update_all(
        from(t in UserToken, where: t.id == ^session_id and t.token == ^presented),
        set: [
          token: token,
          previous_token: presented,
          previous_token_valid_until: DateTime.add(now, @grace_seconds, :second),
          inserted_at: now,
          last_seen_at: now
        ]
      )

    if count == 1,
      do: token,
      else: Repo.one(from(t in UserToken, where: t.id == ^session_id, select: t.token))
  end

  @doc "Deletes the session `token` belongs to (sign-out). Always `:ok`."
  @spec delete_token(binary()) :: :ok
  def delete_token(token) when is_binary(token) do
    Repo.delete_all(
      from(t in UserToken,
        where: t.context == "session" and (t.token == ^token or t.previous_token == ^token)
      )
    )

    :ok
  end

  @doc "Deletes the account's live session `session_id`. `:not_found` if there's none."
  @spec delete(User.t(), Ecto.UUID.t()) :: :ok | :not_found
  def delete(%User{id: user_id}, session_id) do
    query =
      from t in live_query(DateTime.utc_now(:second)),
        where: t.user_id == ^user_id and t.id == ^session_id

    case Repo.delete_all(query) do
      {0, _} -> :not_found
      {_count, _} -> :ok
    end
  end

  @doc "Deletes every session of the account, except `keep_id` when given."
  @spec delete_all(User.t(), Ecto.UUID.t() | nil) :: :ok
  def delete_all(%User{id: user_id}, keep_id) do
    query = from(t in UserToken, where: t.user_id == ^user_id)
    query = if keep_id, do: where(query, [t], t.id != ^keep_id), else: query
    Repo.delete_all(query)
    :ok
  end

  @doc "The account's live sessions, as a query (for the session list)."
  @spec live_query(User.t(), DateTime.t()) :: Ecto.Query.t()
  def live_query(%User{id: user_id}, now),
    do: from(t in live_query(now), where: t.user_id == ^user_id)

  defp live_query(now) do
    from t in UserToken,
      where:
        t.context == "session" and
          t.inserted_at > ^DateTime.add(now, -UserToken.validity_in_days(), :day)
  end

  defp touch(row, now) do
    if DateTime.diff(now, row.last_seen_at) >= @touch_after_seconds do
      Repo.update_all(from(t in UserToken, where: t.id == ^row.id), set: [last_seen_at: now])
    end

    :ok
  end
end
