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

  @doc "The live record for `scope` and `key`, if any."
  @spec lookup(String.t(), Ecto.UUID.t()) :: Record.t() | nil
  def lookup(scope, key) do
    now = DateTime.utc_now(:second)
    Repo.one(from r in Record, where: r.scope == ^scope and r.key == ^key and r.expires_at > ^now)
  end

  @doc """
  Stores a result. `body` is `nil` when the operation re-runs on a repeat
  instead of replaying. The first stored result for a key wins.
  """
  @spec store(
          String.t(),
          Ecto.UUID.t(),
          binary(),
          pos_integer(),
          String.t() | nil,
          binary() | nil
        ) :: :ok
  def store(scope, key, fingerprint, status, content_type, body) do
    now = DateTime.utc_now(:second)

    # An expired row for the key is gone for good; the new result replaces it.
    Repo.delete_all(
      from(r in Record, where: r.scope == ^scope and r.key == ^key and r.expires_at <= ^now)
    )

    Repo.insert!(
      %Record{
        scope: scope,
        key: key,
        fingerprint: fingerprint,
        status: status,
        content_type: content_type,
        body_ciphertext: body && Secrets.encrypt(@purpose, body),
        expires_at: DateTime.add(now, @ttl_hours, :hour),
        inserted_at: now
      },
      on_conflict: :nothing,
      conflict_target: [:scope, :key]
    )

    :ok
  end

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
