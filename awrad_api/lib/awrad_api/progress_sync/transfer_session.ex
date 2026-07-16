defmodule AwradApi.ProgressSync.TransferSession do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "progress_sync_transfer_sessions" do
    field :kind, :string
    field :from_revision, :integer
    field :to_revision, :integer
    field :generation, :integer
    field :status, :string, default: "ready"
    field :page_count, :integer
    field :record_count, :integer
    field :checksum, :binary
    field :expires_at, :utc_datetime
    belongs_to :user, AwradApi.Accounts.User
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(session, attrs, user_id) do
    session
    |> change(Map.put(attrs, :user_id, user_id))
    |> validate_required([
      :user_id,
      :kind,
      :from_revision,
      :to_revision,
      :generation,
      :status,
      :page_count,
      :record_count,
      :checksum,
      :expires_at
    ])
    |> validate_inclusion(:kind, ~w(snapshot delta))
    |> validate_inclusion(:status, ~w(ready completed expired))
  end
end
