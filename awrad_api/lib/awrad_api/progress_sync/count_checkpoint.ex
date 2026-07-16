defmodule AwradApi.ProgressSync.CountCheckpoint do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "progress_sync_count_checkpoints" do
    field :local_date, :date
    field :entity_incarnation, :integer
    field :through_revision, :integer

    belongs_to :user, AwradApi.Accounts.User
    belongs_to :goal, AwradApi.Tracking.Goal
    belongs_to :slot, AwradApi.Tracking.GoalSlot
    belongs_to :credit, AwradApi.ProgressSync.CountCredit

    timestamps(type: :utc_datetime)
  end

  def create_changeset(checkpoint, attrs, user_id) do
    checkpoint
    |> change(Map.put(attrs, :user_id, user_id))
    |> validate_required([
      :user_id,
      :goal_id,
      :slot_id,
      :local_date,
      :entity_incarnation,
      :through_revision,
      :credit_id
    ])
    |> validate_checkpoint()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:slot_id)
    |> foreign_key_constraint(:credit_id)
    |> unique_constraint([:user_id, :goal_id, :slot_id, :local_date, :entity_incarnation],
      name: :progress_sync_count_checkpoints_bucket_index
    )
    |> unique_constraint(:credit_id)
  end

  def advance_changeset(checkpoint, through_revision, credit_id) do
    checkpoint
    |> change(through_revision: through_revision, credit_id: credit_id)
    |> validate_checkpoint()
    |> foreign_key_constraint(:credit_id)
    |> unique_constraint(:credit_id)
  end

  defp validate_checkpoint(changeset) do
    changeset
    |> validate_number(:entity_incarnation, greater_than: 0)
    |> validate_number(:through_revision, greater_than_or_equal_to: 0)
  end
end
