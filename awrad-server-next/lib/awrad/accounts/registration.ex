defmodule Awrad.Accounts.Registration do
  @moduledoc """
  Verification-first registration (ADR-2026-07-12, root ADR-2026-10-26).

    * `register/3` creates an unverified account and emails a code. It answers
      the same for a new email, an unverified one and a verified one, and does
      the same slow work (one Argon2 hash) in each case.
    * Registering an email that exists but isn't verified yet replaces its
      password and sends a new code: the inbox owner's latest registration
      wins, so nobody can pre-register someone else's email with a password
      they keep. A verified account is left untouched and gets no email.
    * `verify_email/2` checks the code; it doesn't sign in.
  """

  import Ecto.Query

  alias Awrad.Accounts.{EmailCode, Input, User, UserNotifier}
  alias Awrad.Repo

  @doc "Registers `email` with `password`. `:ok` whether or not the email has an account."
  @spec register(term(), term(), String.t()) :: :ok | Input.validation_error()
  def register(email, password, locale) do
    with {:ok, values} <-
           Input.collect(email: Input.email(email), password: Input.new_password(password)) do
      %{email: email, password: password} = values

      # Hashed before looking the email up, so every path costs the same.
      hashed_password = User.hash(password)

      {:ok, outcome} = Repo.transact(fn -> create_or_refresh(email, hashed_password) end)

      with {:send, user, code} <- outcome do
        UserNotifier.deliver_code(user.email, :verify_email, code, locale)
      end

      :ok
    end
  end

  defp create_or_refresh(email, hashed_password) do
    case lock_by_email(email) do
      nil -> insert(email, hashed_password)
      %User{confirmed_at: nil} = user -> replace_password(user, hashed_password)
      %User{} -> {:ok, :exists}
    end
  end

  @doc """
  Verifies the email of the account `email` with `code`. Errors:
  `:code_invalid` for a wrong, expired, spent or missing code, or an unknown
  email.
  """
  @spec verify_email(term(), term()) :: :ok | {:error, :code_invalid} | Input.validation_error()
  def verify_email(email, code) do
    with {:ok, values} <-
           Input.collect(email: Input.email(email), code: Input.code(code)),
         %{email: email, code: code} = values,
         %User{} = user <- Repo.get_by(User, email: email) || {:error, :code_invalid},
         {:ok, _user} <- EmailCode.consume(user, :verify_email, code, fn -> confirm(user) end) do
      :ok
    end
  end

  @doc "Emails a new verification code if `email` has an unverified account. Always `:ok` for a valid email."
  @spec resend_verification_code(term(), String.t()) :: :ok | Input.validation_error()
  def resend_verification_code(email, locale) do
    with {:ok, values} <- Input.collect(email: Input.email(email)) do
      %{email: email} = values

      case Repo.get_by(User, email: email) do
        %User{confirmed_at: nil} = user -> send_verification_code(user, locale)
        _verified_or_unknown -> :ok
      end
    end
  end

  @doc "Issues and emails a verification code to `user`."
  @spec send_verification_code(User.t(), String.t()) :: :ok
  def send_verification_code(%User{} = user, locale) do
    code = EmailCode.issue(user, :verify_email)
    UserNotifier.deliver_code(user.email, :verify_email, code, locale)
  end

  defp lock_by_email(email) do
    Repo.one(from u in User, where: u.email == ^email, lock: "FOR UPDATE")
  end

  defp insert(email, hashed_password) do
    now = DateTime.utc_now(:second)

    row = %{
      id: Ecto.UUID.generate(),
      email: email,
      hashed_password: hashed_password,
      inserted_at: now,
      updated_at: now
    }

    # ON CONFLICT DO NOTHING: a concurrent registration of the same email wins,
    # and this one answers the same way without aborting the transaction.
    case Repo.insert_all(User, [row], on_conflict: :nothing, conflict_target: :email) do
      {1, _} ->
        user = Repo.get!(User, row.id)
        {:ok, {:send, user, EmailCode.issue(user, :verify_email)}}

      {0, _} ->
        {:ok, :exists}
    end
  end

  defp replace_password(user, hashed_password) do
    user = user |> Ecto.Changeset.change(hashed_password: hashed_password) |> Repo.update!()
    {:ok, {:send, user, EmailCode.issue(user, :verify_email)}}
  end

  defp confirm(%User{confirmed_at: nil} = user),
    do: user |> User.confirm_changeset() |> Repo.update()

  defp confirm(%User{} = user), do: {:ok, user}
end
