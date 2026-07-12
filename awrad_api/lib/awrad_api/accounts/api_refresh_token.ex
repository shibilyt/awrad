defmodule AwradApi.Accounts.ApiRefreshToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "api_refresh_tokens" do
    field :token_hash, :binary
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :rotation_request_id, Ecto.UUID
    field :retry_token_ciphertext, :binary
    field :retry_expires_at, :utc_datetime
    belongs_to :session, AwradApi.Accounts.AuthSession
    belongs_to :parent, __MODULE__
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def create_changeset(token, attrs) do
    token
    |> cast(attrs, [:session_id, :parent_id, :token_hash, :expires_at])
    |> validate_required([:session_id, :token_hash, :expires_at])
    |> unique_constraint(:token_hash)
  end
end
