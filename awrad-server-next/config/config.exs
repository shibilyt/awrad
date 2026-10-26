# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :awrad,
  ecto_repos: [Awrad.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :awrad, AwradWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: AwradWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Awrad.PubSub,
  live_view: [signing_salt: "8NpQo30C"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :awrad, Awrad.Mailer, adapter: Swoosh.Adapters.Local

# Account emails (slice 2a). Production sets AWRAD_MAIL_FROM in runtime.exs.
config :awrad, Awrad.Accounts.UserNotifier, from: {"Awrad", "no-reply@awrad.localhost"}

# Removes expired idempotency results, rate-limit windows and email codes hourly.
config :awrad, Awrad.Pruner, enabled: true

# Browser cookies get the Secure flag in production only (prod.exs), so plain-http
# localhost works in development (ADR-2026-10-15).
config :awrad, :secure_cookies, false

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Never log credentials: passwords, emailed codes, refresh and CSRF tokens. Phoenix
# filters any parameter whose name contains one of these.
config :phoenix, :filter_parameters, ["password", "code", "token"]

# IANA time zones for the goal rules (ADR 0003). The data is compiled into the
# `tz` dependency; it's updated by bumping `tz`, never at runtime, so
# Tz.UpdatePeriodically / Tz.WatchPeriodically are deliberately not started.
config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
