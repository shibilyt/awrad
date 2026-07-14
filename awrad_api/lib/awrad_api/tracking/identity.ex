defmodule AwradApi.Tracking.Identity do
  @moduledoc false

  import Ecto.Changeset

  @uuid_v4 ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

  def put_client_id(changeset, attrs) when is_map(attrs) do
    case Map.get(attrs, :id) || Map.get(attrs, "id") do
      nil ->
        changeset

      id when is_binary(id) ->
        case Ecto.UUID.cast(id) do
          {:ok, normalized} ->
            if Regex.match?(@uuid_v4, normalized) do
              put_change(changeset, :id, normalized)
            else
              add_error(changeset, :id, "must be a UUIDv4")
            end

          :error ->
            add_error(changeset, :id, "must be a UUIDv4")
        end

      _other ->
        add_error(changeset, :id, "must be a UUIDv4")
    end
  end
end
