defmodule AwradServer.ProgressSync.Head do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type :binary_id

  schema "progress_sync_heads" do
    belongs_to :user, AwradServer.Accounts.User, primary_key: true
    field :revision, :integer, default: 0
    field :generation, :integer, default: 1

    timestamps(type: :utc_datetime)
  end

  def changeset(head, attrs) do
    head
    |> cast(attrs, [:revision, :generation])
    |> validate_required([:user_id, :revision, :generation])
    |> validate_number(:revision, greater_than_or_equal_to: 0)
    |> validate_number(:generation, greater_than: 0)
    |> foreign_key_constraint(:user_id)
  end
end
