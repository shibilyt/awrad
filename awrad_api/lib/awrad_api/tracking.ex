defmodule AwradApi.Tracking do
  @moduledoc """
  Authenticated context boundary for the canonical progress graph.

  Client-created UUIDv4 values are accepted by schema changesets, while user
  ownership and parent ownership are always derived from the authenticated
  scope and server-side queries.
  """

  import Ecto.Query

  alias AwradApi.Accounts.{Scope, User}
  alias AwradApi.Repo
  alias AwradApi.Tracking.{CountEntry, Goal, GoalReminder, GoalSlot}

  def create_goal(%Scope{user: %User{id: user_id}}, attrs) do
    %Goal{}
    |> Goal.for_user_changeset(drop_ownership(attrs), user_id)
    |> Repo.insert()
  end

  def create_slot(%Scope{user: %User{id: user_id}}, goal_id, attrs) do
    with {:ok, %Goal{} = goal} <- owned_goal(user_id, goal_id) do
      %GoalSlot{}
      |> GoalSlot.for_goal_changeset(drop_ownership(attrs), goal.id)
      |> Repo.insert()
    end
  end

  def create_reminder(%Scope{user: %User{id: user_id}}, goal_id, attrs) do
    with {:ok, %Goal{} = goal} <- owned_goal(user_id, goal_id),
         :ok <- validate_optional_slot(goal.id, value(attrs, :slot_id)) do
      %GoalReminder{}
      |> GoalReminder.for_goal_changeset(drop_ownership(attrs), goal.id)
      |> Repo.insert()
    end
  end

  def create_count_entry(%Scope{user: %User{id: user_id}}, goal_id, slot_id, attrs) do
    with {:ok, %Goal{} = goal} <- owned_goal(user_id, goal_id),
         :ok <- validate_slot(goal.id, slot_id) do
      attrs =
        attrs |> drop_ownership() |> Map.put(:goal_id, goal.id) |> Map.put(:slot_id, slot_id)

      %CountEntry{}
      |> CountEntry.for_user_changeset(attrs, user_id)
      |> Repo.insert()
    end
  end

  defp owned_goal(user_id, goal_id) do
    case Repo.one(from goal in Goal, where: goal.id == ^goal_id and goal.user_id == ^user_id) do
      nil -> {:error, :not_found}
      goal -> {:ok, goal}
    end
  end

  defp validate_optional_slot(_goal_id, nil), do: :ok
  defp validate_optional_slot(goal_id, slot_id), do: validate_slot(goal_id, slot_id)

  defp validate_slot(goal_id, slot_id) do
    if Repo.exists?(
         from slot in GoalSlot, where: slot.id == ^slot_id and slot.goal_id == ^goal_id
       ) do
      :ok
    else
      {:error, :invalid_slot}
    end
  end

  defp drop_ownership(attrs) when is_map(attrs) do
    attrs
    |> Map.drop([:user_id, "user_id", :goal_id, "goal_id"])
  end

  defp value(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
end
