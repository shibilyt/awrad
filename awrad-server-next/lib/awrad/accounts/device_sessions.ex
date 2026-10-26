defmodule Awrad.Accounts.DeviceSessions do
  @moduledoc """
  Mobile device sessions and their tokens (ADR-2026-07-12, root ADR-2026-10-26).

    * `create/2` signs an installation in, replacing its earlier session.
    * `refresh/2` rotates a refresh token under a row lock. It needs the
      request's `Idempotency-Key`: the same key within 60 seconds gets the same
      tokens back; any other reuse of a spent token revokes the session.
    * `sign_out/1` revokes the session that owns a refresh token.
    * `identify/1` turns an access token into its account and live session.
    * `revoke/3` and `revoke_all/3` end sessions from the account's session
      list (slice 2b) or after a password change or reset.
  """

  import Ecto.Query

  alias Awrad.Accounts.{AccessToken, DeviceSession, Grant, RefreshToken, User}
  alias Awrad.{Repo, Secrets}

  @retry_seconds 60
  @touch_after_seconds 300
  @retry_purpose "refresh_retry"

  @type device :: %{installation_id: String.t(), name: String.t(), platform: :android | :ios}

  @doc "Signs `user` in on an installation. Its earlier session for the account is revoked (`replaced`)."
  @spec create(User.t(), device()) :: Grant.t()
  def create(%User{} = user, device) do
    now = DateTime.utc_now(:second)
    installation_hash = Secrets.hmac("installation", device.installation_id)

    {:ok, grant} =
      Repo.transact(fn ->
        # Serialises concurrent sign-ins of the account, so two requests from one
        # installation can't both insert a live session.
        Repo.one!(from(u in User, where: u.id == ^user.id, lock: "FOR UPDATE", select: u.id))

        live =
          from(s in DeviceSession,
            where:
              s.user_id == ^user.id and s.installation_hash == ^installation_hash and
                is_nil(s.revoked_at),
            select: s.id
          )
          |> Repo.all()

        revoke_sessions(live, "replaced", now)

        session =
          Repo.insert!(%DeviceSession{
            user_id: user.id,
            installation_hash: installation_hash,
            device_name: device.name,
            platform: device.platform,
            last_seen_at: now,
            idle_expires_at: DeviceSession.expiries(now).idle_expires_at,
            absolute_expires_at: DeviceSession.expiries(now).absolute_expires_at
          })

        refresh_token = insert_refresh_token(session, nil)
        {access_token, expires_at} = AccessToken.issue(user, session)
        {:ok, Grant.new(user, session, access_token, expires_at, refresh_token)}
      end)

    grant
  end

  @doc """
  Rotates `refresh_token`. `key` is the request's `Idempotency-Key` (a UUID).

  Errors: `:refresh_token_invalid` (unknown, expired, revoked, or its session
  ended), `:refresh_reuse_detected` (a spent token reused; the session is now
  revoked), `:idempotency_key_reused` (the key already rotated another token).
  """
  @spec refresh(String.t(), Ecto.UUID.t()) ::
          {:ok, Grant.t()}
          | {:error, :refresh_token_invalid | :refresh_reuse_detected | :idempotency_key_reused}
  def refresh(refresh_token, key) when is_binary(refresh_token) and is_binary(key) do
    hash = :crypto.hash(:sha256, refresh_token)

    # The transaction always commits: a detected reuse must stay revoked. Failed writes raise.
    {:ok, result} = Repo.transact(fn -> {:ok, rotate_locked(hash, key)} end)
    result
  end

  @doc "Revokes the session owning `refresh_token` (`signed_out`). Unknown or spent tokens are ignored."
  @spec sign_out(String.t()) :: :ok
  def sign_out(refresh_token) when is_binary(refresh_token) do
    hash = :crypto.hash(:sha256, refresh_token)

    Repo.transact(fn ->
      session_ids =
        from(t in RefreshToken, where: t.token_hash == ^hash, select: t.device_session_id)
        |> Repo.all()

      revoke_sessions(session_ids, "signed_out", DateTime.utc_now(:second))
      {:ok, :ok}
    end)

    :ok
  end

  @doc "Revokes every live session of `user` with `reason`, except `keep_id` when given."
  @spec revoke_all(User.t(), String.t(), Ecto.UUID.t() | nil) :: :ok
  def revoke_all(%User{id: user_id}, reason, keep_id \\ nil) do
    query =
      from(s in DeviceSession,
        where: s.user_id == ^user_id and is_nil(s.revoked_at),
        select: s.id
      )

    query = if keep_id, do: where(query, [s], s.id != ^keep_id), else: query

    query
    |> Repo.all()
    |> revoke_sessions(reason, DateTime.utc_now(:second))

    :ok
  end

  @doc "Revokes the account's live session `session_id` with `reason`. `:not_found` if there's none."
  @spec revoke(User.t(), Ecto.UUID.t(), String.t()) :: :ok | :not_found
  def revoke(%User{} = user, session_id, reason) do
    now = DateTime.utc_now(:second)

    case Repo.one(from(s in live_query(user, now), where: s.id == ^session_id, select: s.id)) do
      nil -> :not_found
      id -> revoke_sessions([id], reason, now)
    end
  end

  @doc "The account's live sessions at `now`, as a query (for the session list)."
  @spec live_query(User.t(), DateTime.t()) :: Ecto.Query.t()
  def live_query(%User{id: user_id}, now) do
    from s in DeviceSession,
      where: s.user_id == ^user_id and is_nil(s.revoked_at),
      where: s.idle_expires_at > ^now and s.absolute_expires_at > ^now
  end

  @doc """
  The verified account and live session an access token belongs to. Updates
  `last_seen_at` at most every 5 minutes.
  """
  @spec identify(String.t()) :: {:ok, User.t(), DeviceSession.t()} | :error
  def identify(access_token) when is_binary(access_token) do
    now = DateTime.utc_now(:second)

    with {:ok, %{user_id: user_id, session_id: session_id}} <- AccessToken.verify(access_token),
         {:ok, user_id} <- Ecto.UUID.cast(user_id),
         {:ok, session_id} <- Ecto.UUID.cast(session_id),
         {%User{} = user, %DeviceSession{} = session} <- fetch_live(user_id, session_id, now) do
      {:ok, user, touch(session, now)}
    else
      _invalid -> :error
    end
  end

  defp fetch_live(user_id, session_id, now) do
    Repo.one(
      from s in DeviceSession,
        join: u in assoc(s, :user),
        where: s.id == ^session_id and s.user_id == ^user_id and not is_nil(u.confirmed_at),
        where: is_nil(s.revoked_at),
        where: s.idle_expires_at > ^now and s.absolute_expires_at > ^now,
        select: {u, s}
    )
  end

  defp touch(session, now) do
    if DateTime.diff(now, session.last_seen_at) >= @touch_after_seconds do
      Repo.update_all(from(s in DeviceSession, where: s.id == ^session.id),
        set: [last_seen_at: now]
      )

      %{session | last_seen_at: now}
    else
      session
    end
  end

  defp rotate_locked(hash, key) do
    now = DateTime.utc_now(:second)

    token =
      Repo.one(
        from t in RefreshToken,
          where: t.token_hash == ^hash,
          preload: [device_session: :user],
          lock: "FOR UPDATE"
      )

    cond do
      not usable?(token, now) -> {:error, :refresh_token_invalid}
      key_used_elsewhere?(token, key) -> {:error, :idempotency_key_reused}
      is_nil(token.used_at) -> rotate(token, key, now)
      retry?(token, key, now) -> replay(token)
      true -> reuse_detected(token, now)
    end
  end

  defp usable?(nil, _now), do: false

  defp usable?(token, now) do
    is_nil(token.revoked_at) and DateTime.after?(token.expires_at, now) and
      DeviceSession.active?(token.device_session, now)
  end

  defp key_used_elsewhere?(token, key) do
    Repo.exists?(from t in RefreshToken, where: t.rotation_key == ^key and t.id != ^token.id)
  end

  defp retry?(token, key, now) do
    token.rotation_key == key and not is_nil(token.retry_expires_at) and
      DateTime.after?(token.retry_expires_at, now)
  end

  defp rotate(token, key, now) do
    %{device_session: session} = token
    user = session.user
    successor = insert_refresh_token(session, token.id)

    session =
      session
      |> Ecto.Changeset.change(
        last_seen_at: now,
        idle_expires_at: DeviceSession.next_idle_expiry(session, now)
      )
      |> Repo.update!()

    {access_token, expires_at} = AccessToken.issue(user, session)

    retry =
      Jason.encode!(%{
        refresh_token: successor,
        access_token: access_token,
        access_token_expires_at: DateTime.to_unix(expires_at)
      })

    token
    |> Ecto.Changeset.change(
      used_at: now,
      rotation_key: key,
      retry_ciphertext: Secrets.encrypt(@retry_purpose, retry),
      retry_expires_at: DateTime.add(now, @retry_seconds, :second)
    )
    |> Repo.update!()

    {:ok, Grant.new(user, session, access_token, expires_at, successor)}
  end

  defp replay(%RefreshToken{device_session: session} = token) do
    with {:ok, json} <- Secrets.decrypt(@retry_purpose, token.retry_ciphertext),
         {:ok,
          %{
            "refresh_token" => refresh,
            "access_token" => access,
            "access_token_expires_at" => exp
          }} <-
           Jason.decode(json) do
      {:ok, Grant.new(session.user, session, access, DateTime.from_unix!(exp), refresh)}
    else
      _undecryptable -> {:error, :refresh_token_invalid}
    end
  end

  defp reuse_detected(token, now) do
    revoke_sessions([token.device_session_id], "refresh_reuse", now)
    {:error, :refresh_reuse_detected}
  end

  defp insert_refresh_token(session, parent_id) do
    raw = :crypto.strong_rand_bytes(32)

    Repo.insert!(%RefreshToken{
      device_session_id: session.id,
      parent_id: parent_id,
      token_hash: :crypto.hash(:sha256, Base.url_encode64(raw, padding: false)),
      expires_at: session.absolute_expires_at
    })

    Base.url_encode64(raw, padding: false)
  end

  defp revoke_sessions([], _reason, _now), do: :ok

  defp revoke_sessions(session_ids, reason, now) do
    Repo.update_all(
      from(s in DeviceSession, where: s.id in ^session_ids and is_nil(s.revoked_at)),
      set: [revoked_at: now, revoke_reason: reason, updated_at: now]
    )

    Repo.update_all(
      from(t in RefreshToken,
        where: t.device_session_id in ^session_ids and is_nil(t.revoked_at)
      ),
      set: [revoked_at: now]
    )

    :ok
  end
end
