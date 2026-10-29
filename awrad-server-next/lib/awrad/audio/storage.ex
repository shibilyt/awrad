defmodule Awrad.Audio.Storage do
  @moduledoc """
  Object storage for user recordings (root ADR-2026-10-29, server ADR 0011):
  the private R2 bucket, reached by short-lived SigV4 links that clients use
  directly, and by `HEAD` and `DELETE` from the server.

  A behaviour, so tests never reach R2: `config :awrad, Awrad.Audio, storage:`
  names the implementation (`Awrad.Audio.R2` by default; the test stand-in in
  `test/support/`). The functions below dispatch to it.

  Keys are the object keys `users/<account_id>/audio/<asset_id>`. Times are
  whole seconds; a link signed at `now` for `seconds` expires at
  `now + seconds`.
  """

  defmodule Error do
    @moduledoc "Storage didn't answer as expected. The message never holds a link or credential."
    defexception [:message]

    @doc "A short, credential-free description of a `head/1` or `delete/1` error reason."
    @spec describe(term()) :: String.t()
    def describe({:status, status}), do: "HTTP #{status}"
    def describe(%{__exception__: true} = exception), do: inspect(exception.__struct__)
    def describe(_other), do: "unexpected answer"
  end

  @typedoc "An object key in the bucket."
  @type key :: String.t()

  @typedoc "A signed link, the headers a client must send with it, and when it stops working."
  @type link :: %{url: String.t(), headers: %{String.t() => String.t()}, expires_at: DateTime.t()}

  @typedoc """
  What `head/1` reports of a stored object: its size, its `Content-Type`, and
  its SHA-256 as base64 when the upload carried one (`nil` otherwise).
  """
  @type object :: %{
          byte_size: non_neg_integer(),
          content_type: String.t() | nil,
          checksum_sha256: String.t() | nil
        }

  @doc """
  A `PUT` link for `key`, signed with `headers` (lowercase names; at least
  `content-type` and `x-amz-checksum-sha256`), so storage refuses a request
  that doesn't send exactly them.
  """
  @callback presign_put(
              key(),
              headers :: %{String.t() => String.t()},
              pos_integer(),
              DateTime.t()
            ) ::
              link()

  @doc "A `GET` link for `key`, signed with the host only."
  @callback presign_get(key(), pos_integer(), DateTime.t()) :: link()

  @doc "The stored object at `key`, `:not_found`, or `{:error, reason}` when storage didn't answer."
  @callback head(key()) :: {:ok, object()} | :not_found | {:error, term()}

  @doc "Deletes `key`; deleting an object that isn't there is `:ok` too."
  @callback delete(key()) :: :ok | {:error, term()}

  @doc "The configured implementation."
  @spec impl() :: module()
  def impl,
    do: Keyword.get(Application.get_env(:awrad, Awrad.Audio, []), :storage, Awrad.Audio.R2)

  @doc "See the `c:presign_put/4` callback."
  @spec presign_put(key(), %{String.t() => String.t()}, pos_integer(), DateTime.t()) :: link()
  def presign_put(key, headers, seconds, now), do: impl().presign_put(key, headers, seconds, now)

  @doc "See the `c:presign_get/3` callback."
  @spec presign_get(key(), pos_integer(), DateTime.t()) :: link()
  def presign_get(key, seconds, now), do: impl().presign_get(key, seconds, now)

  @doc "See the `c:head/1` callback."
  @spec head(key()) :: {:ok, object()} | :not_found | {:error, term()}
  def head(key), do: impl().head(key)

  @doc "See the `c:delete/1` callback."
  @spec delete(key()) :: :ok | {:error, term()}
  def delete(key), do: impl().delete(key)
end
