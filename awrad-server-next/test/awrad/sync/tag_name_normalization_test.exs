defmodule Awrad.Sync.TagNameNormalizationTest do
  @moduledoc """
  contracts/sync/v1/fixtures/tag_name_normalization.json, one test per case,
  through `Awrad.Sync.TagName.normalize/1`; each accepted name must also make
  a valid `user_tag` document.
  """
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Sync.{Documents, TagName}

  doctest TagName

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("sync/v1", "tag_name_normalization") do
    @given given
    @expect expect
    test id do
      actual =
        case TagName.normalize(@given["input"]) do
          {:ok, name, normalized} ->
            %{
              "accepted" => true,
              "name" => name,
              "normalized_name" => normalized,
              "reason" => nil
            }

          {:error, reason} ->
            %{
              "accepted" => false,
              "name" => nil,
              "normalized_name" => nil,
              "reason" => Atom.to_string(reason)
            }
        end

      assert actual == @expect

      if @expect["accepted"] do
        document = Map.take(@expect, ["name", "normalized_name"])
        assert Documents.errors("user_tag", document) == []
      end
    end
  end
end
