defmodule AwradServer.LocationSearch do
  @moduledoc """
  Resolves human-readable places into the coordinates needed by prayer calculations.

  The geocoder is deliberately kept behind this small boundary so the web UI can
  change providers without changing device-context or practice-day semantics.
  """

  @default_base_url "https://nominatim.openstreetmap.org"
  @default_user_agent "Awrad/0.1 (+https://awrad.app)"
  @max_query_length 120
  @result_limit 5
  @request_timeout 5_000

  @type place :: %{
          name: String.t(),
          display_name: String.t(),
          latitude: float(),
          longitude: float()
        }

  @doc "Searches for up to five named places."
  @spec search(String.t(), keyword()) :: {:ok, [place()]} | {:error, atom()}
  def search(query, opts \\ []) do
    with {:ok, query} <- normalize_query(query),
         {:ok, response} <- request("/search", search_params(query), opts) do
      {:ok, normalize_results(response.body)}
    end
  end

  @doc "Resolves coordinates into one readable place label."
  @spec reverse(number(), number(), keyword()) :: {:ok, place()} | {:error, atom()}
  def reverse(latitude, longitude, opts \\ []) do
    with {:ok, latitude} <- normalize_coordinate(latitude, -90, 90),
         {:ok, longitude} <- normalize_coordinate(longitude, -180, 180),
         {:ok, response} <- request("/reverse", reverse_params(latitude, longitude), opts),
         result when is_map(result) <- normalize_result(response.body) do
      {:ok, result}
    else
      nil -> {:error, :geocoder_unavailable}
      {:error, _reason} = error -> error
      _other -> {:error, :geocoder_unavailable}
    end
  end

  defp normalize_query(query) when is_binary(query) do
    query = String.trim(query)

    if query != "" and String.length(query) <= @max_query_length do
      {:ok, query}
    else
      {:error, :invalid_query}
    end
  end

  defp normalize_query(_query), do: {:error, :invalid_query}

  defp normalize_coordinate(value, minimum, maximum) when is_number(value) do
    value = value * 1.0

    if value >= minimum and value <= maximum,
      do: {:ok, value},
      else: {:error, :invalid_coordinates}
  end

  defp normalize_coordinate(value, minimum, maximum) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {value, ""} -> normalize_coordinate(value, minimum, maximum)
      _ -> {:error, :invalid_coordinates}
    end
  end

  defp normalize_coordinate(_value, _minimum, _maximum), do: {:error, :invalid_coordinates}

  defp search_params(query) do
    [q: query, format: "jsonv2", addressdetails: 1, limit: @result_limit]
  end

  defp reverse_params(latitude, longitude) do
    [lat: latitude, lon: longitude, format: "jsonv2", addressdetails: 1, zoom: 10]
  end

  defp request(path, params, opts) do
    config = Application.get_env(:awrad_server, :location_search, [])
    base_url = Keyword.get(config, :base_url, @default_base_url)
    user_agent = Keyword.get(config, :user_agent, @default_user_agent)

    request_options = [
      url: String.trim_trailing(base_url, "/") <> path,
      params: params,
      headers: [
        {"user-agent", user_agent},
        {"accept-language", "en"}
      ],
      receive_timeout: @request_timeout,
      retry: false
    ]

    req_options =
      config
      |> Keyword.get(:req_options, [])
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    case Req.get(Keyword.merge(request_options, req_options)) do
      {:ok, %{status: status} = response} when status in 200..299 -> {:ok, response}
      {:ok, _response} -> {:error, :geocoder_unavailable}
      {:error, _exception} -> {:error, :geocoder_unavailable}
    end
  end

  defp normalize_results(body) when is_list(body) do
    body
    |> Enum.map(&normalize_result/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_results(_body), do: []

  defp normalize_result(item) when is_map(item) do
    with {:ok, latitude} <- normalize_coordinate(Map.get(item, "lat"), -90, 90),
         {:ok, longitude} <- normalize_coordinate(Map.get(item, "lon"), -180, 180),
         address when is_map(address) <- Map.get(item, "address", %{}),
         name when is_binary(name) <- place_name(item, address),
         display_name when is_binary(display_name) <- display_name(item, address, name) do
      %{
        name: name,
        display_name: display_name,
        latitude: latitude,
        longitude: longitude
      }
    else
      _other -> nil
    end
  end

  defp normalize_result(_item), do: nil

  defp place_name(item, address) do
    first_present([
      Map.get(address, "city"),
      Map.get(address, "town"),
      Map.get(address, "village"),
      Map.get(address, "municipality"),
      Map.get(address, "county"),
      Map.get(item, "name")
    ])
  end

  defp display_name(item, address, name) do
    parts =
      [name, Map.get(address, "state"), Map.get(address, "country")]
      |> Enum.map(&normalize_label/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    case parts do
      [] -> normalize_label(Map.get(item, "display_name"))
      parts -> Enum.join(parts, ", ")
    end
  end

  defp first_present(values) do
    Enum.find_value(values, fn value -> normalize_label(value) end)
  end

  defp normalize_label(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp normalize_label(_value), do: nil
end
