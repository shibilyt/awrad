import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :awrad, Awrad.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  # The machine's Postgres 18 (5432) by default; compose.yaml users export AWRAD_POSTGRES_PORT=5433.
  port: String.to_integer(System.get_env("AWRAD_POSTGRES_PORT", "5432")),
  # Namespaced so a shared local Postgres never mixes with the frozen server's awrad_api_* databases.
  database: "awrad_next_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :awrad, AwradWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "8oYZLbwVKoAfweJ870WCP0SrqWq8Lz0ajGpm9oWUkkMsAKyWSvwK2CjHHpnNTS7r",
  server: false

# In test we don't send emails
config :awrad, Awrad.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
