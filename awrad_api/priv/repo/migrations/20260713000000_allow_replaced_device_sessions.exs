defmodule AwradApi.Repo.Migrations.AllowReplacedDeviceSessions do
  use Ecto.Migration

  def change do
    drop unique_index(:auth_sessions, [:user_id, :device_id_hash])

    create unique_index(:auth_sessions, [:user_id, :device_id_hash],
             where: "revoked_at IS NULL"
           )
  end
end
