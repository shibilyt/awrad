defmodule AwradServer.ProgressSync.TransferPage do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "progress_sync_transfer_pages" do
    field :page_number, :integer
    field :item_count, :integer
    field :payload, :map
    field :checksum, :binary
    belongs_to :session, AwradServer.ProgressSync.TransferSession
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(page, attrs, session_id) do
    page
    |> change(Map.put(attrs, :session_id, session_id))
    |> validate_required([:session_id, :page_number, :item_count, :payload, :checksum])
    |> validate_number(:page_number, greater_than: 0)
    |> validate_number(:item_count, greater_than_or_equal_to: 0)
    |> unique_constraint([:session_id, :page_number])
  end
end
