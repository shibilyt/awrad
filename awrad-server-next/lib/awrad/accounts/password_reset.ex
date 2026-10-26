defmodule Awrad.Accounts.PasswordReset do
  @moduledoc """
  Password reset by emailed code (root ADR-2026-10-26).

  A successful reset, in one transaction:
    * sets the new password;
    * verifies the email (the code proves the inbox);
    * revokes **every** session: device sessions and their refresh tokens
      (`password_reset`), and browser session tokens (`users_tokens`);
    * deletes the account's other email codes.
  """

  import Ecto.Query

  alias Awrad.Accounts.{DeviceSessions, EmailCode, Input, User, UserNotifier, UserToken}
  alias Awrad.Repo

  @doc "Emails a reset code if `email` has an account. Always `:ok` for a valid email."
  @spec request(term(), String.t()) :: :ok | Input.validation_error()
  def request(email, locale) do
    with {:ok, values} <- Input.collect(email: Input.email(email)) do
      %{email: email} = values

      case Repo.get_by(User, email: email) do
        %User{} = user ->
          code = EmailCode.issue(user, :reset_password)
          UserNotifier.deliver_code(user.email, :reset_password, code, locale)

        nil ->
          :ok
      end
    end
  end

  @doc """
  Sets `new_password` for the account `email` if `code` is its reset code.
  Errors: `:code_invalid` (wrong, expired, spent or missing code, or an unknown
  email), or field errors.
  """
  @spec reset(term(), term(), term()) :: :ok | {:error, :code_invalid} | Input.validation_error()
  def reset(email, code, new_password) do
    with {:ok, values} <-
           Input.collect(
             email: Input.email(email),
             code: Input.code(code),
             new_password: Input.new_password(new_password)
           ),
         %{email: email, code: code, new_password: new_password} = values,
         %User{} = user <- Repo.get_by(User, email: email) || {:error, :code_invalid},
         # Hashed before the code check, so a wrong code costs the same time.
         hashed_password = User.hash(new_password),
         {:ok, _user} <-
           EmailCode.consume(user, :reset_password, code, fn ->
             apply_reset(user, hashed_password)
           end) do
      :ok
    end
  end

  defp apply_reset(user, hashed_password) do
    confirmed_at = user.confirmed_at || DateTime.utc_now(:second)

    user =
      user
      |> Ecto.Changeset.change(hashed_password: hashed_password, confirmed_at: confirmed_at)
      |> Repo.update!()

    Repo.delete_all(from(t in UserToken, where: t.user_id == ^user.id))
    :ok = DeviceSessions.revoke_all(user, "password_reset")
    :ok = EmailCode.delete_all(user)
    {:ok, user}
  end
end
