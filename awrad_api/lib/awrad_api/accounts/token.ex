defmodule AwradApi.Accounts.Token do
  use Joken.Config

  import Ecto.Query

  alias AwradApi.Accounts.{ApiRefreshToken, AuthRateLimiter, AuthSecurityEvent, AuthSession, User}
  alias AwradApi.Repo

  @access_token_expiry_seconds 15 * 60
  @refresh_idle_days 30
  @session_absolute_days 180
  @retry_seconds 60
  @rand_size 32

  @impl Joken.Config
  def token_config do
    default_claims(default_exp: @access_token_expiry_seconds, iss: "awrad_api", aud: "awrad_api")
  end

  def generate_access_token(%User{} = user, %AuthSession{} = session) do
    signer = Joken.Signer.create("HS256", signing_secret())

    claims = %{
      "sub" => user.id,
      "sid" => session.id,
      "jti" => Ecto.UUID.generate(),
      "email_verified" => not is_nil(user.confirmed_at)
    }

    generate_and_sign(claims, signer)
  end

  def verify_access_token(token) do
    signer = Joken.Signer.create("HS256", signing_secret())
    verify_and_validate(token, signer)
  end

  def create_session(%User{} = user, device_attrs \\ %{}) do
    now = DateTime.utc_now(:second)
    device_id = Map.get(device_attrs, "installation_id") || Ecto.UUID.generate()
    device_hash = AuthRateLimiter.subject_hash("device:" <> device_id)

    attrs = %{
      user_id: user.id,
      device_id_hash: device_hash,
      device_name: clean_device_value(device_attrs["name"], "Unknown device"),
      platform: normalize_platform(device_attrs["platform"]),
      last_seen_at: now,
      idle_expires_at: DateTime.add(now, @refresh_idle_days, :day),
      absolute_expires_at: DateTime.add(now, @session_absolute_days, :day)
    }

    Repo.transact(fn ->
      Repo.update_all(
        from(s in AuthSession,
          where:
            s.user_id == ^user.id and s.device_id_hash == ^device_hash and is_nil(s.revoked_at)
        ),
        set: [revoked_at: now, revoke_reason: "replaced"]
      )

      with {:ok, session} <- Repo.insert(AuthSession.create_changeset(%AuthSession{}, attrs)),
           {:ok, access_token, _claims} <- generate_access_token(user, session),
           {refresh_token, refresh_changeset} <- build_refresh_token(session),
           {:ok, _token} <- Repo.insert(refresh_changeset) do
        record_event("session_created", user.id, session.id)
        {:ok, {session, access_token, refresh_token}}
      end
    end)
  end

  def verify_and_rotate_refresh_token(encoded_token, request_id \\ nil) do
    request_id = normalize_request_id(request_id)

    with {:ok, raw} <- Base.url_decode64(encoded_token, padding: false) do
      hash = :crypto.hash(:sha256, raw)

      case Repo.transact(fn -> rotate_locked(hash, request_id) end) do
        {:ok, result} -> result
        {:error, reason} -> {:error, reason}
      end
    else
      :error -> {:error, :invalid_token}
    end
  end

  def fetch_active_identity(%{"sub" => user_id, "sid" => session_id}) do
    now = DateTime.utc_now(:second)

    query =
      from s in AuthSession,
        join: u in assoc(s, :user),
        where: s.id == ^session_id and s.user_id == ^user_id,
        where: is_nil(s.revoked_at),
        where: s.idle_expires_at > ^now and s.absolute_expires_at > ^now,
        select: {u, s}

    case Repo.one(query) do
      {%User{} = user, %AuthSession{} = session} -> {:ok, user, session}
      nil -> {:error, :invalid_session}
    end
  end

  def list_sessions(%User{id: user_id}) do
    Repo.all(
      from s in AuthSession,
        where: s.user_id == ^user_id and is_nil(s.revoked_at),
        order_by: [desc: s.last_seen_at]
    )
  end

  def revoke_session(%User{id: user_id}, session_id, reason \\ "user_revoked") do
    now = DateTime.utc_now(:second)

    case Repo.one(from s in AuthSession, where: s.id == ^session_id and s.user_id == ^user_id) do
      nil ->
        {:error, :not_found}

      session ->
        Repo.transact(fn ->
          revoke_session_records(session.id, reason, now)
          record_event("session_revoked", user_id, session.id, %{"reason" => reason})
          {:ok, :ok}
        end)
    end
  end

  def revoke_all_sessions(%User{id: user_id}, reason \\ "user_revoked_all") do
    now = DateTime.utc_now(:second)
    ids = Repo.all(from s in AuthSession, where: s.user_id == ^user_id, select: s.id)

    Repo.transact(fn ->
      Enum.each(ids, &revoke_session_records(&1, reason, now))
      record_event("all_sessions_revoked", user_id, nil, %{"reason" => reason})
      {:ok, :ok}
    end)
  end

  def generate_token_pair(%User{} = user) do
    case create_session(user, %{"platform" => "legacy", "name" => "Legacy client"}) do
      {:ok, {_session, access, refresh}} -> {:ok, access, refresh}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_all_refresh_tokens(%User{} = user),
    do: revoke_all_sessions(user, "legacy_logout_all")

  def delete_refresh_token(encoded_token) do
    with {:ok, raw} <- Base.url_decode64(encoded_token, padding: false),
         %ApiRefreshToken{} = token <-
           Repo.one(from t in ApiRefreshToken, where: t.token_hash == ^:crypto.hash(:sha256, raw)) do
      Repo.update_all(from(t in ApiRefreshToken, where: t.id == ^token.id),
        set: [revoked_at: DateTime.utc_now(:second)]
      )

      :ok
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp rotate_locked(hash, request_id) do
    token =
      Repo.one(
        from t in ApiRefreshToken,
          where: t.token_hash == ^hash,
          preload: [session: :user],
          lock: "FOR UPDATE"
      )

    now = DateTime.utc_now(:second)

    cond do
      is_nil(token) or not is_nil(token.revoked_at) or
          DateTime.compare(token.expires_at, now) != :gt ->
        {:ok, {:error, :invalid_token}}

      not AuthSession.active?(token.session, now) ->
        {:ok, {:error, :invalid_session}}

      is_nil(token.used_at) ->
        rotate_active_token(token, request_id, now)

      (token.rotation_request_id == request_id and token.retry_expires_at) &&
          DateTime.compare(token.retry_expires_at, now) == :gt ->
        retry_rotated_token(token)

      true ->
        revoke_session_records(token.session_id, "refresh_reuse", now)
        record_event("refresh_reuse_detected", token.session.user_id, token.session_id)
        {:ok, {:error, :reuse_detected}}
    end
  end

  defp rotate_active_token(token, request_id, now) do
    {raw_successor, successor_changeset} = build_refresh_token(token.session, token.id)
    retry_ciphertext = encrypt_retry_token(raw_successor)

    with {:ok, _successor} <- Repo.insert(successor_changeset),
         {:ok, _used} <-
           token
           |> Ecto.Changeset.change(%{
             used_at: now,
             rotation_request_id: request_id,
             retry_token_ciphertext: retry_ciphertext,
             retry_expires_at: DateTime.add(now, @retry_seconds, :second)
           })
           |> Repo.update(),
         {:ok, session} <- touch_session(token.session, now),
         {:ok, access, _claims} <- generate_access_token(token.session.user, session) do
      {:ok, {:ok, token.session.user, session, access, raw_successor}}
    end
  end

  defp retry_rotated_token(token) do
    with {:ok, raw_successor} <- decrypt_retry_token(token.retry_token_ciphertext),
         {:ok, access, _claims} <- generate_access_token(token.session.user, token.session) do
      {:ok, {:ok, token.session.user, token.session, access, raw_successor}}
    else
      _ -> {:ok, {:error, :invalid_token}}
    end
  end

  defp build_refresh_token(session, parent_id \\ nil) do
    raw = :crypto.strong_rand_bytes(@rand_size)
    encoded = Base.url_encode64(raw, padding: false)

    changeset =
      ApiRefreshToken.create_changeset(%ApiRefreshToken{}, %{
        session_id: session.id,
        parent_id: parent_id,
        token_hash: :crypto.hash(:sha256, raw),
        expires_at: session.absolute_expires_at
      })

    {encoded, changeset}
  end

  defp touch_session(session, now) do
    idle_expiry = DateTime.add(now, @refresh_idle_days, :day)

    effective_expiry =
      if DateTime.before?(idle_expiry, session.absolute_expires_at),
        do: idle_expiry,
        else: session.absolute_expires_at

    session
    |> Ecto.Changeset.change(last_seen_at: now, idle_expires_at: effective_expiry)
    |> Repo.update()
  end

  defp revoke_session_records(session_id, reason, now) do
    Repo.update_all(from(s in AuthSession, where: s.id == ^session_id and is_nil(s.revoked_at)),
      set: [revoked_at: now, revoke_reason: reason]
    )

    Repo.update_all(
      from(t in ApiRefreshToken, where: t.session_id == ^session_id and is_nil(t.revoked_at)),
      set: [revoked_at: now]
    )
  end

  defp record_event(event, user_id, session_id, metadata \\ %{}) do
    Repo.insert!(%AuthSecurityEvent{
      event: event,
      user_id: user_id,
      session_id: session_id,
      metadata: metadata
    })
  end

  defp encrypt_retry_token(token) do
    {secret, sign_secret} = retry_secrets()
    Plug.Crypto.MessageEncryptor.encrypt(token, secret, sign_secret)
  end

  defp decrypt_retry_token(token) do
    {secret, sign_secret} = retry_secrets()
    Plug.Crypto.MessageEncryptor.decrypt(token, secret, sign_secret)
  end

  defp retry_secrets do
    base = Application.fetch_env!(:awrad_api, __MODULE__)[:refresh_retry_secret]
    {:crypto.hash(:sha256, base <> ":encrypt"), :crypto.hash(:sha256, base <> ":sign")}
  end

  defp signing_secret, do: Application.fetch_env!(:awrad_api, __MODULE__)[:signing_secret]
  defp normalize_request_id(nil), do: Ecto.UUID.generate()

  defp normalize_request_id(value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> uuid
      :error -> Ecto.UUID.generate()
    end
  end

  defp normalize_platform(value) when value in ["android", "ios"], do: value
  defp normalize_platform(_), do: "legacy"

  defp clean_device_value(value, _fallback) when is_binary(value),
    do: value |> String.trim() |> String.slice(0, 120)

  defp clean_device_value(_, fallback), do: fallback
end
