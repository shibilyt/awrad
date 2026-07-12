defmodule AwradApi.Repo do
  use Ecto.Repo,
    otp_app: :awrad_api,
    adapter: Ecto.Adapters.Postgres
end
