defmodule AwradApi.ProgressSync.Actor do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias AwradApi.Tracking.Identity

  @uuid_v4 ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "progress_sync_actors" do
    field :installation_id, :binary_id
    field :incarnation, :integer
    field :next_expected_sequence, :integer, default: 1
    field :applied_revision, :integer, default: 0
    field :safe_compaction_revision, :integer, default: 0
    field :lease_expires_at, :utc_datetime
    field :last_seen_at, :utc_datetime
    field :retired_at, :utc_datetime

    belongs_to :user, AwradApi.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def registration_changeset(actor, attrs, user_id, now, lease_expires_at) do
    actor
    |> cast(attrs, [:installation_id, :incarnation])
    |> Identity.put_client_id(attrs)
    |> put_change(:user_id, user_id)
    |> put_change(:last_seen_at, now)
    |> put_change(:lease_expires_at, lease_expires_at)
    |> validate_required([
      :id,
      :user_id,
      :installation_id,
      :incarnation,
      :last_seen_at,
      :lease_expires_at
    ])
    |> validate_uuid_v4(:installation_id)
    |> validate_number(:incarnation, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :installation_id, :incarnation],
      name: :progress_sync_actors_installation_incarnation_index
    )
  end

  defp validate_uuid_v4(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      case Ecto.UUID.cast(value) do
        {:ok, normalized} ->
          if Regex.match?(@uuid_v4, normalized), do: [], else: [{field, "must be a UUIDv4"}]

        :error ->
          [{field, "must be a UUIDv4"}]
      end
    end)
  end
end
