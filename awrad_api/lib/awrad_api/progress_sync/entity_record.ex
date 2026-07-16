defmodule AwradApi.ProgressSync.EntityRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "progress_sync_entities" do
    field :entity_type, :string
    field :entity_id, :binary_id
    field :incarnation, :integer, default: 1
    field :version, :integer, default: 1
    field :sync_revision, :integer
    field :document, :map
    field :state, :string, default: "active"
    field :deleted_at, :utc_datetime
    field :purge_after, :utc_datetime
    field :purged_at, :utc_datetime
    field :completion_origin, :string
    belongs_to :user, AwradApi.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def create_changeset(entity, attrs, user_id) do
    entity
    |> change(Map.put(attrs, :user_id, user_id))
    |> validate_required([
      :user_id,
      :entity_type,
      :entity_id,
      :incarnation,
      :version,
      :sync_revision,
      :document
    ])
    |> validate_inclusion(:entity_type, ~w(custom_dhikr goal))
    |> validate_inclusion(:state, ~w(active deleted purged))
    |> validate_number(:incarnation, greater_than: 0)
    |> validate_number(:version, greater_than: 0)
    |> validate_number(:sync_revision, greater_than: 0)
    |> unique_constraint([:user_id, :entity_type, :entity_id],
      name: :progress_sync_entities_identity_index
    )
  end
end
