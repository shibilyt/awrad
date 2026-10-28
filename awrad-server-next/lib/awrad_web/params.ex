defmodule AwradWeb.Params do
  @moduledoc """
  Strict request bodies (`contracts/api/STYLE.md` §7, §12). A body must be an
  `application/json` object with only the declared fields, each of the declared
  JSON type. Anything else (another content type, an unknown field, a missing
  required field, a wrong type) is a malformed request: `400 malformed_request`.

  Values are checked here only for their JSON type; the domain checks their
  content and answers `422 validation_failed` with field codes.
  """

  # `:array` checks only that the value is a JSON array; its items are the domain's.
  @type type :: :string | :boolean | :array | {:object, spec()}
  @type spec :: [{atom(), {type(), :required | :optional}}]

  @doc """
  Casts the parsed body of `conn` by `spec`, e.g.
  `[email: {:string, :required}, remember_me: {:boolean, :optional}]`.
  Returns the present fields with atom keys, or `{:error, detail}`.
  """
  @spec cast(Plug.Conn.t(), spec()) :: {:ok, map()} | {:error, String.t()}
  def cast(%Plug.Conn{} = conn, spec) do
    if json?(conn),
      do: cast_object(conn.body_params, spec, ""),
      else: {:error, "the body must be an application/json object"}
  end

  defp json?(conn) do
    case Plug.Conn.get_req_header(conn, "content-type") do
      [content_type | _] ->
        content_type |> String.downcase() |> String.starts_with?("application/json")

      [] ->
        false
    end
  end

  defp cast_object(%{"_json" => _not_an_object}, _spec, path),
    do: {:error, "#{label(path)} must be a JSON object"}

  defp cast_object(object, spec, path) when is_map(object) do
    allowed = Map.new(spec, fn {name, rule} -> {Atom.to_string(name), {name, rule}} end)

    with :ok <- reject_unknown(object, allowed, path) do
      Enum.reduce_while(spec, {:ok, %{}}, &cast_entry(object, path, &1, &2))
    end
  end

  defp cast_object(_value, _spec, path), do: {:error, "#{label(path)} must be a JSON object"}

  defp cast_entry(object, path, {name, {type, presence}}, {:ok, acc}) do
    key = Atom.to_string(name)

    case {Map.fetch(object, key), presence} do
      {:error, :optional} -> {:cont, {:ok, acc}}
      {:error, :required} -> {:halt, {:error, "missing field \"#{path}#{key}\""}}
      {{:ok, value}, _} -> cast_field(value, type, "#{path}#{key}", name, acc)
    end
  end

  defp cast_field(value, :string, _path, name, acc) when is_binary(value),
    do: {:cont, {:ok, Map.put(acc, name, value)}}

  defp cast_field(value, :array, _path, name, acc) when is_list(value),
    do: {:cont, {:ok, Map.put(acc, name, value)}}

  defp cast_field(value, :boolean, _path, name, acc) when is_boolean(value),
    do: {:cont, {:ok, Map.put(acc, name, value)}}

  defp cast_field(value, {:object, spec}, path, name, acc) do
    case cast_object(value, spec, path <> "/") do
      {:ok, nested} -> {:cont, {:ok, Map.put(acc, name, nested)}}
      {:error, detail} -> {:halt, {:error, detail}}
    end
  end

  defp cast_field(_value, type, path, _name, _acc),
    do: {:halt, {:error, "field \"#{path}\" must be #{type_name(type)}"}}

  defp reject_unknown(object, allowed, path) do
    case object |> Map.keys() |> Enum.reject(&Map.has_key?(allowed, &1)) |> Enum.sort() do
      [] -> :ok
      [unknown | _] -> {:error, "unknown field \"#{path}#{unknown}\""}
    end
  end

  defp label(""), do: "the body"
  defp label(path), do: "field \"#{String.trim_trailing(path, "/")}\""

  defp type_name(:string), do: "a string"
  defp type_name(:boolean), do: "a boolean"
  defp type_name(:array), do: "an array"
end
