defmodule AwradServer.PracticeSettings.DeviceContext do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @location_sources ~w(browser manual)
  @uuid_v4 ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "practice_device_contexts" do
    field :installation_id, :binary_id
    field :timezone, :string
    field :latitude, :float
    field :longitude, :float
    field :accuracy_m, :float
    field :location_name, :string
    field :location_source, :string, default: "browser"
    field :revision, :integer, default: 1
    field :last_seen_at, :utc_datetime

    belongs_to :user, AwradServer.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(context, attrs) do
    context
    |> cast(attrs, [
      :installation_id,
      :timezone,
      :latitude,
      :longitude,
      :accuracy_m,
      :location_name,
      :location_source,
      :revision,
      :last_seen_at
    ])
    |> validate_required([
      :installation_id,
      :timezone,
      :location_source,
      :revision,
      :last_seen_at
    ])
    |> validate_uuid_v4(:installation_id)
    |> validate_length(:timezone, min: 1, max: 128)
    |> validate_length(:location_name, max: 160)
    |> validate_inclusion(:location_source, @location_sources)
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:accuracy_m, greater_than_or_equal_to: 0)
    |> validate_location_pair()
    |> validate_number(:revision, greater_than: 0)
    |> unique_constraint([:user_id, :installation_id])
  end

  defp validate_location_pair(changeset) do
    latitude = get_field(changeset, :latitude)
    longitude = get_field(changeset, :longitude)

    if is_nil(latitude) == is_nil(longitude) do
      changeset
    else
      add_error(changeset, :latitude, "latitude and longitude must be provided together")
    end
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
