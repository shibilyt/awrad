defmodule AwradApi.Accounts.AuthSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "auth_sessions" do
    field :device_id_hash, :binary
    field :device_name, :string
    field :platform, :string
    field :last_seen_at, :utc_datetime
    field :idle_expires_at, :utc_datetime
    field :absolute_expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :revoke_reason, :string
    belongs_to :user, AwradApi.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def create_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :user_id,
      :device_id_hash,
      :device_name,
      :platform,
      :last_seen_at,
      :idle_expires_at,
      :absolute_expires_at
    ])
    |> validate_required([
      :user_id,
      :device_id_hash,
      :device_name,
      :platform,
      :last_seen_at,
      :idle_expires_at,
      :absolute_expires_at
    ])
    |> validate_length(:device_name, max: 120)
    |> validate_inclusion(:platform, ["android", "ios", "legacy"])
    |> unique_constraint([:user_id, :device_id_hash])
  end

  def active?(%__MODULE__{} = session, now \\ DateTime.utc_now(:second)) do
    is_nil(session.revoked_at) and DateTime.after?(session.idle_expires_at, now) and
      DateTime.after?(session.absolute_expires_at, now)
  end
end
