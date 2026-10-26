defmodule Awrad.Accounts.AccessToken do
  @moduledoc """
  Mobile access tokens (ADR-2026-07-12, server ADR 0005): HS256 JWTs signed
  with `Awrad.Secrets.access_token_secret/0`, valid for 15 minutes.

  Claims: `sub` (account ID), `sid` (device session ID), `jti`, `iat`, `nbf`,
  `exp`, `iss` = `"awrad"`, `aud` = `"awrad-mobile"`. A valid signature is
  never enough on its own: `Awrad.Accounts.DeviceSessions.identify/1` checks the
  session in the database on every request.
  """

  alias Awrad.Accounts.{DeviceSession, User}
  alias Awrad.Secrets

  @validity_seconds 15 * 60
  @issuer "awrad"
  @audience "awrad-mobile"

  @doc "Signs an access token for `user` on `session`. Returns the token and its expiry."
  @spec issue(User.t(), DeviceSession.t()) :: {String.t(), DateTime.t()}
  def issue(%User{id: user_id}, %DeviceSession{id: session_id}) do
    {:ok, token, %{"exp" => exp}} =
      Joken.generate_and_sign(token_config(), %{"sub" => user_id, "sid" => session_id}, signer())

    {token, DateTime.from_unix!(exp)}
  end

  @doc """
  Checks the signature, algorithm, issuer, audience and expiry. Returns the
  account and session IDs it names, or `:error`.
  """
  @spec verify(String.t()) :: {:ok, %{user_id: String.t(), session_id: String.t()}} | :error
  def verify(token) when is_binary(token) do
    case Joken.verify_and_validate(token_config(), token, signer()) do
      {:ok, %{"sub" => user_id, "sid" => session_id, "exp" => exp}}
      when is_binary(user_id) and is_binary(session_id) and is_integer(exp) ->
        {:ok, %{user_id: user_id, session_id: session_id}}

      _invalid ->
        :error
    end
  end

  defp token_config do
    Joken.Config.default_claims(
      default_exp: @validity_seconds,
      iss: @issuer,
      aud: @audience
    )
  end

  # verify_strict: only HS256 is accepted, so `alg: none` or RS/HS confusion fails.
  defp signer, do: Joken.Signer.create("HS256", Secrets.access_token_secret())
end
