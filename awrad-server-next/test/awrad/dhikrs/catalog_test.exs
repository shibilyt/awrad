defmodule Awrad.Dhikrs.CatalogTest do
  use ExUnit.Case, async: true

  alias Awrad.Dhikrs.Catalog
  alias Awrad.Dhikrs.Catalog.Entry
  alias Awrad.Fixtures

  @catalog "dhikr-catalog/v1/catalog.json"
           |> Fixtures.contracts_path()
           |> File.read!()
           |> Jason.decode!()
  @builtins "progress-model/v1/builtin-dhikrs.json"
            |> Fixtures.contracts_path()
            |> File.read!()
            |> Jason.decode!()
            |> Map.fetch!("dhikrs")

  @ikhlas_id "c88b9491-40ad-4b42-a5b8-e07c4b4d31ef"

  test "every key and id pair is the one in progress-model/v1/builtin-dhikrs.json" do
    assert length(@builtins) == length(@catalog["dhikrs"])

    for %{"catalog_key" => key, "id" => id} <- @builtins do
      assert {:ok, %Entry{id: ^id, key: ^key}} = Catalog.fetch_by_key(key)
      assert {:ok, %Entry{id: ^id, key: ^key}} = Catalog.fetch_by_id(id)
      assert Catalog.builtin?(id)
    end

    for %{"key" => key} <- @catalog["dhikrs"] do
      assert {:ok, _} = Catalog.fetch_by_key(key), "#{key} isn't in the compiled catalog"
    end
  end

  test "looks a dhikr up by id and by key" do
    entry = %Entry{
      id: @ikhlas_id,
      key: "surah-ikhlas",
      kind: :quran,
      collections: ["daily-essentials"]
    }

    assert Catalog.fetch_by_id(@ikhlas_id) == {:ok, entry}
    assert Catalog.fetch_by_key("surah-ikhlas") == {:ok, entry}
    assert Catalog.kind(@ikhlas_id) == {:ok, :quran}
  end

  test "keeps every kind and collection membership from the catalog" do
    for %{"id" => id, "kind" => kind} <- @catalog["dhikrs"] do
      assert {:ok, atom} = Catalog.kind(id)
      assert Atom.to_string(atom) == kind
    end

    for %{"key" => collection, "dhikrs" => keys} <- @catalog["collections"], key <- keys do
      assert {:ok, %Entry{collections: collections}} = Catalog.fetch_by_key(key)
      assert collection in collections
    end
  end

  test "unknown ids and keys are :error" do
    for id <- [
          "00000000-0000-4000-8000-000000000000",
          String.upcase(@ikhlas_id),
          "surah-ikhlas",
          "",
          nil
        ] do
      assert Catalog.fetch_by_id(id) == :error
      assert Catalog.kind(id) == :error
      refute Catalog.builtin?(id)
    end

    assert Catalog.fetch_by_key("no-such-dhikr") == :error
    assert Catalog.fetch_by_key(@ikhlas_id) == :error
  end

  test "content_revision is the catalog's contentRevision" do
    assert Catalog.content_revision() == @catalog["contentRevision"]
  end
end
