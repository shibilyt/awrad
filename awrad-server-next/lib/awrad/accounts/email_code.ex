defmodule Awrad.Accounts.EmailCode do
  @moduledoc """
  A 6-digit emailed code (`CONTEXT.md`, root ADR-2026-10-26) that verifies an
  account's email or resets its password.

    * Stored only as an HMAC (`Awrad.Secrets.hmac/2`) bound to the account and
      purpose; the code itself exists only in the email.
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

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type purpose :: :verify_email | :reset_password
  @type t :: %__MODULE__{}

  schema "email_codes" do
    field :purpose, Ecto.Enum, values: [:verify_email, :reset_password]
    field :code_hash, :binary, redact: true
    field :attempts, :integer, default: 0
    field :expires_at, :utc_datetime
    belongs_to :user, User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "Minutes a code stays valid."
  @spec validity_minutes() :: 15
  def validity_minutes, do: @validity_minutes

  @doc "Issues a new code for `user` and `purpose`, cancelling any earlier one. Returns the code."
  @spec issue(User.t(), purpose()) :: String.t()
  def issue(%User{} = user, purpose) do
    code = generate()
    now = DateTime.utc_now(:second)

    row = %__MODULE__{
      user_id: user.id,
      purpose: purpose,
      code_hash: hash(user, purpose, code),
      attempts: 0,
      expires_at: DateTime.add(now, @validity_minutes, :minute),
      inserted_at: now
    }

    Repo.insert!(row,
      on_conflict: {:replace, [:code_hash, :attempts, :expires_at, :inserted_at]},
      conflict_target: [:user_id, :purpose]
    )

    code
  end

  @doc """
  Checks `code` and, when it matches, deletes it and runs `on_match` in the same
  transaction. A wrong code counts a try, and that try is kept even though the
  call fails.

  Returns `on_match`'s `{:ok, value}`, its `{:error, reason}`, or
  `{:error, :code_invalid}` for a wrong, expired, spent or missing code.
  """
  @spec consume(User.t(), purpose(), String.t(), (-> {:ok, term()} | {:error, term()})) ::
          {:ok, term()} | {:error, term()}
  def consume(%User{} = user, purpose, code, on_match) when is_function(on_match, 0) do
    result = Repo.transact(fn -> check_locked(user, purpose, code, on_match) end)

    case result do
      {:ok, :code_invalid} -> {:error, :code_invalid}
      other -> other
    end
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
          on_match.()
        else
          count_try(row)
          {:ok, :code_invalid}
        end
    end
  end

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
    do: Plug.Crypto.secure_compare(row.code_hash, hash(user, purpose, code))

  # A spent code stays until it expires, so later tries keep failing.
  defp count_try(row) do
    Repo.update_all(from(c in __MODULE__, where: c.id == ^row.id), inc: [attempts: 1])
  end

  defp hash(user, purpose, code),
    do: Secrets.hmac("email_code", [user.id, ":", Atom.to_string(purpose), ":", code])

  # Uniform over 000000..999999: 64 random bits make the modulo bias negligible.
  defp generate do
    <<n::unsigned-64>> = :crypto.strong_rand_bytes(8)
    n |> rem(1_000_000) |> Integer.to_string() |> String.pad_leading(6, "0")
  end
end
