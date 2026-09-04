import Config

# Force using SSL in production. This also sets the "strict-security-transport" header,
# known as HSTS. If you have a health check endpoint, you may want to exclude it below.
# Note `:force_ssl` is required to be set at compile-time.
config :awrad_server, AwradServerWeb.Endpoint,
  force_ssl: [
    rewrite_on: [:x_forwarded_proto],
    exclude: [
      # The proxy and container healthcheck reach the release over plain HTTP
      # without `x-forwarded-proto`, so a redirect here would fail the probe.
      paths: ["/up"],
      hosts: ["localhost", "127.0.0.1"]
    ]
  ]

# Configure Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Req

# Product email delivery uses the Resend API. The API key is injected at
# runtime so it never needs to be compiled into the release.
config :awrad_server, AwradServer.Mailer, adapter: Swoosh.Adapters.Resend

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
