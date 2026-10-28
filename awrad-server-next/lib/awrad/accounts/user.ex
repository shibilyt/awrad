defmodule Awrad.Accounts.User do
  @moduledoc """
  An account (`CONTEXT.md`): an email and a password, usable once the email is
  verified (`confirmed_at`).

  Based on the `phx.gen.auth` schema (ADR-2026-10-15). Deliberate changes: the
  generated email and password changesets are gone, because input is checked
  by the shared rules (`Awrad.Accounts.Input`, `EmailInput`, `PasswordPolicy`)
  before anything is written, and passwords are hashed in NFC form.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Awrad.Accounts.PasswordPolicy

  @primary_key {:id, Awrad.UUIDv7, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          email: String.t() | nil,
          password: String.t() | nil,
          hashed_password: String.t() | nil,
          confirmed_at: DateTime.t() | nil,
          authenticated_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc "Hashes a password (Argon2id) in its NFC form."
  @spec hash(String.t()) :: String.t()
  def hash(password) do
    case password |> PasswordPolicy.normalize() |> Argon2.hash_pwd_salt() do
      hash when is_binary(hash) -> hash
    end
  end

  @doc "Confirms the account by setting `confirmed_at`."
  @spec confirm_changeset(t()) :: Ecto.Changeset.t()
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Argon2.no_user_verify/0` to avoid timing attacks.
  """
  @spec valid_password?(t() | nil, String.t()) :: boolean()
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Argon2.verify_pass(PasswordPolicy.normalize(password), hashed_password)
  end

  def valid_password?(_user, _password) do
    Argon2.no_user_verify()
    false
  end
end
