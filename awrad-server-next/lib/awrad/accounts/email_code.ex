defmodule Awrad.Accounts.EmailCode do
  @moduledoc """
  A 6-digit emailed code (`CONTEXT.md`, root ADR-2026-10-26) that verifies an
  account's email, resets its password, or confirms a new email address.

    * Stored only as an HMAC (`Awrad.Secrets.hmac/2`) bound to the account,
      the purpose and, for an email change, the new address (`new_email`); the
      code itself exists only in the email.
    * Lasts 15 minutes and allows 5 tries; the 5th wrong try spends it.
    * One live code per account and purpose: issuing a new one replaces
      (cancels) the old one.
  """

  use Ecto.Schema

  import Ecto.Query

  alias Awrad.Accounts.User
  alias Awrad.{Repo, Secrets}

  @validity_minutes 15
  @max_attempts 5

  @primary_key {:id, Awrad.UUIDv7, autogenerate: true}
  @foreign_key_type :binary_id

  @type purpose :: :verify_email | :reset_password | :change_email
  @type t :: %__MODULE__{}
  @type on_match ::
          (-> {:ok, term()} | {:error, term()})
          | (String.t() | nil -> {:ok, term()} | {:error, term()})

  schema "email_codes" do
    field :purpose, Ecto.Enum, values: [:verify_email, :reset_password, :change_email]
    field :code_hash, :binary, redact: true
    field :new_email, :string
    field :attempts, :integer, default: 0
    field :expires_at, :utc_datetime
    belongs_to :user, User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "Minutes a code stays valid."
  @spec validity_minutes() :: 15
  def validity_minutes, do: @validity_minutes

  @doc """
  Issues a new code for `user` and `purpose`, cancelling any earlier one, and
  returns it. `new_email` is the address an email change switches to.
  """
  @spec issue(User.t(), purpose(), String.t() | nil) :: String.t()
  def issue(%User{} = user, purpose, new_email \\ nil) do
    code = generate()
    now = DateTime.utc_now(:second)

    row = %__MODULE__{
      user_id: user.id,
      purpose: purpose,
      code_hash: hash(user, purpose, new_email, code),
      new_email: new_email,
      attempts: 0,
      expires_at: DateTime.add(now, @validity_minutes, :minute),
      inserted_at: now
    }

    Repo.insert!(row,
      on_conflict: {:replace, [:code_hash, :new_email, :attempts, :expires_at, :inserted_at]},
      conflict_target: [:user_id, :purpose]
    )

    code
  end

  @doc """
  Checks `code` and, when it matches, deletes it and runs `on_match` in the same
  transaction (with the code's `new_email` when it takes an argument). A wrong
  code counts a try, and that try is kept even though the call fails. When
  `on_match` fails, nothing it did is kept and the code stays as it was.

  Returns `on_match`'s `{:ok, value}`, its `{:error, reason}`, or
  `{:error, :code_invalid}` for a wrong, expired, spent or missing code.
  """
  @spec consume(User.t(), purpose(), String.t(), on_match()) ::
          {:ok, term()} | {:error, term()}
  def consume(%User{} = user, purpose, code, on_match)
      when is_function(on_match, 0) or is_function(on_match, 1) do
    result = Repo.transact(fn -> check_locked(user, purpose, code, on_match) end)

    case result do
      {:ok, :code_invalid} -> {:error, :code_invalid}
      other -> other
    end
  end

  @doc "Deletes the code of `user` for `purpose`, if any (cancels it)."
  @spec delete(User.t(), purpose()) :: :ok
  def delete(%User{id: user_id}, purpose) do
    Repo.delete_all(from(c in __MODULE__, where: c.user_id == ^user_id and c.purpose == ^purpose))
    :ok
  end

  @doc "Deletes every code of `user` (after a password reset, for example)."
  @spec delete_all(User.t()) :: :ok
  def delete_all(%User{id: user_id}) do
    Repo.delete_all(from(c in __MODULE__, where: c.user_id == ^user_id))
    :ok
  end

  @doc "Deletes codes that expired before `now`. Returns how many."
  @spec prune(DateTime.t()) :: non_neg_integer()
  def prune(now) do
    {count, _} = Repo.delete_all(from(c in __MODULE__, where: c.expires_at <= ^now))
    count
  end

  defp check_locked(user, purpose, code, on_match) do
    now = DateTime.utc_now(:second)

    case lock_row(user, purpose) do
      nil ->
        {:ok, :code_invalid}

      row ->
        if usable?(row, now) and matches?(row, user, purpose, code) do
          Repo.delete!(row)
          run(on_match, row)
        else
          count_try(row)
          {:ok, :code_invalid}
        end
    end
  end

  defp run(on_match, _row) when is_function(on_match, 0), do: on_match.()
  defp run(on_match, row) when is_function(on_match, 1), do: on_match.(row.new_email)

  defp lock_row(user, purpose) do
    Repo.one(
      from c in __MODULE__,
        where: c.user_id == ^user.id and c.purpose == ^purpose,
        lock: "FOR UPDATE"
    )
  end

  defp usable?(row, now),
    do: row.attempts < @max_attempts and DateTime.after?(row.expires_at, now)

  defp matches?(row, user, purpose, code),
    do: Plug.Crypto.secure_compare(row.code_hash, hash(user, purpose, row.new_email, code))

  # A spent code stays until it expires, so later tries keep failing.
  defp count_try(row) do
    Repo.update_all(from(c in __MODULE__, where: c.id == ^row.id), inc: [attempts: 1])
  end

  defp hash(user, purpose, nil, code),
    do: Secrets.hmac("email_code", [user.id, ":", Atom.to_string(purpose), ":", code])

  # The new address is part of the HMAC, so a stored code only confirms the
  # address it was sent to.
  defp hash(user, purpose, new_email, code) do
    Secrets.hmac("email_code", [
      user.id,
      ":",
      Atom.to_string(purpose),
      ":",
      String.downcase(new_email),
      ":",
      code
    ])
  end

  # Uniform over 000000..999999: 64 random bits make the modulo bias negligible.
  defp generate do
    <<n::unsigned-64>> = :crypto.strong_rand_bytes(8)
    n |> rem(1_000_000) |> Integer.to_string() |> String.pad_leading(6, "0")
  end
end
