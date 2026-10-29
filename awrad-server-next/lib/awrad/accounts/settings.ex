defmodule Awrad.Accounts.Settings do
  @moduledoc """
  Sensitive changes to a signed-in account (slice 2b), each confirmed with the
  current password (`current_password_incorrect` otherwise):

    * `change_password/4` sets a new password, ends every other session of
      both kinds and keeps the caller's; the account's email gets a notice.
    * `request_email_change/4` sends a code to the new address, or, when that
      address already has an account, a notice instead (the response is the
      same); a new request cancels the previous code.
    * `confirm_email_change/3` switches the email with that code, keeps the
      sessions, and tells the old address.
    * `delete/3` deletes the account and everything stored for it (the
      database cascades from `users`), which ends every session; the address
      gets a confirmation. Its recordings are left to the audio cleanup job,
      which deletes every object soon after (`Awrad.Audio.account_deleted/0`).

  Emails are localized in `locale`, the request's language.
  """

  import Ecto.Query

  alias Awrad.Accounts.{
    AccountSessions,
    DeletedRefreshToken,
    EmailCode,
    Input,
    RateLimiter,
    Scope,
    User,
    UserNotifier
  }

  alias Awrad.Repo

  @doc "Changes the password; every other session ends, the caller's stays."
  @spec change_password(Scope.t(), term(), term(), String.t()) :: :ok | Input.validation_error()
  def change_password(%Scope{user: user} = scope, current_password, new_password, locale) do
    with {:ok, values} <-
           Input.collect(
             current_password: check_password(user, current_password),
             new_password: Input.new_password(new_password)
           ) do
      hashed_password = User.hash(values.new_password)

      {:ok, :ok} =
        Repo.transact(fn ->
          user |> Ecto.Changeset.change(hashed_password: hashed_password) |> Repo.update!()
          :ok = AccountSessions.end_others(scope, "password_changed")
          # A pending reset code would set a password nobody asked for any more.
          {:ok, EmailCode.delete(user, :reset_password)}
        end)

      UserNotifier.deliver_notice(user.email, :password_changed, locale)
    end
  end

  @doc """
  Starts an email change: a code to `new_email`, or a notice there when it
  already belongs to an account. `:ok` either way for a valid request.
  """
  @spec request_email_change(Scope.t(), term(), term(), String.t()) ::
          :ok | Input.validation_error()
  def request_email_change(%Scope{user: user}, current_password, new_email, locale) do
    with {:ok, values} <-
           Input.collect(
             current_password: check_password(user, current_password),
             new_email: new_email(user, new_email)
           ) do
      %{new_email: new_email} = values
      :ok = EmailCode.delete(user, :change_email)

      if Repo.exists?(from(u in User, where: u.email == ^new_email)) do
        UserNotifier.deliver_notice(new_email, :email_taken, locale)
      else
        code = EmailCode.issue(user, :change_email, new_email)
        UserNotifier.deliver_code(new_email, :change_email, code, locale)
      end
    end
  end

  @doc """
  Switches the account's email to the address the code was sent to. Errors:
  `:code_invalid` (wrong, expired, spent or missing code), `:email_taken` (the
  address got an account in the meantime; the code stays usable), or field
  errors.
  """
  @spec confirm_email_change(Scope.t(), term(), String.t()) ::
          {:ok, User.t()} | {:error, :code_invalid | :email_taken} | Input.validation_error()
  def confirm_email_change(%Scope{user: user}, code, locale) do
    with {:ok, %{code: code}} <- Input.collect(code: Input.code(code)),
         {:ok, updated} <-
           EmailCode.consume(user, :change_email, code, &switch_email(user, &1)) do
      UserNotifier.deliver_notice(user.email, :email_changed, locale, new_email: updated.email)
      {:ok, updated}
    end
  end

  @doc "Deletes the account and everything stored for it. Every session ends."
  @spec delete(Scope.t(), term(), String.t()) :: :ok | Input.validation_error()
  def delete(%Scope{user: user}, current_password, locale) do
    with {:ok, _values} <- Input.collect(current_password: check_password(user, current_password)) do
      {:ok, :ok} =
        Repo.transact(fn ->
          :ok = RateLimiter.delete_account_windows(user.id)
          # Its live refresh tokens answer `account_deleted` from now on (ADR 0010).
          :ok = DeletedRefreshToken.remember(user.id, DateTime.utc_now(:second))
          # Every table that keeps account data references users ON DELETE CASCADE.
          Repo.delete_all(from(u in User, where: u.id == ^user.id))
          {:ok, :ok}
        end)

      # Its recordings outlive the row only as cleanup work (`audio_assets.user_id`
      # is set to NULL); the job deletes every object, retrying when R2 fails.
      :ok = Awrad.Audio.account_deleted()

      UserNotifier.deliver_notice(user.email, :account_deleted, locale)
    end
  end

  # The current password, re-entered. Out-of-bounds input is never hashed, but
  # costs the same Argon2 work.
  defp check_password(user, password) do
    case Input.sign_in_password(password) do
      {:ok, password} ->
        if User.valid_password?(user, password),
          do: :ok,
          else: {:error, :current_password_incorrect}

      {:error, _bounds} ->
        Argon2.no_user_verify()
        {:error, :current_password_incorrect}
    end
  end

  defp new_email(user, input) do
    with {:ok, email} <- Input.email(input) do
      if String.downcase(email) == String.downcase(user.email),
        do: {:error, :email_unchanged},
        else: {:ok, email}
    end
  end

  defp switch_email(user, new_email) do
    taken? = Repo.exists?(from(u in User, where: u.email == ^new_email and u.id != ^user.id))

    with false <- taken?,
         {:ok, updated} <-
           user
           |> Ecto.Changeset.change(email: new_email)
           |> Ecto.Changeset.unique_constraint(:email)
           |> Repo.update() do
      # A reset code sent to the old address mustn't work for the new one.
      :ok = EmailCode.delete(updated, :reset_password)
      {:ok, updated}
    else
      _taken -> {:error, :email_taken}
    end
  end
end
