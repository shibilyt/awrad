defmodule AwradApi.Accounts.AuthRateLimit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "auth_rate_limits" do
    field :scope, :string
    field :subject_hash, :binary
    field :window_started_at, :utc_datetime
    field :count, :integer, default: 1
    timestamps(type: :utc_datetime)
  end

  def changeset(limit, attrs) do
    limit
    |> cast(attrs, [:scope, :subject_hash, :window_started_at, :count])
    |> validate_required([:scope, :subject_hash, :window_started_at, :count])
    |> unique_constraint([:scope, :subject_hash, :window_started_at])
  end
end
