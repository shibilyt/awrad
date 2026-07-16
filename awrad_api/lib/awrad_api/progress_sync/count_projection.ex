defmodule AwradApi.ProgressSync.CountProjection do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "progress_sync_count_projections" do
    field :local_date, :date
    field :entity_incarnation, :integer
    field :count, :integer, default: 0
    field :sync_revision, :integer, default: 0

    belongs_to :user, AwradApi.Accounts.User
    belongs_to :goal, AwradApi.Tracking.Goal
    belongs_to :slot, AwradApi.Tracking.GoalSlot

    timestamps(type: :utc_datetime)
  end

  def create_changeset(projection, attrs, user_id) do
    projection
    |> change(Map.put(attrs, :user_id, user_id))
    |> validate_required([
      :user_id,
      :goal_id,
      :slot_id,
      :local_date,
      :entity_incarnation,
      :count,
      :sync_revision
    ])
    |> validate_projection()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:slot_id)
    |> unique_constraint([:user_id, :goal_id, :slot_id, :local_date, :entity_incarnation],
      name: :progress_sync_count_projections_bucket_index
    )
  end

  def update_changeset(projection, count, revision) do
    projection
    |> change(count: count, sync_revision: revision)
    |> validate_projection()
  end

  defp validate_projection(changeset) do
    changeset
    |> validate_number(:entity_incarnation, greater_than: 0)
    |> validate_number(:count, greater_than_or_equal_to: 0)
    |> validate_number(:sync_revision, greater_than_or_equal_to: 0)
  end
end
