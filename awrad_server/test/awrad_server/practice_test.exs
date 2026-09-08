defmodule AwradServer.PracticeTest do
  use AwradServer.DataCase, async: true

  alias AwradServer.Dhikr.{Dhikr, DhikrTranslation}
  alias AwradServer.Practice
  alias AwradServer.ProgressSync.{CountProjection, EntityRecord}
  alias AwradServer.Tracking

  import AwradServer.AccountsFixtures

  test "lists an owned goal with its dhikr and today's canonical progress" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)
    other_scope = user_scope_fixture()
    create_bucket(other_scope)

    Repo.insert!(%CountProjection{
      user_id: scope.user.id,
      goal_id: goal.id,
      slot_id: slot.id,
      local_date: ~D[2026-07-16],
      entity_incarnation: 1,
      count: 7,
      sync_revision: 1
    })

    assert [
             %{
               id: goal_id,
               title: "Morning remembrance",
               today_count: 7,
               target_count: 100,
               web_countable?: true
             }
           ] = Practice.list_goals(scope, ~D[2026-07-16])

    assert goal_id == goal.id
  end

  test "searches built-in and owned dhikr without leaking another user's custom dhikr" do
    scope = user_scope_fixture()
    other_scope = user_scope_fixture()

    builtin = insert_dhikr(nil, "Morning remembrance", "morning")
    owned = insert_dhikr(scope.user.id, "Morning protection", "morning")
    insert_dhikr(other_scope.user.id, "Morning private", "morning")
    insert_dhikr(scope.user.id, "Evening remembrance", "evening")

    results = Practice.search_dhikr(scope, %{query: "morning", category: "morning"})

    assert Enum.map(results, & &1.id) == [builtin.id, owned.id]
    assert Enum.all?(results, &(&1.category == "morning"))
    assert Enum.all?(results, &is_binary(&1.title))
  end

  test "builds mobile-ordered categories without leaking another user's dhikr" do
    scope = user_scope_fixture()
    other_scope = user_scope_fixture()

    insert_dhikr(nil, "Morning remembrance", "morning")
    insert_dhikr(scope.user.id, "Morning protection", "morning")
    insert_dhikr(scope.user.id, "Evening remembrance", "evening")
    insert_dhikr(other_scope.user.id, "Private praise", "praise")

    categories = Practice.categories(scope)

    assert Enum.take(categories, 2) == [
             %{key: "morning", count: 2},
             %{key: "evening", count: 1}
           ]

    refute Enum.any?(categories, &(&1.key == "praise"))
  end

  test "returns one owned dhikr detail and hides another user's custom dhikr" do
    scope = user_scope_fixture()
    other_scope = user_scope_fixture()
    owned = insert_dhikr(scope.user.id, "Personal remembrance", "general")
    other = insert_dhikr(other_scope.user.id, "Private remembrance", "general")

    assert %{id: owned_id, title: "Personal remembrance", audio_url: audio_url} =
             Practice.get_dhikr(scope, owned.id)

    assert owned_id == owned.id
    assert audio_url == "https://example.com/audio.mp3"
    assert Practice.get_dhikr(scope, other.id) == nil
  end

  test "builds a counter snapshot with the current slot and canonical count" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)

    Repo.insert!(%CountProjection{
      user_id: scope.user.id,
      goal_id: goal.id,
      slot_id: slot.id,
      local_date: ~D[2026-07-16],
      entity_incarnation: 1,
      count: 7,
      sync_revision: 1
    })

    assert %{
             goal_id: goal_id,
             date: ~D[2026-07-16],
             count: 7,
             target_count: 100,
             selected_slot_id: selected_slot_id,
             can_count?: true
           } = Practice.counter(scope, goal.id, ~D[2026-07-16])

    assert goal_id == goal.id
    assert selected_slot_id == slot.id
  end

  test "builds a home snapshot from active due goals and today's canonical counts" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)

    Repo.insert!(%CountProjection{
      user_id: scope.user.id,
      goal_id: goal.id,
      slot_id: slot.id,
      local_date: ~D[2026-07-16],
      entity_incarnation: 1,
      count: 7,
      sync_revision: 1
    })

    assert %{
             email: email,
             date: ~D[2026-07-16],
             due_goals: [%{id: goal_id, today_count: 7}],
             total_today_count: 7,
             featured_wirds: [%{slug: "dalail-al-khayrat"} | _],
             categories: categories
           } = Practice.home(scope, ~D[2026-07-16])

    assert email == scope.user.email
    assert goal_id == goal.id
    assert %{key: "morning", count: 1} in categories
  end

  test "includes a current streak and recent contribution dates" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)

    Enum.each([~D[2026-07-14], ~D[2026-07-15], ~D[2026-07-16]], fn date ->
      Repo.insert!(%CountProjection{
        user_id: scope.user.id,
        goal_id: goal.id,
        slot_id: slot.id,
        local_date: date,
        entity_incarnation: 1,
        count: 1,
        sync_revision: 1
      })
    end)

    assert %{current_streak: 3, contribution_dates: contribution_dates} =
             Practice.home(scope, ~D[2026-07-16])

    assert Enum.sort(contribution_dates) == [~D[2026-07-14], ~D[2026-07-15], ~D[2026-07-16]]
  end

  defp insert_dhikr(user_id, title, category) do
    dhikr =
      %Dhikr{user_id: user_id}
      |> Dhikr.changeset(%{
        is_custom: not is_nil(user_id),
        arabic: "ذِكْر",
        category: category,
        audio_url: "https://example.com/audio.mp3"
      })
      |> Repo.insert!()

    Repo.insert!(%DhikrTranslation{
      dhikr_id: dhikr.id,
      locale: "en",
      title: title,
      transliteration: title,
      translation: "A translation"
    })

    dhikr
  end

  defp create_bucket(scope) do
    dhikr =
      %Dhikr{}
      |> Dhikr.changeset(%{arabic: "سُبْحَانَ اللَّهِ", category: "morning"})
      |> Repo.insert!()

    Repo.insert!(%DhikrTranslation{
      dhikr_id: dhikr.id,
      locale: "en",
      title: "Morning remembrance",
      transliteration: "Subhan Allah",
      translation: "Glory be to Allah"
    })

    {:ok, goal} =
      Tracking.create_goal(scope, %{
        id: Ecto.UUID.generate(),
        dhikr_id: dhikr.id,
        start_date: ~D[2026-07-01]
      })

    {:ok, slot} =
      Tracking.create_slot(scope, goal.id, %{
        id: Ecto.UUID.generate(),
        target_count: 100
      })

    Repo.insert!(%EntityRecord{
      user_id: scope.user.id,
      entity_type: "goal",
      entity_id: goal.id,
      incarnation: 1,
      version: 1,
      sync_revision: 1,
      document: %{},
      state: "active"
    })

    {goal, slot}
  end
end
