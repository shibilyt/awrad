defmodule Awrad.Repo do
  use Ecto.Repo,
    otp_app: :awrad,
    adapter: Ecto.Adapters.Postgres
end
