defmodule AwradWeb.BrowserName do
  @moduledoc """
  A short summary of a browser from its `User-Agent`, such as "Firefox on
  Windows", saved with a browser session at sign-in so the account's session
  list can name it (`AccountSession.name`). `nil` when the browser can't be
  told; clients then show a generic label.

  A deliberately small parser: it knows the common browsers and systems, in the
  order their tokens must be checked (Edge and Opera also say "Chrome", Chrome
  also says "Safari", Android also says "Linux"). It's a label, never used for
  any decision. iPadOS Safari presents itself as macOS, so it's named that way.
  """

  # {token in the User-Agent, name}, first match wins.
  @browsers [
    {"Edg/", "Edge"},
    {"EdgiOS/", "Edge"},
    {"EdgA/", "Edge"},
    {"OPR/", "Opera"},
    {"SamsungBrowser/", "Samsung Internet"},
    {"Firefox/", "Firefox"},
    {"FxiOS/", "Firefox"},
    {"CriOS/", "Chrome"},
    {"Chrome/", "Chrome"},
    {"Chromium/", "Chromium"},
    {"Safari/", "Safari"}
  ]

  @systems [
    {"Windows", "Windows"},
    {"iPhone", "iOS"},
    {"iPad", "iPadOS"},
    {"iPod", "iOS"},
    {"Android", "Android"},
    {"CrOS", "ChromeOS"},
    {"Macintosh", "macOS"},
    {"Mac OS X", "macOS"},
    {"Linux", "Linux"}
  ]

  @max_header 1024

  @doc "The browser name for a request, from its `User-Agent`."
  @spec from_conn(Plug.Conn.t()) :: String.t() | nil
  def from_conn(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [user_agent | _] -> parse(user_agent)
      [] -> nil
    end
  end

  @doc """
  The browser name for a `User-Agent` value.

      iex> AwradWeb.BrowserName.parse("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0")
      "Firefox on Windows"

      iex> AwradWeb.BrowserName.parse("curl/8.7.1")
      nil
  """
  @spec parse(String.t()) :: String.t() | nil
  def parse(user_agent) when is_binary(user_agent) and byte_size(user_agent) <= @max_header do
    case {find(@browsers, user_agent), find(@systems, user_agent)} do
      {nil, _system} -> nil
      {browser, nil} -> browser
      {browser, system} -> "#{browser} on #{system}"
    end
  end

  def parse(_user_agent), do: nil

  defp find(table, user_agent) do
    Enum.find_value(table, fn {token, name} ->
      if String.contains?(user_agent, token), do: name
    end)
  end
end
