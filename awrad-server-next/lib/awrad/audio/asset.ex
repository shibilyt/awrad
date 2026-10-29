defmodule Awrad.Audio.Asset do
  @moduledoc """
  One upload of a recording (`audio_assets`), from its reservation to the
  deletion of its object:

    * `pending`: reserved, with a signed `PUT` link valid until
      `upload_expires_at`; counts against the quota;
    * `ready`: confirmed (`ready_at`); a custom dhikr document may name it;
    * `deleting`: abandoned, unreferenced, mismatched or of a deleted account.
      Clients never see it; `Awrad.Audio.Cleaner` deletes its object from
      `delete_after` on, then the row.

  `user_id` is `nil` once the account is deleted; `object_key` still names the
  object.
  """

  use Ecto.Schema

  @primary_key {:id, Awrad.UUIDv7, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "audio_assets" do
    field :user_id, :binary_id
    field :asset_id, Ecto.UUID
    field :object_key, :string
    field :byte_size, :integer
    field :content_type, :string
    field :sha256, :string
    field :status, :string
    field :upload_expires_at, :utc_datetime
    field :ready_at, :utc_datetime
    field :referenced, :boolean, default: false
    field :last_referenced_at, :utc_datetime
    field :delete_after, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc "The object key of an account's recording: `users/<account_id>/audio/<asset_id>`."
  @spec object_key(Ecto.UUID.t(), Ecto.UUID.t()) :: String.t()
  def object_key(user_id, asset_id), do: "users/#{user_id}/audio/#{asset_id}"

  @doc "A ready asset as `Awrad.Audio` returns it."
  @spec summary(t()) :: Awrad.Audio.asset()
  def summary(%__MODULE__{status: "ready"} = asset) do
    %{
      asset_id: asset.asset_id,
      byte_size: asset.byte_size,
      content_type: asset.content_type,
      created_at: asset.ready_at
    }
  end
end
