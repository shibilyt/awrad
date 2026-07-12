defmodule AwradApi.Accounts.AuthSecurityEvent do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "auth_security_events" do
    field :event, :string
    field :subject_hash, :binary
    field :metadata, :map, default: %{}
    belongs_to :user, AwradApi.Accounts.User
    belongs_to :session, AwradApi.Accounts.AuthSession
    timestamps(type: :utc_datetime, updated_at: false)
  end
end
