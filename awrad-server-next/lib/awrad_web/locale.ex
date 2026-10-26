defmodule AwradWeb.Locale do
  @moduledoc """
  The language for emails a request sends, from `Accept-Language`
  (`AcceptLanguage` in `contracts/api/openapi.yaml`): the supported language
  (`en`, `ar`, `ml`) the client prefers most, by q-value then order; `en` when
  none matches or the header is missing or too long.
  """

  @supported ~w(en ar ml)
  @default "en"
  @max_length 256

  @doc """
  The locale for `conn`.

      iex> AwradWeb.Locale.parse("ml-IN, ar;q=0.9, en;q=0.8")
      "ml"
  """
  @spec from_conn(Plug.Conn.t()) :: String.t()
  def from_conn(conn) do
    case Plug.Conn.get_req_header(conn, "accept-language") do
      [header | _] -> parse(header)
      [] -> @default
    end
  end

  @doc "Picks the locale from an `Accept-Language` value."
  @spec parse(String.t()) :: String.t()
  def parse(header) when byte_size(header) > @max_length, do: @default

  def parse(header) do
    header
    |> String.split(",")
    |> Enum.with_index()
    |> Enum.flat_map(&range/1)
    |> Enum.filter(fn {language, q, _index} -> language in @supported and q > 0 end)
    |> Enum.sort_by(fn {_language, q, index} -> {-q, index} end)
    |> case do
      [{language, _q, _index} | _] -> language
      [] -> @default
    end
  end

  defp range({part, index}) do
    [tag | params] = part |> String.split(";") |> Enum.map(&String.trim/1)
    language = tag |> String.downcase() |> String.split("-") |> hd()
    [{language, quality(params), index}]
  end

  defp quality(params) do
    Enum.find_value(params, 1.0, fn
      "q=" <> value ->
        case Float.parse(value) do
          {q, ""} when q >= 0 and q <= 1 -> q
          _invalid -> 0.0
        end

      _other ->
        nil
    end)
  end
end
