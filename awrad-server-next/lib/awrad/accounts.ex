defmodule Awrad.Accounts do
  @moduledoc """
  Accounts (slice 2a): registration, email verification and password reset by
  emailed code, sign-in, mobile device sessions and browser session tokens.

  The only entry point to the context. Mobile and browser credentials resolve
  to the same accounts through separate functions (`identify_device_session/1`,
  `get_user_by_session_token/1`), and neither accepts the other's credential
  (ADR-2026-10-15).

  Functions that take request values validate them and return
  `{:error, {:validation, [{field, code}]}}` with every field error.
  """

  use Boundary,
    deps: [Awrad, Awrad.Secrets],
    exports: [DeviceSession, EmailInput, Grant, RateLimiter, Scope, User]

  import Ecto.Query

  alias Awrad.Accounts.{
    DeviceSession,
    DeviceSessions,
    EmailCode,
    Grant,
    Input,
    PasswordReset,
    RateLimiter,
    Registration,
    User,
    UserToken
  }

  alias Awrad.Repo

  @type validation_error :: Input.validation_error()

  ## Registration, verification and reset

  @doc "Creates an unverified account and emails a code. `:ok` whether or not the email has an account."
  @spec register(term(), term(), String.t()) :: :ok | validation_error()
  defdelegate register(email, password, locale), to: Registration

  @doc "Verifies an account's email with its emailed code. Doesn't sign in."
  @spec verify_email(term(), term()) :: :ok | {:error, :code_invalid} | validation_error()
  defdelegate verify_email(email, code), to: Registration

  @doc "Emails a new verification code to an unverified account. Always `:ok` for a valid email."
  @spec resend_verification_code(term(), String.t()) :: :ok | validation_error()
  defdelegate resend_verification_code(email, locale), to: Registration

  @doc "Emails a password-reset code to an account. Always `:ok` for a valid email."
  @spec request_password_reset(term(), String.t()) :: :ok | validation_error()
  defdelegate request_password_reset(email, locale), to: PasswordReset, as: :request

  @doc "Sets a new password with the emailed reset code, verifies the email and revokes every session."
  @spec reset_password(term(), term(), term()) ::
          :ok | {:error, :code_invalid} | validation_error()
  defdelegate reset_password(email, code, new_password), to: PasswordReset, as: :reset

  ## Sign-in

  @doc """
  Checks an email and password.

  A right password on an unverified account is
  `{:error, :email_verification_required}`, and a fresh verification code is
  emailed (at most 5 an hour per account). A wrong email or password is
  `{:error, :invalid_credentials}`, with the same Argon2 work either way.
  """
  @spec authenticate(term(), term(), String.t()) ::
          {:ok, User.t()}
          | {:error, :invalid_credentials | :email_verification_required}
          | validation_error()
  def authenticate(email, password, locale) do
    with {:ok, values} <-
           Input.collect(email: Input.email(email), password: Input.sign_in_password(password)) do
      %{email: email, password: password} = values

      user = Repo.get_by(User, email: email)

      cond do
        not User.valid_password?(user, password) ->
          {:error, :invalid_credentials}

        is_nil(user.confirmed_at) ->
          send_fresh_verification_code(user, locale)
          {:error, :email_verification_required}

        true ->
          {:ok, user}
      end
    end
  end

  # A sign-in to an unverified account emails a fresh code, at most 5 an hour.
  defp send_fresh_verification_code(user, locale) do
    with :ok <- RateLimiter.check(:verification_email, nil, user.id) do
      Registration.send_verification_code(user, locale)
    end
  end

  @doc """
  Signs in on a mobile installation: checks the device, then the credentials,
  then creates the device session (replacing the installation's earlier one).
  """
  @spec create_device_session(term(), term(), map(), String.t()) ::
          {:ok, Grant.t()}
          | {:error, :invalid_credentials | :email_verification_required}
          | validation_error()
  def create_device_session(email, password, device, locale) when is_map(device) do
    with {:ok, device} <- device(device),
         {:ok, user} <- authenticate(email, password, locale) do
      {:ok, DeviceSessions.create(user, device)}
    end
  end

  defp device(device) do
    with {:ok, values} <-
           Input.collect(
             installation_id: Input.installation_id(device[:installation_id]),
             device_name: Input.device_name(device[:name]),
             platform: Input.platform(device[:platform])
           ) do
      {:ok,
       %{
         installation_id: values.installation_id,
         name: values.device_name,
         platform: values.platform
       }}
    end
  end

  ## Mobile device sessions

  @doc "Rotates a refresh token. `key` is the request's required `Idempotency-Key`."
  @spec refresh_device_session(String.t(), Ecto.UUID.t()) ::
          {:ok, Grant.t()}
          | {:error, :refresh_token_invalid | :refresh_reuse_detected | :idempotency_key_reused}
  defdelegate refresh_device_session(refresh_token, key), to: DeviceSessions, as: :refresh

  @doc "Revokes the session owning a refresh token. Always `:ok`."
  @spec sign_out_device_session(String.t()) :: :ok
  defdelegate sign_out_device_session(refresh_token), to: DeviceSessions, as: :sign_out

  @doc "The account and live device session of a mobile access token."
  @spec identify_device_session(String.t()) :: {:ok, User.t(), DeviceSession.t()} | :error
  defdelegate identify_device_session(access_token), to: DeviceSessions, as: :identify

  ## Browser sessions (phx.gen.auth)

  @doc """
  Generates a session token.
  """
  @spec generate_user_session_token(User.t()) :: binary()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  @spec get_user_by_session_token(binary()) :: {User.t(), DateTime.t()} | nil
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  @spec delete_user_session_token(binary()) :: :ok
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Housekeeping

  @doc "Deletes expired email codes and old rate-limit windows. Returns how many rows went."
  @spec prune(DateTime.t()) :: non_neg_integer()
  def prune(now), do: EmailCode.prune(now) + RateLimiter.prune(now)
end
