defmodule AwradWeb.BrowserNameTest do
  @moduledoc "Browser names for the account's session list, from User-Agent strings."
  use ExUnit.Case, async: true

  alias AwradWeb.BrowserName

  doctest BrowserName

  for {user_agent, name} <- [
        {"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) " <>
           "Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0", "Edge on Windows"},
        {"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) " <>
           "Chrome/130.0.0.0 Safari/537.36", "Chrome on macOS"},
        {"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) " <>
           "Version/18.0 Safari/605.1.15", "Safari on macOS"},
        {"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " <>
           "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", "Safari on iOS"},
        {"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " <>
           "(KHTML, like Gecko) CriOS/130.0.6723.90 Mobile/15E148 Safari/604.1", "Chrome on iOS"},
        {"Mozilla/5.0 (Linux; Android 14; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) " <>
           "Chrome/130.0.0.0 Mobile Safari/537.36", "Chrome on Android"},
        {"Mozilla/5.0 (Linux; Android 14; SM-S921B) AppleWebKit/537.36 (KHTML, like Gecko) " <>
           "SamsungBrowser/26.0 Chrome/122.0.0.0 Mobile Safari/537.36",
         "Samsung Internet on Android"},
        {"Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0",
         "Firefox on Linux"},
        {"Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 (KHTML, like Gecko) " <>
           "Chrome/130.0.0.0 Safari/537.36", "Chrome on ChromeOS"},
        {"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) " <>
           "Chrome/130.0.0.0 Safari/537.36 OPR/114.0.0.0", "Opera on Windows"},
        {"Mozilla/5.0 (compatible; SomeBot/1.0) Firefox/1.0", "Firefox"},
        {"", nil}
      ] do
    @user_agent user_agent
    @name name
    test "#{inspect(name)} from #{String.slice(user_agent, 0, 40)}" do
      assert BrowserName.parse(@user_agent) == @name
    end
  end

  test "an absurdly long header is no name" do
    assert BrowserName.parse("Firefox/1 " <> String.duplicate("x", 2000)) == nil
  end
end
