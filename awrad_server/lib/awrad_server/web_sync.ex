defmodule AwradServer.WebSync do
  @moduledoc """
  Browser-facing adapter for the shared progress synchronization boundary.

  Browser requests never provide an actor sequence or ownership field. This
  module resolves the authenticated user, validates the browser installation
  and count bucket, then delegates the mutation to `AwradServer.ProgressSync`.
  """

  import Ecto.Query

  alias AwradServer.Accounts.Scope
  alias AwradServer.Practice.Eligibility
  alias AwradServer.ProgressSync
  alias AwradServer.ProgressSync.EntityRecord
  alias AwradServer.ProgressSync.CountProjection
  alias AwradServer.Repo
  alias AwradServer.Tracking.{Goal, GoalSlot}

  @uuid_v4 ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

  @doc "Executes one manual browser increment through the canonical ledger."
  def increment(%Scope{user: %{confirmed_at: %DateTime{}} = user} = scope, installation_id, attrs)
      when is_map(attrs) do
    with {:ok, installation_id} <- uuid_v4(installation_id),
         {:ok, command_id} <- uuid_v4(value(attrs, :command_id)),
         {:ok, goal_id} <- uuid_v4(value(attrs, :goal_id)),
         {:ok, slot_id} <- uuid_v4(value(attrs, :slot_id)),
         {:ok, local_date} <- local_date(value(attrs, :local_date)),
         :ok <- valid_timezone(value(attrs, :timezone)),
         {:ok, %{goal: goal, slot: slot, entity_incarnation: entity_incarnation}} <-
           load_bucket(user.id, goal_id, slot_id),
         :ok <- eligibility_allows?(goal, slot, local_date) do
      with {:ok, actor} <- ProgressSync.ensure_actor(scope, installation_id),
           {:ok, result} <-
             ProgressSync.execute_next_count_command(
               scope,
               actor.id,
               %{
                 command_id: command_id,
                 payload: %{
                   "type" => "increment",
                   "goal_id" => goal_id,
                   "slot_id" => slot_id,
                   "local_date" => Date.to_iso8601(local_date),
                   "amount" => "1",
                   "entity_incarnation" => Integer.to_string(entity_incarnation)
                 }
               },
               fn ->
                 with {:ok,
                       %{
                         goal: current_goal,
                         slot: current_slot,
                         entity_incarnation: current_incarnation
                       }} <-
                        load_bucket(user.id, goal_id, slot_id),
                      true <- current_incarnation == entity_incarnation,
                      :ok <- eligibility_allows?(current_goal, current_slot, local_date),
                      :ok <-
                        cap_allows?(
                          user.id,
                          current_goal,
                          current_slot,
                          current_incarnation,
                          local_date
                        ) do
                   :ok
                 else
                   false -> {:error, :stale_entity}
                   {:error, reason} -> {:error, reason}
                 end
               end
             ) do
        {:ok, result}
      end
    end
  end

  def increment(%Scope{user: %{}}, _installation_id, _attrs),
    do: {:error, :email_not_verified}

  def increment(_scope, _installation_id, _attrs), do: {:error, :unauthenticated}

  defp load_bucket(user_id, goal_id, slot_id) do
    query =
      from entity in EntityRecord,
        join: goal in Goal,
        on: goal.id == entity.entity_id,
        join: slot in GoalSlot,
        on: slot.goal_id == goal.id,
        where:
          entity.user_id == ^user_id and entity.entity_type == "goal" and
            entity.entity_id == ^goal_id and entity.state == "active" and
            goal.user_id == ^user_id and slot.id == ^slot_id,
        select: %{goal: goal, slot: slot, entity_incarnation: entity.incarnation}

    case Repo.one(query) do
      nil ->
        {:error, :counting_unavailable}

      %{goal: %{deleted_at: deleted_at}} when not is_nil(deleted_at) ->
        {:error, :deleted}

      bucket ->
        {:ok, bucket}
    end
  end

  defp cap_allows?(user_id, goal, slot, entity_incarnation, local_date) do
    count = current_cap_count(user_id, goal, slot, entity_incarnation, local_date)
    target_count = slot.target_count || goal.target_count
    maximum_count = slot.maximum_count || goal.maximum_count

    case slot.cap_behavior do
      "block_at_target" when is_integer(target_count) and count >= target_count ->
        {:error, :count_cap_reached}

      "block_at_maximum" when is_integer(maximum_count) and count >= maximum_count ->
        {:error, :count_cap_reached}

      _cap_behavior ->
        :ok
    end
  end

  defp eligibility_allows?(goal, slot, date) do
    case Eligibility.evaluate(goal, slot, date) do
      :allowed -> :ok
      {:blocked, reason} -> {:error, reason}
    end
  end

  defp current_cap_count(user_id, %{target_policy: "cumulative_total"}, slot, incarnation, _date) do
    Repo.one(
      from projection in CountProjection,
        where:
          projection.user_id == ^user_id and projection.goal_id == ^slot.goal_id and
            projection.slot_id == ^slot.id and projection.entity_incarnation == ^incarnation,
        select: coalesce(sum(projection.count), 0)
    )
    |> current_cap_count_value()
  end

  defp current_cap_count(user_id, goal, slot, incarnation, date) do
    Repo.one(
      from projection in CountProjection,
        where:
          projection.user_id == ^user_id and projection.goal_id == ^goal.id and
            projection.slot_id == ^slot.id and projection.local_date == ^date and
            projection.entity_incarnation == ^incarnation,
        select: coalesce(sum(projection.count), 0)
    )
    |> current_cap_count_value()
  end

  defp current_cap_count_value(%Decimal{} = value), do: Decimal.to_integer(value)
  defp current_cap_count_value(value), do: value

  defp local_date(%Date{} = date), do: {:ok, date}
  defp local_date(value) when is_binary(value), do: Date.from_iso8601(value)
  defp local_date(_value), do: {:error, :invalid_local_date}

  defp valid_timezone(value) when is_binary(value) and byte_size(value) in 1..128, do: :ok
  defp valid_timezone(_value), do: {:error, :invalid_timezone}

  defp uuid_v4(value) when is_binary(value) do
    with {:ok, normalized} <- Ecto.UUID.cast(value),
         true <- value == normalized,
         true <- Regex.match?(@uuid_v4, normalized) do
      {:ok, normalized}
    else
      _other -> {:error, :invalid_uuid_v4}
    end
  end

  defp uuid_v4(_value), do: {:error, :invalid_uuid_v4}

  defp value(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
end
