defmodule AwradApi.Accounts.Token do
  @moduledoc """
  Handles JWT access tokens and DB-backed refresh tokens for API auth.

  - Access tokens: short-lived JWTs (15 min), stateless
  - Refresh tokens: long-lived (180 days), stored hashed in DB, rotated on use
  """

  use Joken.Config

  alias AwradApi.Accounts.UserToken
  alias AwradApi.Repo

  import Ecto.Query

  @access_token_expiry_seconds 15 * 60
  @refresh_token_validity_in_days 180
  @hash_algorithm :sha256
  @rand_size 32

  # --- JWT Access Tokens ---

  @impl Joken.Config
  def token_config do
    default_claims(default_exp: @access_token_expiry_seconds, iss: "awrad_api", aud: "awrad_api")
  end

  defp signing_secret do
    Application.fetch_env!(:awrad_api, __MODULE__)[:signing_secret]
  end

  @doc """
  Generates a signed JWT access token for the given user.
  Returns `{:ok, token, claims}` or `{:error, reason}`.
  """
  def generate_access_token(user) do
    signer = Joken.Signer.create("HS256", signing_secret())
    extra_claims = %{"sub" => user.id}
    generate_and_sign(extra_claims, signer)
  end

  @doc """
  Verifies a JWT access token and returns `{:ok, claims}` or `{:error, reason}`.
  """
  def verify_access_token(token) do
    signer = Joken.Signer.create("HS256", signing_secret())
    verify_and_validate(token, signer)
  end

  # --- Refresh Tokens (DB-backed) ---

  @doc """
  Generates a refresh token for the given user.
  Returns `{raw_token, user_token}` where `raw_token` is the base64-encoded
  token to send to the client, and `user_token` is the Ecto struct to insert.
  """
  def build_refresh_token(user) do
    raw = :crypto.strong_rand_bytes(@rand_size)
    hashed = :crypto.hash(@hash_algorithm, raw)

    encoded = Base.url_encode64(raw, padding: false)

    user_token = %UserToken{
      token: hashed,
      context: "refresh",
      user_id: user.id
    }

    {encoded, user_token}
  end

  @doc """
  Verifies a refresh token and returns the associated user, or nil.
  Deletes the used refresh token (for rotation).
  """
  def verify_and_rotate_refresh_token(encoded_token) do
    with {:ok, raw} <- Base.url_decode64(encoded_token, padding: false) do
      hashed = :crypto.hash(@hash_algorithm, raw)

      query =
        from t in UserToken,
          where: t.token == ^hashed and t.context == "refresh",
          where: t.inserted_at > ago(@refresh_token_validity_in_days, "day"),
          join: u in assoc(t, :user),
          select: {u, t}

      case Repo.one(query) do
        {user, token} ->
          Repo.delete!(token)
          {:ok, user}

        nil ->
          {:error, :invalid_token}
      end
    else
      :error -> {:error, :invalid_token}
    end
  end

  @doc """
  Generates both access and refresh tokens for a user.
  Inserts the refresh token into the DB.
  Returns `{:ok, access_token, refresh_token}` or `{:error, reason}`.
  """
  def generate_token_pair(user) do
    with {:ok, access_token, _claims} <- generate_access_token(user) do
      {refresh_token, user_token} = build_refresh_token(user)
      Repo.insert!(user_token)
      {:ok, access_token, refresh_token}
    end
  end

  @doc """
  Deletes all refresh tokens for a user (e.g., on logout from all devices).
  """
  def delete_all_refresh_tokens(user) do
    Repo.delete_all(
      from t in UserToken,
        where: t.user_id == ^user.id and t.context == "refresh"
    )

    :ok
  end

  @doc """
  Deletes a specific refresh token (e.g., on single-device logout).
  """
  def delete_refresh_token(encoded_token) do
    with {:ok, raw} <- Base.url_decode64(encoded_token, padding: false) do
      hashed = :crypto.hash(@hash_algorithm, raw)

      Repo.delete_all(
        from t in UserToken,
          where: t.token == ^hashed and t.context == "refresh"
      )

      :ok
    else
      :error -> {:error, :invalid_token}
    end
  end
end
