defmodule AwradServer.ProgressSync.CountCredit do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "progress_sync_count_credits" do
    field :kind, :string
    field :actor_sequence, :integer
    field :local_date, :date
    field :entity_incarnation, :integer
    field :accepted_revision, :integer
    field :amount, :integer

    belongs_to :user, AwradServer.Accounts.User
    belongs_to :actor, AwradServer.ProgressSync.Actor
    belongs_to :goal, AwradServer.Tracking.Goal
    belongs_to :slot, AwradServer.Tracking.GoalSlot

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def increment_changeset(credit, attrs, user_id) do
    credit
    |> change(Map.put(attrs, :user_id, user_id))
    |> validate_required([
      :id,
      :kind,
      :user_id,
      :actor_id,
      :actor_sequence,
      :goal_id,
      :slot_id,
      :local_date,
      :entity_incarnation,
      :accepted_revision,
      :amount
    ])
    |> validate_inclusion(:kind, ["increment"])
    |> validate_number(:actor_sequence, greater_than: 0)
    |> validate_number(:entity_incarnation, greater_than: 0)
    |> validate_number(:accepted_revision, greater_than: 0)
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:slot_id)
    |> unique_constraint(:id, name: :progress_sync_count_credits_pkey)
    |> unique_constraint([:user_id, :actor_id, :actor_sequence],
      name: :progress_sync_count_credits_actor_sequence_index
    )
  end

  def checkpoint_changeset(credit, attrs, user_id) do
    credit
    |> change(Map.put(attrs, :user_id, user_id))
    |> validate_required([
      :id,
      :kind,
      :user_id,
      :goal_id,
      :slot_id,
      :local_date,
      :entity_incarnation,
      :accepted_revision,
      :amount
    ])
    |> validate_inclusion(:kind, ["checkpoint"])
    |> validate_number(:entity_incarnation, greater_than: 0)
    |> validate_number(:accepted_revision, greater_than_or_equal_to: 0)
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:slot_id)
    |> unique_constraint(:id, name: :progress_sync_count_credits_pkey)
  end
end
