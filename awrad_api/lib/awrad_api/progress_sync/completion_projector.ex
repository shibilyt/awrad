defmodule AwradApi.ProgressSync.CompletionProjector do
  @moduledoc false

  import Ecto.Query

  alias AwradApi.ProgressSync.{CountProjection, EntityRecord, Materializer}
  alias AwradApi.Repo

  def refresh(user_id, goal_id, incarnation, revision) do
    entity =
      Repo.one(
        from entity in EntityRecord,
          where:
            entity.user_id == ^user_id and entity.entity_type == "goal" and
              entity.entity_id == ^goal_id,
          lock: "FOR UPDATE"
      )

    with %EntityRecord{state: "active", incarnation: ^incarnation} = entity <- entity,
         document when is_map(document) <- entity.document,
         true <- automatic_completion?(document),
         {:ok, threshold} <- completion_threshold(document) do
      total =
        Repo.one(
          from projection in CountProjection,
            where:
              projection.user_id == ^user_id and projection.goal_id == ^goal_id and
                projection.entity_incarnation == ^incarnation,
            select: coalesce(sum(projection.count), 0)
        )
        |> decimal_to_integer()

      project(entity, document, total >= threshold, user_id, revision)
    else
      nil -> :ok
      false -> :ok
      %EntityRecord{} -> :ok
      {:error, :missing_threshold} -> :ok
    end
  end

  defp automatic_completion?(document) do
    document["target_policy"] == "cumulative_total" and
      document["completion_policy"] == "when_target_reached"
  end

  defp completion_threshold(%{"count_policy" => policy}) do
    case policy["completion_threshold"] do
      "any_positive" -> {:ok, 1}
      "minimum" -> positive(policy["minimum_count"])
      "target" -> positive(policy["target_count"])
      "maximum" -> positive(policy["maximum_count"])
      %{"type" => "custom", "count" => count} -> positive(count)
      _ -> {:error, :missing_threshold}
    end
  end

  defp completion_threshold(_), do: {:error, :missing_threshold}
  defp positive(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp positive(_), do: {:error, :missing_threshold}

  defp project(entity, document, true, user_id, revision) do
    if is_nil(document["completed_at"]) do
      completed =
        document
        |> Map.put("completed_at", DateTime.utc_now(:second) |> DateTime.to_iso8601())
        |> Map.put("is_active", false)

      persist(entity, completed, "automatic", user_id, revision)
    else
      :ok
    end
  end

  defp project(
         %EntityRecord{completion_origin: "automatic"} = entity,
         document,
         false,
         user_id,
         revision
       ) do
    reopened = document |> Map.put("completed_at", nil) |> Map.put("is_active", true)
    persist(entity, reopened, nil, user_id, revision)
  end

  defp project(_entity, _document, false, _user_id, _revision), do: :ok

  defp persist(entity, document, origin, user_id, revision) do
    with {:ok, _materialized} <- Materializer.put("goal", document, user_id),
         {:ok, _entity} <-
           entity
           |> Ecto.Changeset.change(
             document: document,
             completion_origin: origin,
             sync_revision: revision
           )
           |> Repo.update() do
      :ok
    end
  end

  defp decimal_to_integer(%Decimal{} = value), do: Decimal.to_integer(value)
  defp decimal_to_integer(value) when is_integer(value), do: value
end
