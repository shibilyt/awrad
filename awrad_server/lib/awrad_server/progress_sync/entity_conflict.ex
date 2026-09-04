defmodule AwradServer.ProgressSync.EntityConflict do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "progress_sync_entity_conflicts" do
    field :command_id, :binary_id
    field :base_version, :integer
    field :sync_revision, :integer
    field :proposed_document, :map
    field :resolved_at, :utc_datetime
    belongs_to :user, AwradServer.Accounts.User
    belongs_to :entity_record, AwradServer.ProgressSync.EntityRecord
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(conflict, attrs, user_id, entity_record_id) do
    conflict
    |> change(Map.merge(attrs, %{user_id: user_id, entity_record_id: entity_record_id}))
    |> validate_required([
      :user_id,
      :entity_record_id,
      :command_id,
      :base_version,
      :sync_revision,
      :proposed_document
    ])
    |> validate_number(:base_version, greater_than_or_equal_to: 0)
    |> validate_number(:sync_revision, greater_than: 0)
    |> unique_constraint([:user_id, :command_id])
  end
end
