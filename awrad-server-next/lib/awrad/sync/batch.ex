defmodule Awrad.Sync.Batch do
  @moduledoc """
  The batch envelope (`urn:awrad:sync:1#/$defs/command_batch` and
  `command_envelope`). A batch that breaks it is refused whole, with nothing
  applied (`422 validation_failed`):

    * `batch_size_invalid` on `/commands`: 0 or more than 100 commands;
    * `command_malformed` on `/commands/{i}` or one of its members: not an
      object, an unknown or missing member, a `command_id` or `entity_id`
      that isn't an ID (`Awrad.ID`), an unknown `entity_type` or `op`, a
      `base_version` that isn't an integer from 0 to 2^53 - 1, or a `document`
      missing on a put, present on a delete, or not an object.

  A document's content isn't checked here: a bad one is a `rejected` receipt.
  """

  @max_commands 100
  @max_int 9_007_199_254_740_991
  @entity_types ~w(custom_dhikr user_tag dhikr_personal practice_policy)
  @ops ~w(put delete)
  @members ~w(command_id entity_type entity_id op base_version document)
  @required ~w(command_id entity_type entity_id op base_version)

  @type error :: %{field: String.t(), code: String.t(), detail: String.t()}

  @doc "`:ok`, or every envelope error in order."
  @spec validate([term()]) :: :ok | {:error, [error(), ...]}
  def validate(commands) when is_list(commands) do
    count = length(commands)

    errors =
      if count in 1..@max_commands do
        commands |> Enum.with_index() |> Enum.flat_map(&command_errors/1)
      else
        [
          error(
            "/commands",
            "batch_size_invalid",
            "#{count} commands; a batch holds 1 to #{@max_commands}"
          )
        ]
      end

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp command_errors({command, index}) when is_map(command) do
    path = "/commands/#{index}"

    unknown =
      for key <- command |> Map.keys() |> Enum.sort(), key not in @members do
        error("#{path}/#{escape(key)}", "command_malformed", "isn't a command member")
      end

    missing =
      for key <- @required, not Map.has_key?(command, key) do
        error("#{path}/#{key}", "command_malformed", "is required")
      end

    unknown ++ missing ++ member_errors(command, path)
  end

  defp command_errors({_not_an_object, index}),
    do: [error("/commands/#{index}", "command_malformed", "must be an object")]

  defp member_errors(command, path) do
    checks = [
      {"command_id", &Awrad.ID.valid?/1, "must be a lowercase UUID"},
      {"entity_id", &Awrad.ID.valid?/1, "must be a lowercase UUID"},
      {"entity_type", &(&1 in @entity_types),
       "must be custom_dhikr, user_tag, dhikr_personal or practice_policy"},
      {"op", &(&1 in @ops), "must be put or delete"},
      {"base_version", &(is_integer(&1) and &1 >= 0 and &1 <= @max_int),
       "must be an integer from 0 to 2^53 - 1"}
    ]

    invalid =
      for {key, valid?, detail} <- checks,
          Map.has_key?(command, key),
          not valid?.(command[key]) do
        error("#{path}/#{key}", "command_malformed", detail)
      end

    invalid ++ document_errors(command, path)
  end

  defp document_errors(%{"op" => "put"} = command, path) do
    case Map.fetch(command, "document") do
      {:ok, document} when is_map(document) -> []
      {:ok, _other} -> [error("#{path}/document", "command_malformed", "must be an object")]
      :error -> [error("#{path}/document", "command_malformed", "is required on a put")]
    end
  end

  defp document_errors(%{"op" => "delete"} = command, path) do
    if Map.has_key?(command, "document"),
      do: [error("#{path}/document", "command_malformed", "isn't allowed on a delete")],
      else: []
  end

  defp document_errors(_unknown_op, _path), do: []

  defp error(field, code, detail), do: %{field: field, code: code, detail: detail}

  defp escape(key), do: key |> String.replace("~", "~0") |> String.replace("/", "~1")
end
