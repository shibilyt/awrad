defmodule AwradServerWeb.PublicUrls do
  @moduledoc """
  Builds absolute URLs for the public web and API hosts.

  The Phoenix endpoint is canonical for API and mobile association traffic,
  while browser-facing auth links use the separate web host.
  """

  @spec web(binary()) :: binary()
  def web(path), do: build(:web, path)

  @spec api(binary()) :: binary()
  def api(path), do: build(:api, path)

  defp build(kind, path) do
    base_url =
      :awrad_server
      |> Application.fetch_env!(:public_urls)
      |> Keyword.fetch!(kind)

    base_url
    |> URI.parse()
    |> URI.merge(path)
    |> URI.to_string()
  end
end
