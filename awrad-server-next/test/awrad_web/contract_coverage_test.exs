defmodule AwradWeb.ContractCoverageTest do
  @moduledoc "The router and the OpenAPI spec describe exactly the same /api/v1 operations."
  use ExUnit.Case, async: true

  alias AwradWeb.Contract

  defp routed_operations do
    for %{verb: verb, path: "/api/v1/" <> _ = path} <- AwradWeb.Router.__routes__(),
        into: MapSet.new() do
      {verb |> to_string() |> String.upcase(), Regex.replace(~r/:([a-z_]+)/, path, "{\\1}")}
    end
  end

  test "every routed operation is in the spec" do
    missing = MapSet.difference(routed_operations(), Contract.operations())

    assert missing == MapSet.new(),
           "routes missing from contracts/api/openapi.yaml: #{inspect(MapSet.to_list(missing))}"
  end

  test "every spec operation is routed" do
    unrouted = MapSet.difference(Contract.operations(), routed_operations())

    assert unrouted == MapSet.new(),
           "spec operations with no route: #{inspect(MapSet.to_list(unrouted))}"
  end
end
