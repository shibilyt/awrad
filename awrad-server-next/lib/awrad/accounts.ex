defmodule Awrad.Accounts do
  @moduledoc """
  Accounts (slice 2a): registration, email verification and password reset by
  emailed code, sign-in, mobile device sessions and browser session tokens.
  Account settings (slice 2b): the session list, password and email changes,
  and account deletion.

  The only entry point to the context. Mobile and browser credentials resolve
  to the same accounts through separate functions (`identify_device_session/1`,
  `get_user_by_session_token/1`), and neither accepts the other's credential
  (ADR-2026-10-15).

  Functions that take request values validate them and return
  `{:error, {:validation, [{field, code}]}}` with every field error.
  """

  use Boundary,
    deps: [Awrad, Awrad.Audio, Awrad.Secrets],
    exports: [DeviceSession, EmailInput, Grant, RateLimiter, Scope, User]

  alias Awrad.Accounts.{
    AccountSessions,
    BrowserSessions,
    DeletedRefreshToken,
    DeviceSession,
    DeviceSessions,
    EmailCode,
    Grant,
    Input,
    PasswordReset,
    RateLimiter,
    Registration,
    Scope,
    Settings,
    User
  }

  alias Awrad.Repo

  @type validation_error :: Input.validation_error()

  @typedoc "One entry of the account's session list (`list_account_sessions/3`)."
  @type account_session :: AccountSessions.item()

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
          | {:error,
             :refresh_token_invalid
             | :refresh_reuse_detected
             | :idempotency_key_reused
             | :account_deleted}
  defdelegate refresh_device_session(refresh_token, key), to: DeviceSessions, as: :refresh

  @doc "Revokes the session owning a refresh token. Always `:ok`."
  @spec sign_out_device_session(String.t()) :: :ok
  defdelegate sign_out_device_session(refresh_token), to: DeviceSessions, as: :sign_out

  @doc "The account and live device session of a mobile access token."
  @spec identify_device_session(String.t()) :: {:ok, User.t(), DeviceSession.t()} | :error
  defdelegate identify_device_session(access_token), to: DeviceSessions, as: :identify

  ## Browser sessions (phx.gen.auth)

  @doc """
  Generates a session token for a browser called `name` ("Firefox on
  Windows", or `nil` when unknown).
  """
  @spec generate_user_session_token(User.t(), String.t() | nil) :: binary()
  def generate_user_session_token(user, name \\ nil), do: BrowserSessions.create(user, name)

  @doc """
  Gets the user and browser session of a session token, or `nil`. Updates the
  session's `last_seen_at` at most every 5 minutes. The returned session's
  `token` is its current one, which differs from `token` for a minute after a
  reissue.
  """
  @spec get_user_by_session_token(binary()) :: {User.t(), BrowserSessions.session()} | nil
  defdelegate get_user_by_session_token(token), to: BrowserSessions, as: :identify

  @doc "Replaces a browser session's token, keeping the session; returns the token to use."
  @spec reissue_user_session_token(Ecto.UUID.t(), binary()) :: binary() | nil
  defdelegate reissue_user_session_token(session_id, token), to: BrowserSessions, as: :reissue

  @doc """
  Deletes the signed token with the given context.
  """
  @spec delete_user_session_token(binary()) :: :ok
  defdelegate delete_user_session_token(token), to: BrowserSessions, as: :delete_token

  ## Account settings (slice 2b)

  @doc "One page of the account's device and browser sessions, most recently used first."
  @spec list_account_sessions(Scope.t(), String.t() | nil, pos_integer() | nil) ::
          {:ok, AccountSessions.page()} | {:error, :cursor_invalid}
  defdelegate list_account_sessions(scope, cursor, limit), to: AccountSessions, as: :list

  @doc "Ends one of the account's sessions. `:not_found` unless it's a live session of the account."
  @spec revoke_account_session(Scope.t(), String.t()) :: :ok | :not_found
  defdelegate revoke_account_session(scope, session_id), to: AccountSessions, as: :revoke

  @doc "Ends every session of the account except the caller's."
  @spec revoke_other_account_sessions(Scope.t()) :: :ok
  defdelegate revoke_other_account_sessions(scope), to: AccountSessions, as: :revoke_others

  @doc "Changes the password with the current one; other sessions end, the caller's stays."
  @spec change_password(Scope.t(), term(), term(), String.t()) :: :ok | validation_error()
  defdelegate change_password(scope, current_password, new_password, locale), to: Settings

  @doc "Starts an email change: a code to the new address (or a notice, if it's taken)."
  @spec request_email_change(Scope.t(), term(), term(), String.t()) :: :ok | validation_error()
  defdelegate request_email_change(scope, current_password, new_email, locale), to: Settings

  @doc "Switches the email with the code sent to the new address."
  @spec confirm_email_change(Scope.t(), term(), String.t()) ::
          {:ok, User.t()} | {:error, :code_invalid | :email_taken} | validation_error()
  defdelegate confirm_email_change(scope, code, locale), to: Settings

  @doc "Deletes the account and everything stored for it, with the current password."
  @spec delete_account(Scope.t(), term(), String.t()) :: :ok | validation_error()
  defdelegate delete_account(scope, current_password, locale), to: Settings, as: :delete

  ## Housekeeping

  @doc """
  Deletes expired email codes, old rate-limit windows and expired deleted-account
  refresh tokens. Returns how many rows went.
  """
  @spec prune(DateTime.t()) :: non_neg_integer()
  def prune(now),
    do: EmailCode.prune(now) + RateLimiter.prune(now) + DeletedRefreshToken.prune(now)
end
