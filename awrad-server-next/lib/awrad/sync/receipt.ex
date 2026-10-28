defmodule Awrad.Sync.Receipt do
  @moduledoc """
  A command's first receipt, kept 90 days (`contracts/sync/v1/README.md`, rule 1):
  the command ID, the SHA-256 of its canonical payload, and the receipt as
  sent. A repeat with the same payload replays it as `duplicate`; a different
  payload is `command_id_reused`.
  """

  use Ecto.Schema

  alias Awrad.Sync.Entity

  @primary_key {:id, Awrad.UUIDv7, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "sync_receipts" do
    field :user_id, :binary_id
    field :command_id, Ecto.UUID
    field :payload_hash, :binary
    field :receipt, :map

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  A `rejected` receipt (`$defs/rejected_receipt`): `fields` point into the
  command, and `current` is the server's copy of the entity, or `nil`.
  """
  @spec rejected(map(), String.t(), [map()], Entity.t() | nil) :: map()
  def rejected(command, code, fields, entity) do
    %{
      "command_id" => command["command_id"],
      "status" => "rejected",
      "code" => code,
      "fields" => fields,
      "current" => Entity.current(entity)
    }
  end

  @doc """
  The SHA-256 of a command's payload (`entity_type`, `entity_id`, `op`,
  `base_version`, `document`) as canonical JSON: object members sorted by
  name, so member order doesn't matter.
  """
  @spec payload_hash(map()) :: binary()
  def payload_hash(command) when is_map(command) do
    payload = Map.take(command, ~w(entity_type entity_id op base_version document))
    :crypto.hash(:sha256, canonical(payload))
  end

  defp canonical(map) when is_map(map) do
    members =
      map
      |> Enum.sort_by(fn {key, _value} -> key end)
      |> Enum.map_intersperse(",", fn {key, value} ->
        [Jason.encode!(key), ":", canonical(value)]
      end)

    ["{", members, "}"]
  end

  defp canonical(list) when is_list(list),
    do: ["[", Enum.map_intersperse(list, ",", &canonical/1), "]"]

  defp canonical(value), do: Jason.encode!(value)
end
