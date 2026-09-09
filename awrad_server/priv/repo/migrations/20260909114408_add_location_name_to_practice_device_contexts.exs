defmodule AwradServer.Repo.Migrations.AddLocationNameToPracticeDeviceContexts do
  use Ecto.Migration

  def change do
    alter table(:practice_device_contexts) do
      add :location_name, :string
    end
  end
end
