defmodule AwradServer.ProgressSync.CountConsumption do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "progress_sync_count_consumptions" do
    field :correction_command_id, :binary_id
    field :accepted_revision, :integer
    field :amount, :integer

    belongs_to :user, AwradServer.Accounts.User
    belongs_to :credit, AwradServer.ProgressSync.CountCredit

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(consumption, attrs, user_id) do
    consumption
    |> change(Map.put(attrs, :user_id, user_id))
    |> validate_required([
      :user_id,
      :correction_command_id,
      :credit_id,
      :accepted_revision,
      :amount
    ])
    |> validate_number(:accepted_revision, greater_than: 0)
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:credit_id)
    |> unique_constraint([:user_id, :correction_command_id, :credit_id],
      name: :progress_sync_count_consumptions_command_credit_index
    )
  end
end
