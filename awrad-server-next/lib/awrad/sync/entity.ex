defmodule Awrad.Sync.Entity do
  @moduledoc """
  A synced entity's latest state (`contracts/sync/v1/README.md`): its type and
  ID, version, the revision of its last change, `active` or `deleted`, and the
  whole document (`nil` once deleted; the row stays as a tombstone).
  """

  use Ecto.Schema

  @primary_key {:id, Awrad.UUIDv7, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "sync_entities" do
    field :user_id, :binary_id
    field :entity_type, :string
    field :entity_id, Ecto.UUID
    field :version, :integer
    field :revision, :integer
    field :state, :string
    field :document, :map

    timestamps(type: :utc_datetime)
  end

  @doc "The entity as receipts carry it (`$defs/current`), or `nil` when there's none."
  @spec current(t() | nil) :: map() | nil
  def current(nil), do: nil

  def current(%__MODULE__{} = entity),
    do: %{"version" => entity.version, "state" => entity.state, "document" => entity.document}

  @doc "The entity as the changes feed lists it (`$defs/change`)."
  @spec change(t()) :: map()
  def change(%__MODULE__{} = entity) do
    %{
      "entity_type" => entity.entity_type,
      "entity_id" => entity.entity_id,
      "state" => entity.state,
      "version" => entity.version,
      "revision" => entity.revision,
      "document" => entity.document
    }
  end
end
