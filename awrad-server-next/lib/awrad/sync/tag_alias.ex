defmodule Awrad.Sync.TagAlias do
  @moduledoc """
  A merged tag ID (`alias_id`) and the tag it was merged into (`tag_id`).
  Later `dhikr_personal` documents naming the alias are rewritten to the tag,
  and `user_tag` commands on the alias are `gone`.
  """

  use Ecto.Schema

  @primary_key {:id, Awrad.UUIDv7, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "sync_tag_aliases" do
    field :user_id, :binary_id
    field :alias_id, Ecto.UUID
    field :tag_id, Ecto.UUID

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
