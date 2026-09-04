defmodule AwradServer.ProgressSync.ReceiptAdoption do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "progress_sync_receipt_adoptions" do
    field :actor_sequence, :integer
    belongs_to :user, AwradServer.Accounts.User
    belongs_to :actor, AwradServer.ProgressSync.Actor

    belongs_to :command, AwradServer.ProgressSync.CommandReceipt,
      foreign_key: :command_id,
      references: :command_id

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(adoption, attrs, user_id, actor_id, command_id) do
    adoption
    |> cast(attrs, [:actor_sequence])
    |> put_change(:user_id, user_id)
    |> put_change(:actor_id, actor_id)
    |> put_change(:command_id, command_id)
    |> validate_required([:user_id, :actor_id, :command_id, :actor_sequence])
    |> validate_number(:actor_sequence, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
    |> foreign_key_constraint(:command_id)
    |> unique_constraint([:user_id, :actor_id, :actor_sequence],
      name: :progress_sync_adoptions_actor_sequence_index
    )
    |> unique_constraint([:user_id, :actor_id, :command_id],
      name: :progress_sync_adoptions_actor_command_index
    )
  end
end
