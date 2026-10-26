defmodule Awrad.Idempotency do
  @moduledoc """
  Stored results for `Idempotency-Key` (`contracts/api/STYLE.md` §10, server
  ADR 0007): a Postgres table, one row per operation and key, kept 24 hours.

  A row holds an HMAC fingerprint of the request body, the response status and
  content type, and the response body encrypted (`Awrad.Secrets.encrypt/2`),
  because some results carry tokens. `AwradWeb.Plugs.Idempotency` is the only
  caller.
  """

  use Boundary, deps: [Awrad, Awrad.Secrets], exports: [Record]

  import Ecto.Query

  alias Awrad.Idempotency.Record
  alias Awrad.{Repo, Secrets}

  @ttl_hours 24
  @purpose "idempotency"

  @doc "The fingerprint of a request body (any term), keyed with the server pepper."
  @spec fingerprint(term()) :: binary()
  def fingerprint(body),
    do: Secrets.hmac(@purpose, :erlang.term_to_binary(body, [:deterministic]))

  @doc """
  The live record for `scope` and `key`, if any. `user_id` is the signed-in
  account making the request (`nil` for public operations): a key is only ever
  matched within the same account.
  """
  @spec lookup(String.t(), Ecto.UUID.t(), Ecto.UUID.t() | nil) :: Record.t() | nil
  def lookup(scope, key, user_id \\ nil) do
    now = DateTime.utc_now(:second)

    Repo.one(
      from r in for_key(scope, key, user_id),
        where: r.expires_at > ^now
    )
  end

  @doc """
  Stores a result for `scope`, `key` and the account `user_id` (or `nil`).
  `body` is `nil` when the operation re-runs on a repeat instead of replaying.
  The first stored result for a key wins. An account's results are deleted
  with it.
  """
  @spec store(
          {String.t(), Ecto.UUID.t(), Ecto.UUID.t() | nil},
          binary(),
          pos_integer(),
          String.t() | nil,
          binary() | nil
        ) :: :ok
  def store({scope, key, user_id}, fingerprint, status, content_type, body) do
    now = DateTime.utc_now(:second)

    # An expired row for the key is gone for good; the new result replaces it.
    Repo.delete_all(from(r in for_key(scope, key, user_id), where: r.expires_at <= ^now))

    record = %Record{
      scope: scope,
      key: key,
      user_id: user_id,
      fingerprint: fingerprint,
      status: status,
      content_type: content_type,
      body_ciphertext: body && Secrets.encrypt(@purpose, body),
      expires_at: DateTime.add(now, @ttl_hours, :hour),
      inserted_at: now
    }

    # An account deleted while its request ran keeps nothing (foreign key).
    {_ok_or_error, _record} =
      record
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.foreign_key_constraint(:user_id)
      |> Repo.insert(on_conflict: :nothing)

    :ok
  end

  defp for_key(scope, key, nil),
    do: from(r in Record, where: r.scope == ^scope and r.key == ^key and is_nil(r.user_id))

  defp for_key(scope, key, user_id),
    do: from(r in Record, where: r.scope == ^scope and r.key == ^key and r.user_id == ^user_id)

  @doc "The stored response body, decrypted. `:error` when there's none or it can't be read."
  @spec body(Record.t()) :: {:ok, binary()} | :error
  def body(%Record{body_ciphertext: nil}), do: :error
  def body(%Record{body_ciphertext: ciphertext}), do: Secrets.decrypt(@purpose, ciphertext)

  @doc "Deletes expired records. Returns how many."
  @spec prune(DateTime.t()) :: non_neg_integer()
  def prune(now) do
    {count, _} = Repo.delete_all(from(r in Record, where: r.expires_at <= ^now))
    count
  end
end
