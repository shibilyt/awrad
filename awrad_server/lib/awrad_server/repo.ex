defmodule AwradServer.Repo do
  use Ecto.Repo,
    otp_app: :awrad_server,
    adapter: Ecto.Adapters.Postgres
end
