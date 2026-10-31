defmodule Awrad.Sync.GoalRules do
  @moduledoc """
  The entity rules of slice 4's `goal` and `goal_order` puts
  (`contracts/sync/v1/README.md`, rule 5), and the goals a custom dhikr's
  delete ends (rule 6):

    * a stored goal's `dhikr_id` and `counts` never change
      (`goal_field_immutable`, `immutable` on each changed member), checked
      before its dhikr;
    * a goal's `dhikr_id` must be a built-in dhikr or a custom dhikr the
      account has had (`dhikr_not_found`, `not_found` on `/document/dhikr_id`).
      A deleted custom dhikr is accepted, and a goal of it that hasn't ended
      is stored ended (`dhikr_deleted`);
    * goal limits: no put may leave the account with more than 300 goals that
      haven't ended, or 2,000 goals in all (deleted ones don't count), or
      it's `goal_limit_reached`. Ending a goal is never refused;
    * a goal order keeps only the account's non-deleted goals, in order.

  **The date a server-ended goal gets** is `today` (the UTC date it applies
  the command on), or the goal's `created_on` or last version's `from` if
  one is later.
  """

  import Ecto.Query

  alias Awrad.Dhikrs.Catalog
  alias Awrad.Repo
  alias Awrad.Sync.{Entity, Receipt}

  @max_running 300
  @max_goals 2_000

  @doc "`{:ok, document_to_store}`, or `{:stop, receipt}`."
  @spec check_goal(Ecto.UUID.t(), map(), Entity.t() | nil, Date.t()) ::
          {:ok, map()} | {:stop, map()}
  def check_goal(user_id, %{"document" => document} = command, entity, today) do
    case changed_members(document, entity) do
      [] ->
        check_dhikr(user_id, command, entity, today)

      changed ->
        fields =
          for member <- changed, do: %{"field" => "/document/" <> member, "code" => "immutable"}

        {:stop, Receipt.rejected(command, "goal_field_immutable", fields, entity)}
    end
  end

  # A stored goal's dhikr_id and counts never change (sorted by field).
  defp changed_members(_document, nil), do: []

  defp changed_members(document, %Entity{document: stored}),
    do: for(member <- ~w(counts dhikr_id), document[member] != stored[member], do: member)

  defp check_dhikr(user_id, %{"document" => document} = command, entity, today) do
    case dhikr_state(user_id, document["dhikr_id"]) do
      nil ->
        fields = [%{"field" => "/document/dhikr_id", "code" => "not_found"}]
        {:stop, Receipt.rejected(command, "dhikr_not_found", fields, entity)}

      state ->
        stored = if state == "deleted", do: ended(document, today), else: document

        if over_limits?(user_id, command["entity_id"], stored),
          do: {:stop, Receipt.rejected(command, "goal_limit_reached", [], entity)},
          else: {:ok, stored}
    end
  end

  # "active" for a built-in dhikr or an active custom dhikr, "deleted" for a
  # custom dhikr the account deleted, nil for anything else.
  defp dhikr_state(user_id, dhikr_id) do
    if Catalog.builtin?(dhikr_id) do
      "active"
    else
      Repo.one(
        from e in Entity,
          where: e.user_id == ^user_id and e.entity_type == "custom_dhikr",
          where: e.entity_id == ^dhikr_id,
          select: e.state
      )
    end
  end

  defp over_limits?(user_id, goal_id, document) do
    others = from e in active_goals(user_id), where: e.entity_id != ^goal_id
    running = from e in others, where: fragment("(?->>'ended') IS NULL", e.document)
    adds_running = if document["ended"] == nil, do: 1, else: 0

    Repo.aggregate(others, :count) + 1 > @max_goals or
      Repo.aggregate(running, :count) + adds_running > @max_running
  end

  @doc "The goal order to store: only the account's non-deleted goals, in order."
  @spec check_goal_order(Ecto.UUID.t(), map()) :: {:ok, map()}
  def check_goal_order(user_id, %{"document" => %{"goal_ids" => ids}}) do
    known =
      from(e in active_goals(user_id), where: e.entity_id in ^ids, select: e.entity_id)
      |> Repo.all()
      |> MapSet.new()

    {:ok, %{"goal_ids" => Enum.filter(ids, &MapSet.member?(known, &1))}}
  end

  @doc "The active goals of a custom dhikr that haven't ended: a delete of it ends them."
  @spec running_goals_of(Ecto.UUID.t(), Ecto.UUID.t()) :: [Entity.t()]
  def running_goals_of(user_id, dhikr_id) do
    Repo.all(
      from e in active_goals(user_id),
        where: fragment("?->>'dhikr_id'", e.document) == ^dhikr_id,
        where: fragment("(?->>'ended') IS NULL", e.document)
    )
  end

  @doc "`document` ended because its dhikr was deleted, unless it has ended already."
  @spec ended(map(), Date.t()) :: map()
  def ended(%{"ended" => nil} = document, today) do
    last_from = document["versions"] |> List.last() |> Map.fetch!("from")
    on = Enum.max([Date.to_iso8601(today), document["created_on"], last_from])
    %{document | "ended" => %{"on" => on, "reason" => "dhikr_deleted"}}
  end

  def ended(document, _today), do: document

  defp active_goals(user_id) do
    from e in Entity,
      where: e.user_id == ^user_id and e.entity_type == "goal" and e.state == "active"
  end
end
