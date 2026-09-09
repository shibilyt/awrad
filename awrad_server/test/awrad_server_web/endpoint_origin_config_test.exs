defmodule AwradServerWeb.EndpointOriginConfigTest do
  use ExUnit.Case, async: false

  @runtime_env [
    {"DATABASE_URL", "ecto://user:pass@localhost/awrad"},
    {"SECRET_KEY_BASE", "test-secret-key-base"},
    {"PHX_HOST", "api.example.test"},
    {"WEB_HOST", "app.example.test"},
    {"RESEND_API_KEY", "test-resend-key"},
    {"MAIL_FROM", "noreply@example.test"},
    {"JWT_SIGNING_SECRET", "12345678901234567890123456789012"},
    {"REFRESH_RETRY_SECRET", "12345678901234567890123456789012"},
    {"AUTH_RATE_LIMIT_PEPPER", "12345678901234567890123456789012"}
  ]

  test "production endpoint accepts both API and web origins" do
    previous_env = save_env(@runtime_env)
    put_env(@runtime_env)

    try do
      endpoint_config =
        Path.expand("../../config/runtime.exs", __DIR__)
        |> Config.Reader.read!(env: :prod)
        |> Keyword.fetch!(:awrad_server)
        |> Keyword.fetch!(AwradServerWeb.Endpoint)

      assert Keyword.fetch!(endpoint_config, :check_origin) == [
               "https://api.example.test",
               "https://app.example.test"
             ]
    after
      restore_env(previous_env)
    end
  end

  defp save_env(env) do
    Map.new(env, fn {key, _value} -> {key, System.get_env(key)} end)
  end

  defp put_env(env) do
    Enum.each(env, fn {key, value} -> System.put_env(key, value) end)
  end

  defp restore_env(env) do
    Enum.each(env, fn
      {key, nil} -> System.delete_env(key)
      {key, value} -> System.put_env(key, value)
    end)
  end
end
