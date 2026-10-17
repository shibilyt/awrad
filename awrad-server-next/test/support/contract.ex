defmodule AwradWeb.Contract do
  @moduledoc """
  Contract checks against `contracts/api/openapi.bundled.json`, the API source
  of truth (`contracts/api/STYLE.md` §15).

  `assert_conforms/2` checks a real response against its operation: the status
  is documented, every declared header is present, the content type matches,
  and the body validates against the response schema (JSON Schema 2020-12).
  """

  # Test support sits outside the production boundaries (Awrad, AwradWeb).
  use Boundary, top_level?: true, check: [in: false, out: false]

  import ExUnit.Assertions

  @spec_path Path.expand("../../../contracts/api/openapi.bundled.json", __DIR__)
  @external_resource @spec_path
  @spec_doc @spec_path |> File.read!() |> Jason.decode!()
  @methods ~w(get put post patch delete options head trace)

  @doc ~s|Every operation in the spec, as `{"GET", "/api/v1/..."}` tuples.|
  @spec operations() :: MapSet.t({String.t(), String.t()})
  def operations do
    for {path, item} <- @spec_doc["paths"],
        {method, _op} <- item,
        method in @methods,
        into: MapSet.new() do
      {String.upcase(method), path}
    end
  end

  @doc "Asserts `conn`'s response matches operation `operation_id`. Returns the decoded body."
  @spec assert_conforms(Plug.Conn.t(), String.t()) :: term()
  def assert_conforms(%Plug.Conn{} = conn, operation_id) do
    operation = operation!(operation_id)
    status = Integer.to_string(conn.status)

    response =
      resolve(operation["responses"][status] || operation["responses"]["default"]) ||
        flunk("#{operation_id}: status #{status} isn't documented in the spec")

    for {name, _header} <- response["headers"] || %{} do
      assert Plug.Conn.get_resp_header(conn, String.downcase(name)) != [],
             "#{operation_id} #{status}: missing declared header #{name}"
    end

    assert_body(conn, response, "#{operation_id} #{status}")
  end

  defp assert_body(conn, %{"content" => content}, label) do
    [content_type | _] = Plug.Conn.get_resp_header(conn, "content-type")
    media = content_type |> String.split(";") |> hd() |> String.trim()

    schema =
      get_in(content, [media, "schema"]) ||
        flunk("#{label}: content type #{media} isn't documented")

    body = Jason.decode!(conn.resp_body)

    root =
      JSV.build!(
        %{
          "$schema" => "https://json-schema.org/draft/2020-12/schema",
          "components" => @spec_doc["components"],
          "allOf" => [schema]
        },
        formats: true
      )

    case JSV.validate(body, root) do
      {:ok, _} ->
        body

      {:error, error} ->
        flunk(
          "#{label}: body doesn't match the schema\n#{inspect(JSV.normalize_error(error), pretty: true)}"
        )
    end
  end

  defp assert_body(conn, _response, label) do
    assert conn.resp_body in ["", nil], "#{label}: the spec declares no body, but one was sent"
    nil
  end

  defp operation!(operation_id) do
    found =
      for {_path, item} <- @spec_doc["paths"],
          {method, op} <- item,
          method in @methods,
          op["operationId"] == operation_id,
          do: op

    case found do
      [op] -> op
      [] -> flunk("operationId #{operation_id} isn't in the spec")
    end
  end

  # Follows a local `$ref` such as "#/components/responses/Unauthorized".
  defp resolve(%{"$ref" => "#/" <> pointer}) do
    pointer
    |> String.split("/")
    |> Enum.map(&unescape/1)
    |> then(&get_in(@spec_doc, &1))
    |> resolve()
  end

  defp resolve(node), do: node

  defp unescape(segment), do: segment |> String.replace("~1", "/") |> String.replace("~0", "~")
end
