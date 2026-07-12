import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :awrad_api, AwradApi.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "awrad_api_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :awrad_api, AwradApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "/4VQN3t7Ogf4RWZNFHp0YkVOUR5VPyAgSBW61C8JdpfdRuLLoIUrvfA6VlpeGpyg",
  server: false

# JWT signing secret for tests
config :awrad_api, AwradApi.Accounts.Token,
  signing_secret: "test-only-jwt-secret-at-least-32-characters!"

# In test we don't send emails
config :awrad_api, AwradApi.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
