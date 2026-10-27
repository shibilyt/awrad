defmodule Awrad.Dhikrs.Catalog do
  @moduledoc """
  The built-in dhikr catalog's identity (`contracts/dhikr-catalog/v1/catalog.json`,
  ADR-2026-07-13): each built-in dhikr's `id`, `key`, `kind` and collections,
  and the catalog's `contentRevision`. Nothing else of the content is kept.

  The catalog is compiled in from the server's checked copy,
  `priv/dhikr-catalog/catalog.json`, like the Hijri table (ADR 0004): the
  release never reads `contracts/` or the copy at runtime, and
  `test/awrad/shared_fixtures_test.exs` fails `mix validate` when the copy
  differs from the contracts file. Compilation fails when the copy breaks an
  identity rule (an unknown kind, a duplicate or non-UUIDv4 id, a duplicate
  key, a collection listing an unknown key).

  IDs are matched exactly, in the catalog's lowercase form.
  """

  alias Awrad.Dhikrs.Catalog.Entry

  @path Path.expand("../../../priv/dhikr-catalog/catalog.json", __DIR__)
  @external_resource @path

  @kinds %{
    "quran" => :quran,
    "dhikr" => :dhikr,
    "dua" => :dua,
    "salawat" => :salawat,
    "name_of_allah" => :name_of_allah
  }

  catalog = @path |> File.read!() |> Jason.decode!()
  dhikrs = Map.get(catalog, "dhikrs", [])
  collections = Map.get(catalog, "collections", [])
  keys = Enum.map(dhikrs, & &1["key"])
  ids = Enum.map(dhikrs, & &1["id"])
  uuid_v4 = ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  problem =
    cond do
      not match?(%{"version" => 1, "contentRevision" => r} when is_integer(r) and r >= 1, catalog) ->
        "expected catalog version 1 with a positive integer contentRevision"

      dhikrs == [] ->
        "no dhikrs"

      not Enum.all?(keys, &(is_binary(&1) and &1 != "")) ->
        "a dhikr has no key"

      keys != Enum.uniq(keys) ->
        "duplicate dhikr keys"

      not Enum.all?(ids, &(is_binary(&1) and &1 =~ uuid_v4)) ->
        "an id isn't a lowercase UUIDv4"

      ids != Enum.uniq(ids) ->
        "duplicate dhikr ids"

      not Enum.all?(dhikrs, &Map.has_key?(@kinds, &1["kind"])) ->
        "unknown dhikr kind"

      not Enum.all?(collections, &(&1["dhikrs"] -- keys == [])) ->
        "a collection lists an unknown key"

      true ->
        nil
    end

  if problem, do: raise(CompileError, description: "#{@path}: #{problem}")

  memberships =
    for collection <- collections, key <- collection["dhikrs"], reduce: %{} do
      acc -> Map.update(acc, key, [collection["key"]], &(&1 ++ [collection["key"]]))
    end

  entries =
    for dhikr <- dhikrs do
      %Entry{
        id: dhikr["id"],
        key: dhikr["key"],
        kind: Map.fetch!(@kinds, dhikr["kind"]),
        collections: Map.get(memberships, dhikr["key"], [])
      }
    end

  @content_revision catalog["contentRevision"]
  @by_id Map.new(entries, &{&1.id, &1})
  @by_key Map.new(entries, &{&1.key, &1})

  @doc "The built-in dhikr with this id, or `:error`."
  @spec fetch_by_id(term()) :: {:ok, Entry.t()} | :error
  def fetch_by_id(id), do: Map.fetch(@by_id, id)

  @doc "The built-in dhikr with this catalog key, or `:error`."
  @spec fetch_by_key(term()) :: {:ok, Entry.t()} | :error
  def fetch_by_key(key), do: Map.fetch(@by_key, key)

  @doc "Whether `id` is a built-in dhikr's id."
  @spec builtin?(term()) :: boolean()
  def builtin?(id), do: Map.has_key?(@by_id, id)

  @doc "The kind of the built-in dhikr with this id, or `:error`."
  @spec kind(term()) :: {:ok, Entry.kind()} | :error
  def kind(id) do
    with {:ok, %Entry{kind: kind}} <- fetch_by_id(id), do: {:ok, kind}
  end

  @doc "The catalog's `contentRevision`."
  # The compiled-in value itself: Dialyzer rejects a wider spec.
  @spec content_revision() :: unquote(@content_revision)
  def content_revision, do: @content_revision
end
