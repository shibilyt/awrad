defmodule Awrad.Audio.FakeStorage do
  @moduledoc """
  The test stand-in for `Awrad.Audio.Storage` (`config/test.exs`), so tests
  never reach R2.

    * Links are signed by the real `Awrad.Audio.R2` signer, with the test
      credentials in `config/test.exs`: signing is pure, so tests check the
      real links' shape.
    * Objects live in a public ETS table (created by `test/test_helper.exs`),
      keyed by object key. Keys hold a fresh account ID, so async tests never
      share one. `put_object/3` plays the client's `PUT`.
    * `fail_deletes/1` makes `delete/1` fail for a key, as R2 might.
  """

  @behaviour Awrad.Audio.Storage

  # Test support sits outside the production boundaries (Awrad, AwradWeb).
  use Boundary, top_level?: true, check: [in: false, out: false]

  @table __MODULE__

  @doc "Creates the store. Called once, from `test/test_helper.exs`."
  @spec start() :: :ok
  def start do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    :ok
  end

  @impl Awrad.Audio.Storage
  defdelegate presign_put(key, headers, seconds, now), to: Awrad.Audio.R2

  @impl Awrad.Audio.Storage
  defdelegate presign_get(key, seconds, now), to: Awrad.Audio.R2

  @impl Awrad.Audio.Storage
  def head(key) do
    case :ets.lookup(@table, {:object, key}) do
      [{_key, object}] -> {:ok, object}
      [] -> :not_found
    end
  end

  @impl Awrad.Audio.Storage
  def delete(key) do
    if :ets.member(@table, {:failing, key}) do
      {:error, {:status, 500}}
    else
      :ets.delete(@table, {:object, key})
      :ok
    end
  end

  @doc """
  Stores `bytes` at `key` as R2 would after a `PUT` with `content_type` and
  their SHA-256 (`x-amz-checksum-sha256`). Options override what `head/1`
  reports: `:byte_size`, `:content_type`, `:checksum_sha256`.
  """
  @spec put_object(String.t(), binary(), keyword()) :: :ok
  def put_object(key, bytes, opts \\ []) do
    object = %{
      byte_size: Keyword.get(opts, :byte_size, byte_size(bytes)),
      content_type: Keyword.get(opts, :content_type, "audio/mpeg"),
      checksum_sha256:
        Keyword.get_lazy(opts, :checksum_sha256, fn ->
          Base.encode64(:crypto.hash(:sha256, bytes))
        end)
    }

    :ets.insert(@table, {{:object, key}, object})
    :ok
  end

  @doc "Whether an object is stored at `key`."
  @spec object?(String.t()) :: boolean()
  def object?(key), do: :ets.member(@table, {:object, key})

  @doc "Makes every `delete/1` of `key` fail (`true`), or work again (`false`)."
  @spec fail_deletes(String.t(), boolean()) :: :ok
  def fail_deletes(key, failing? \\ true) do
    if failing?,
      do: :ets.insert(@table, {{:failing, key}, true}),
      else: :ets.delete(@table, {:failing, key})

    :ok
  end
end
