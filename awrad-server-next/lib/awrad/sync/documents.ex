defmodule Awrad.Sync.Documents do
  @moduledoc """
  Checks a put's document (`contracts/sync/v1/README.md`, rule 3): its size,
  then its shape for the entity type. Field errors point into the document
  (`/title/en`); a receipt puts `/document` in front.

    * Any document: at most 64 KB as compact UTF-8 JSON with non-ASCII
      unescaped (`document_too_large`). Checked first, so the shape checks
      never walk an oversized document.
    * `custom_dhikr`: `Awrad.Sync.CustomDhikrDocument`.
    * `user_tag`: `{name, normalized_name}`; `name` already in display form
      with 1–40 graphemes and at most 128 bytes (`Awrad.Sync.TagName`), and
      `normalized_name` equal to the server's fold of it (`mismatch`).
    * `dhikr_personal`: `{tag_ids}`, at most 20 distinct UUIDs.
    * `practice_policy`: `Awrad.Sync.PracticePolicyDocument` (slice 3d).
    * `goal` and `goal_order`: `Awrad.Sync.GoalDocument` (slice 4), the goal
      rules included.

  Which tags, dhikrs and goals exist is the entity rules' job, not this module's.
  """

  alias Awrad.Sync.{CustomDhikrDocument, GoalDocument, PracticePolicyDocument, TagName}

  @max_bytes 64 * 1024
  @max_tags 20

  @type error :: CustomDhikrDocument.error()

  @doc "`:ok`, `{:error, :document_too_large}` or `{:error, {:document_invalid, errors}}`."
  @spec check(String.t(), map()) ::
          :ok | {:error, :document_too_large | {:document_invalid, [error(), ...]}}
  def check(entity_type, document) when is_map(document) do
    if byte_size(Jason.encode!(document)) > @max_bytes do
      {:error, :document_too_large}
    else
      case errors(entity_type, document) do
        [] -> :ok
        errors -> {:error, {:document_invalid, errors}}
      end
    end
  end

  @doc "The shape errors of `document` for `entity_type`, sorted by field and code."
  @spec errors(String.t(), map()) :: [error()]
  def errors("custom_dhikr", document), do: CustomDhikrDocument.errors(document)
  def errors("user_tag", document), do: document |> tag_errors() |> sorted()
  def errors("dhikr_personal", document), do: document |> personal_errors() |> sorted()
  def errors("practice_policy", document), do: PracticePolicyDocument.errors(document)
  def errors("goal", document), do: GoalDocument.goal_errors(document)
  def errors("goal_order", document), do: GoalDocument.goal_order_errors(document)

  defp tag_errors(document) do
    unknown(document, ~w(name normalized_name)) ++
      case {Map.fetch(document, "name"), Map.fetch(document, "normalized_name")} do
        {{:ok, name}, normalized} when is_binary(name) -> tag_name(name, normalized)
        {name, normalized} -> missing_or_invalid(name, "/name") ++ normalized_name(normalized)
      end
  end

  defp tag_name(name, normalized) do
    case TagName.normalize(name) do
      {:ok, ^name, folded} ->
        case normalized do
          {:ok, ^folded} -> []
          {:ok, value} when is_binary(value) -> [{"/normalized_name", "mismatch"}]
          other -> normalized_name(other)
        end

      {:ok, _display, _folded} ->
        [{"/name", "invalid"} | normalized_name(normalized)]

      {:error, :empty} ->
        [{"/name", "blank"} | normalized_name(normalized)]

      {:error, _too_long} ->
        [{"/name", "too_long"} | normalized_name(normalized)]
    end
  end

  # normalized_name when the name itself is wrong: only its own shape.
  defp normalized_name({:ok, value}) when is_binary(value) do
    if String.trim(value) == "", do: [{"/normalized_name", "blank"}], else: []
  end

  defp normalized_name(other), do: missing_or_invalid(other, "/normalized_name")

  defp personal_errors(document) do
    unknown(document, ["tag_ids"]) ++
      case Map.fetch(document, "tag_ids") do
        {:ok, ids} when is_list(ids) -> tag_ids(ids)
        other -> missing_or_invalid(other, "/tag_ids")
      end
  end

  defp tag_ids(ids) do
    too_many = if length(ids) > @max_tags, do: [{"/tag_ids", "too_many"}], else: []

    invalid =
      for {id, index} <- Enum.with_index(ids),
          not Awrad.ID.valid?(id),
          do: {"/tag_ids/#{index}", "invalid"}

    duplicate = if Enum.uniq(ids) != ids, do: [{"/tag_ids", "duplicate"}], else: []

    too_many ++ invalid ++ duplicate
  end

  defp unknown(document, members) do
    for key <- Map.keys(document), key not in members, do: {pointer(key), "not_allowed"}
  end

  defp missing_or_invalid(:error, field), do: [{field, "required"}]
  defp missing_or_invalid({:ok, nil}, field), do: [{field, "required"}]
  defp missing_or_invalid({:ok, _value}, field), do: [{field, "invalid"}]

  defp pointer(key), do: "/" <> (key |> String.replace("~", "~0") |> String.replace("/", "~1"))

  defp sorted(errors) do
    errors
    |> Enum.sort()
    |> Enum.map(fn {field, code} -> %{"field" => field, "code" => code} end)
  end
end
