defmodule AwradApi.CommunityTest do
  use AwradApi.DataCase, async: true

  alias AwradApi.Community
  alias AwradApi.Dhikr.Dhikr
  alias AwradApi.ProgressSync.{CountProjection, EntityRecord}
  alias AwradApi.Tracking

  import AwradApi.AccountsFixtures

  test "returns an empty seven-day series" do
    today = ~D[2026-07-19]
    stats = Community.stats(today)

    assert stats.total_tracked_goals == 0
    assert stats.approximate_total_counts == "0"
    assert stats.approximate_dhikr_hours == 0.0
    assert stats.count_semantics == "current_canonical_net"
    assert stats.seconds_per_count == 1

    assert stats.daily_counts ==
             Enum.map(
               Date.range(~D[2026-07-13], today),
               &%{date: Date.to_iso8601(&1), approximate_count: "0"}
             )
  end

  test "aggregates each current active goal projection across users" do
    today = ~D[2026-07-19]
    first_scope = user_scope_fixture()
    second_scope = user_scope_fixture()
    large_count = 9_007_199_254_740_993

    {current_goal, current_slot} = bucket(first_scope, 2, "active")
    insert_projection(first_scope, current_goal, current_slot, today, 2, large_count)
    insert_projection(first_scope, current_goal, current_slot, Date.add(today, -20), 2, 20)
    insert_projection(first_scope, current_goal, current_slot, today, 1, 999)

    {_paused_goal, _paused_slot} = bucket(first_scope, 1, "active", %{"is_active" => false})

    {_completed_goal, _completed_slot} =
      bucket(first_scope, 1, "active", %{"completed_at" => "2026-07-18T00:00:00Z"})

    {deleted_goal, deleted_slot} = bucket(first_scope, 1, "deleted")
    insert_projection(first_scope, deleted_goal, deleted_slot, today, 1, 100)

    {purged_goal, purged_slot} = bucket(first_scope, 1, "purged")
    insert_projection(first_scope, purged_goal, purged_slot, today, 1, 200)

    {other_goal, other_slot} = bucket(second_scope, 1, "active")
    insert_projection(second_scope, other_goal, other_slot, today, 1, 30)

    stats = Community.stats(today)

    assert stats.total_tracked_goals == 4
    assert stats.approximate_total_counts == Integer.to_string(large_count + 50)

    assert Enum.map(stats.daily_counts, & &1.date) ==
             Enum.map(Date.range(~D[2026-07-13], today), &Date.to_iso8601/1)

    assert Enum.map(stats.daily_counts, & &1.approximate_count) ==
             ["0", "0", "0", "0", "0", "0", Integer.to_string(large_count + 30)]
  end

  defp bucket(scope, incarnation, state, document \\ %{}) do
    dhikr = Repo.insert!(Dhikr.changeset(%Dhikr{}, %{arabic: "test"}))

    {:ok, goal} =
      Tracking.create_goal(scope, %{
        id: Ecto.UUID.generate(),
        dhikr_id: dhikr.id,
        start_date: ~D[2026-07-01]
      })

    {:ok, slot} =
      Tracking.create_slot(scope, goal.id, %{id: Ecto.UUID.generate(), target_count: 100})

    state_fields = entity_state_fields(state, document)

    %{user_id: scope.user.id, entity_type: "goal", entity_id: goal.id}
    |> Map.merge(%{incarnation: incarnation, version: 1, sync_revision: 1, state: state})
    |> Map.merge(state_fields)
    |> then(&struct!(EntityRecord, &1))
    |> Repo.insert!()

    {goal, slot}
  end

  defp insert_projection(scope, goal, slot, date, incarnation, count) do
    Repo.insert!(%CountProjection{
      user_id: scope.user.id,
      goal_id: goal.id,
      slot_id: slot.id,
      local_date: date,
      entity_incarnation: incarnation,
      count: count,
      sync_revision: 1
    })
  end

  defp entity_state_fields("active", document), do: %{document: document}

  defp entity_state_fields("deleted", document) do
    deleted_at = ~U[2026-07-18 00:00:00Z]
    %{document: document, deleted_at: deleted_at, purge_after: DateTime.add(deleted_at, 30, :day)}
  end

  defp entity_state_fields("purged", _document) do
    %{document: nil, deleted_at: ~U[2026-06-01 00:00:00Z], purged_at: ~U[2026-07-01 00:00:00Z]}
  end
end
