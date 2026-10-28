defmodule Awrad.Sync.Head do
  @moduledoc """
  An account's head revision: the revision of its last applied command (0
  before the first). The row is locked `FOR UPDATE` for a whole batch, which
  serializes the account's batches.
  """

  use Ecto.Schema

  @primary_key {:id, Awrad.UUIDv7, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "sync_heads" do
    field :user_id, :binary_id
    field :head_revision, :integer, default: 0

    timestamps(type: :utc_datetime)
  end
end
