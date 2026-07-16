defmodule AwradApi.ProgressSync.Materializer do
  @moduledoc false

  import Ecto.Query

  alias AwradApi.Dhikr.{Dhikr, DhikrTranslation}
  alias AwradApi.Repo
  alias AwradApi.Tracking.{Goal, GoalReminder, GoalSlot}

  def put("custom_dhikr", document, user_id), do: put_dhikr(document, user_id)
  def put("goal", document, user_id), do: put_goal(document, user_id)

  def soft_delete("custom_dhikr", entity_id, user_id, deleted_at) do
    case Repo.one(from d in Dhikr, where: d.id == ^entity_id and d.user_id == ^user_id) do
      nil -> {:error, :entity_materialization_missing}
      dhikr -> dhikr |> Ecto.Changeset.change(deleted_at: deleted_at) |> Repo.update()
    end
  end

  def soft_delete("goal", entity_id, user_id, deleted_at) do
    case Repo.one(from g in Goal, where: g.id == ^entity_id and g.user_id == ^user_id) do
      nil ->
        {:error, :entity_materialization_missing}

      goal ->
        goal |> Ecto.Changeset.change(deleted_at: deleted_at, is_active: false) |> Repo.update()
    end
  end

  def purge("goal", entity_id, user_id) do
    case Repo.one(from g in Goal, where: g.id == ^entity_id and g.user_id == ^user_id) do
      nil -> :ok
      goal -> goal |> Repo.delete() |> normalize_delete()
    end
  end

  def purge("custom_dhikr", entity_id, user_id) do
    case Repo.one(from d in Dhikr, where: d.id == ^entity_id and d.user_id == ^user_id) do
      nil -> :ok
      dhikr -> dhikr |> Repo.delete() |> normalize_delete()
    end
  end

  def custom_dhikr_referenced?(entity_id, user_id) do
    Repo.exists?(
      from g in Goal,
        where: g.user_id == ^user_id and g.dhikr_id == ^entity_id and is_nil(g.deleted_at)
    )
  end

  defp normalize_delete({:ok, _record}), do: :ok
  defp normalize_delete({:error, reason}), do: {:error, reason}

  defp put_dhikr(document, user_id) do
    id = document["id"]
    quran = document["quran_ref"] || %{}

    attrs = %{
      is_custom: true,
      catalog_key: nil,
      arabic: document["arabic"],
      audio_url: document["audio_url"],
      audio_file_name: document["audio_file_name"],
      category: document["category"],
      audio_count_per_play: document["audio_count_per_play"],
      sort_order: document["sort_order"],
      quran_surah: quran["surah"],
      quran_ayah_start: quran["ayah_start"],
      quran_ayah_end: quran["ayah_end"],
      benefits: document["benefits"]
    }

    with {:ok, dhikr} <- upsert_owned_dhikr(id, user_id, attrs),
         {:ok, _translation} <- upsert_translation(dhikr.id, document) do
      {:ok, dhikr}
    end
  end

  defp upsert_owned_dhikr(id, user_id, attrs) do
    case Repo.get(Dhikr, id) do
      nil ->
        %Dhikr{id: id, user_id: user_id}
        |> Dhikr.changeset(attrs)
        |> Repo.insert()

      %Dhikr{user_id: ^user_id, is_custom: true} = dhikr ->
        dhikr
        |> Dhikr.changeset(attrs)
        |> Ecto.Changeset.change(deleted_at: nil)
        |> Repo.update()

      _ ->
        {:error, :entity_identity_collision}
    end
  end

  defp upsert_translation(dhikr_id, document) do
    attrs = %{
      dhikr_id: dhikr_id,
      locale: "und",
      title: document["title"],
      transliteration: document["transliteration"],
      translation: document["translation"]
    }

    case Repo.one(
           from t in DhikrTranslation, where: t.dhikr_id == ^dhikr_id and t.locale == "und"
         ) do
      nil -> %DhikrTranslation{} |> DhikrTranslation.changeset(attrs) |> Repo.insert()
      translation -> translation |> DhikrTranslation.changeset(attrs) |> Repo.update()
    end
  end

  defp put_goal(document, user_id) do
    with :ok <- valid_dhikr_owner(document["dhikr_id"], user_id),
         {:ok, goal} <- upsert_goal(document, user_id),
         :ok <- retain_all_existing_slots(goal.id, document["slots"]),
         {:ok, _slots} <- upsert_slots(goal.id, document["slots"]),
         {:ok, _reminders} <- replace_reminders(goal.id, document["reminders"]) do
      {:ok, goal}
    end
  end

  defp valid_dhikr_owner(dhikr_id, user_id) do
    if Repo.exists?(
         from d in Dhikr,
           where:
             d.id == ^dhikr_id and is_nil(d.deleted_at) and
               (is_nil(d.user_id) or d.user_id == ^user_id)
       ) do
      :ok
    else
      {:error, :invalid_dhikr_reference}
    end
  end

  defp upsert_goal(document, user_id) do
    id = document["id"]
    attrs = goal_attrs(document)

    case Repo.get(Goal, id) do
      nil ->
        %Goal{id: id} |> Goal.for_user_changeset(attrs, user_id) |> Repo.insert()

      %Goal{user_id: ^user_id} = goal ->
        goal |> Goal.changeset(attrs) |> Ecto.Changeset.change(deleted_at: nil) |> Repo.update()

      _ ->
        {:error, :entity_identity_collision}
    end
  end

  defp goal_attrs(document) do
    policy = document["count_policy"]
    recurrence = document["recurrence"]

    %{
      dhikr_id: document["dhikr_id"],
      target_policy: document["target_policy"],
      minimum_count: policy["minimum_count"],
      target_count: policy["target_count"],
      maximum_count: policy["maximum_count"],
      streak_threshold: threshold_map(policy["streak_threshold"]),
      reminder_threshold: threshold_map(policy["reminder_threshold"]),
      completion_threshold: threshold_map(policy["completion_threshold"]),
      cap_behavior: policy["cap_behavior"],
      completion_policy: document["completion_policy"],
      slot_counting_policy: document["slot_counting_policy"],
      recurrence_frequency: recurrence["frequency"],
      recurrence_calendar: recurrence["calendar"],
      recurrence_interval_days: recurrence["interval_days"],
      recurrence_anchor_date: recurrence["anchor_date"],
      recurrence_month: recurrence["month"],
      recurrence_season_code: recurrence["season_code"],
      recurrence_weekdays: recurrence["weekdays"],
      recurrence_month_days: recurrence["month_days"],
      recurrence_specific_dates: recurrence["specific_dates"],
      start_date: document["start_date"],
      end_date: document["end_date"],
      duration_days: document["duration_days"],
      is_active: document["is_active"],
      completed_at: document["completed_at"]
    }
  end

  defp retain_all_existing_slots(goal_id, proposed_slots) do
    existing =
      Repo.all(from s in GoalSlot, where: s.goal_id == ^goal_id, select: s.id) |> MapSet.new()

    proposed = MapSet.new(proposed_slots, & &1["id"])
    if MapSet.subset?(existing, proposed), do: :ok, else: {:error, :slot_removal_requires_archive}
  end

  defp upsert_slots(goal_id, slots) do
    Enum.reduce_while(slots, {:ok, []}, fn document, {:ok, acc} ->
      policy = document["count_policy"]

      attrs = %{
        minimum_count: policy["minimum_count"],
        target_count: policy["target_count"],
        maximum_count: policy["maximum_count"],
        streak_threshold: threshold_map(policy["streak_threshold"]),
        reminder_threshold: threshold_map(policy["reminder_threshold"]),
        completion_threshold: threshold_map(policy["completion_threshold"]),
        cap_behavior: policy["cap_behavior"],
        slot_type: document["slot_type"],
        timing_type: document["slot_type"],
        prayer_name: document["prayer_name"],
        prayer_relation: document["prayer_relation"],
        start_minute: document["start_minute"],
        end_minute: document["end_minute"],
        start_lead_minutes_override: document["start_lead_minutes_override"],
        label: document["label"],
        sort_order: document["sort_order"],
        is_active: document["is_active"],
        archived_at: document["archived_at"]
      }

      result =
        case Repo.get(GoalSlot, document["id"]) do
          nil ->
            %GoalSlot{id: document["id"]}
            |> GoalSlot.for_goal_changeset(attrs, goal_id)
            |> Repo.insert()

          %GoalSlot{goal_id: ^goal_id} = slot ->
            slot |> GoalSlot.changeset(attrs) |> Repo.update()

          _ ->
            {:error, :entity_identity_collision}
        end

      case result do
        {:ok, slot} -> {:cont, {:ok, [slot | acc]}}
        error -> {:halt, error}
      end
    end)
  end

  defp replace_reminders(goal_id, reminders) do
    ids = Enum.map(reminders, & &1["id"])
    query = from r in GoalReminder, where: r.goal_id == ^goal_id
    query = if ids == [], do: query, else: from(r in query, where: r.id not in ^ids)
    Repo.delete_all(query)

    Enum.reduce_while(reminders, {:ok, []}, fn document, {:ok, acc} ->
      attrs =
        Map.take(
          document,
          ~w(slot_id reminder_type hour minute offset_minutes enabled sort_order)
        )

      result =
        case Repo.get(GoalReminder, document["id"]) do
          nil ->
            %GoalReminder{id: document["id"]}
            |> GoalReminder.for_goal_changeset(attrs, goal_id)
            |> Repo.insert()

          %GoalReminder{goal_id: ^goal_id} = reminder ->
            reminder |> GoalReminder.changeset(attrs) |> Repo.update()

          _ ->
            {:error, :entity_identity_collision}
        end

      case result do
        {:ok, reminder} -> {:cont, {:ok, [reminder | acc]}}
        error -> {:halt, error}
      end
    end)
  end

  defp threshold_map(value) when is_binary(value), do: %{"type" => value}
  defp threshold_map(value), do: value
end
