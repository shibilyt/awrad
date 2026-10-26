defmodule AwradWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :awrad

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    # Matches cookieAuth in contracts/api/openapi.yaml (ADR-2026-10-15).
    key: "_awrad_session",
    signing_salt: "yjQEFkGi",
    same_site: "Lax",
    http_only: true,
    # Secure in production (config/prod.exs); plain-http localhost in development.
    secure: Application.compile_env(:awrad, :secure_cookies, false)
  ]

  # socket "/live", Phoenix.LiveView.Socket,
  #   websocket: [connect_info: [session: @session_options]],
  #   longpoll: [connect_info: [session: @session_options]]

  # No static files: this is a JSON API (STYLE.md §1). The web app is served separately.

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :awrad
  end

  plug Plug.RequestId
  plug AwradWeb.Plugs.ApiResponseHeaders
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug AwradWeb.Router
end
