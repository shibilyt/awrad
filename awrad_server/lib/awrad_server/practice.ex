defmodule AwradServer.Practice do
  @moduledoc """
  Read models for the authenticated Awrad web companion.

  The web layer receives plain maps from this context. Ownership is always
  derived from the caller's scope, and canonical progress records are used for
  counts rather than the legacy count-entry projection.
  """

  import Ecto.Query

  alias AwradServer.Accounts.{Scope, User}
  alias AwradServer.Dhikr.{Dhikr, DhikrTranslation}
  alias AwradServer.Practice.Eligibility
  alias AwradServer.ProgressSync.{CountProjection, EntityRecord}
  alias AwradServer.Repo
  alias AwradServer.Tracking.{Goal, GoalSlot}

  @category_order ~w(
    morning
    evening
    after_salah
    forgiveness
    praise
    protection
    general
    swalaths
    asma_ul_husna
    ramadan
    quran
  )

  @featured_wirds [
    %{
      slug: "dalail-al-khayrat",
      title: "Dalail al-Khayrat",
      arabic_title: "دلائل الخيرات",
      description: "A complete Arabic wird of prayers and blessings upon the Prophet Muhammad ﷺ.",
      tag: "Salawat",
      schedule: "Sections by weekday",
      estimated_minutes: 60
    }
  ]

  @doc "Searches built-in dhikr and custom dhikr owned by the caller."
  def search_dhikr(%Scope{user: %User{id: user_id}}, filters) when is_map(filters) do
    query = filters |> value(:query) |> to_string() |> String.trim()
    category = filters |> value(:category) |> to_string() |> String.trim()

    base_query = dhikr_query(user_id)

    base_query =
      if category in ["", "all"] do
        base_query
      else
        from [dhikr, _english, _und] in base_query, where: dhikr.category == ^category
      end

    base_query =
      if query == "" do
        base_query
      else
        pattern = "%#{escape_like(query)}%"

        from [dhikr, english, und] in base_query,
          where:
            ilike(dhikr.arabic, ^pattern) or ilike(english.title, ^pattern) or
              ilike(english.transliteration, ^pattern) or ilike(english.translation, ^pattern) or
              ilike(und.title, ^pattern) or ilike(und.transliteration, ^pattern) or
              ilike(und.translation, ^pattern)
      end

    Repo.all(base_query) |> Enum.map(&format_dhikr/1)
  end

  @doc "Returns one built-in or caller-owned dhikr, or nil when it is unavailable."
  def get_dhikr(%Scope{user: %User{id: user_id}}, dhikr_id) do
    with {:ok, dhikr_id} <- Ecto.UUID.cast(dhikr_id) do
      dhikr_query(user_id)
      |> where([dhikr, _english, _und], dhikr.id == ^dhikr_id)
      |> Repo.one()
      |> case do
        nil -> nil
        dhikr -> format_dhikr(dhikr)
      end
    else
      :error -> nil
    end
  end

  @doc "Builds a counter snapshot for one owned goal and the caller's local date."
  def counter(%Scope{} = scope, goal_id, %Date{} = date),
    do: counter(scope, goal_id, date, nil)

  def counter(%Scope{} = scope, goal_id, %Date{} = date, requested_slot_id) do
    with {:ok, goal_id} <- Ecto.UUID.cast(goal_id),
         goal when not is_nil(goal) <- Enum.find(list_goals(scope, date), &(&1.id == goal_id)) do
      requested_slot_id = cast_slot_id(requested_slot_id)

      selected_slot =
        Enum.find(goal.slots, &(&1.id == requested_slot_id)) ||
          Enum.find(goal.slots, & &1.web_countable?) || List.first(goal.slots)

      count = if selected_slot, do: selected_slot.count, else: goal.count
      target_count = if selected_slot, do: selected_slot.target_count, else: goal.target_count

      %{
        goal_id: goal.id,
        dhikr_id: goal.dhikr_id,
        date: date,
        goal: goal,
        slots: goal.slots,
        selected_slot_id: selected_slot && selected_slot.id,
        count: count,
        target_count: target_count,
        progress: progress(count, target_count),
        can_count?: selected_slot != nil and selected_slot.web_countable?,
        block_reason: selected_slot && selected_slot.web_block_reason
      }
    else
      nil -> nil
      :error -> nil
    end
  end

  @doc "Returns the caller-visible dhikr categories with their current library counts."
  def categories(%Scope{user: %User{id: user_id}}) do
    counts =
      Repo.all(
        from dhikr in Dhikr,
          where:
            is_nil(dhikr.deleted_at) and
              (is_nil(dhikr.user_id) or dhikr.user_id == ^user_id),
          group_by: dhikr.category,
          select: {dhikr.category, count(dhikr.id)}
      )
      |> Map.new()

    @category_order
    |> Enum.flat_map(fn key ->
      case Map.get(counts, key, 0) do
        0 -> []
        count -> [%{key: key, count: count}]
      end
    end)
  end

  @doc "Returns the bundled featured Wird catalog for the mobile-parity home section."
  def featured_wirds(%Scope{}, %Date{}), do: @featured_wirds

  @doc "Builds the authenticated user's browser-local home snapshot."
  def home(%Scope{} = scope, %Date{} = date) do
    goals = list_goals(scope, date)
    due_goals = Enum.filter(goals, & &1.due_today?)
    contribution_counts = load_contribution_counts(scope.user.id, date)

    %{
      email: scope.user.email,
      date: date,
      goals: goals,
      due_goals: due_goals,
      total_today_count: Enum.sum(Enum.map(due_goals, & &1.today_count)),
      active_goal_count: Enum.count(goals, &(&1.status == :active)),
      current_streak: current_streak(contribution_counts, date),
      contribution_dates: Enum.map(contribution_counts, &elem(&1, 0)),
      featured_wirds: featured_wirds(scope, date),
      categories: categories(scope)
    }
  end

  @doc "Returns the authenticated user's non-deleted canonical goals."
  def list_goals(%Scope{user: %User{id: user_id}}, %Date{} = date) do
    goals =
      Repo.all(
        from goal in Goal,
          join: dhikr in Dhikr,
          on:
            dhikr.id == goal.dhikr_id and
              (is_nil(dhikr.user_id) or dhikr.user_id == ^user_id) and
              is_nil(dhikr.deleted_at),
          join: entity in EntityRecord,
          on:
            entity.user_id == goal.user_id and entity.entity_type == "goal" and
              entity.entity_id == goal.id and entity.state == "active",
          left_join: english in DhikrTranslation,
          on: english.dhikr_id == dhikr.id and english.locale == "en",
          left_join: und in DhikrTranslation,
          on: und.dhikr_id == dhikr.id and und.locale == "und",
          where: goal.user_id == ^user_id and is_nil(goal.deleted_at),
          order_by: [desc: goal.is_active, asc: goal.start_date, asc: goal.inserted_at],
          select: %{
            goal: goal,
            dhikr: dhikr,
            title: fragment("COALESCE(?, ?, ?)", english.title, und.title, dhikr.catalog_key),
            transliteration:
              fragment("COALESCE(?, ?)", english.transliteration, und.transliteration),
            translation: fragment("COALESCE(?, ?)", english.translation, und.translation),
            entity: entity
          }
      )

    goal_ids = Enum.map(goals, & &1.goal.id)
    slots = load_slots(goal_ids)
    projections = load_projections(user_id, goal_ids)

    Enum.map(goals, fn %{
                         goal: goal,
                         dhikr: dhikr,
                         title: title,
                         transliteration: transliteration,
                         translation: translation,
                         entity: entity
                       } ->
      goal_slots = Map.get(slots, goal.id, [])

      slot_views =
        Enum.map(goal_slots, fn slot ->
          today_count =
            projection_count(projections, goal.id, slot.id, entity.incarnation, date)

          count =
            if goal.target_policy == "cumulative_total" do
              total_projection_count(projections, goal.id, slot.id, entity.incarnation)
            else
              today_count
            end

          target_count = slot.target_count || goal.target_count || 0
          eligibility = Eligibility.evaluate(goal, slot, date)

          %{
            id: slot.id,
            label: slot.label || slot.prayer_name || "Anytime",
            slot_type: slot.slot_type,
            timing_type: slot.timing_type,
            minimum_count: slot.minimum_count || goal.minimum_count,
            target_count: target_count,
            maximum_count: slot.maximum_count || goal.maximum_count,
            cap_behavior: slot.cap_behavior || goal.cap_behavior,
            count: count,
            today_count: today_count,
            progress: progress(count, target_count),
            web_countable?: eligibility == :allowed,
            web_block_reason: block_reason(eligibility)
          }
        end)

      %{
        id: goal.id,
        dhikr_id: dhikr.id,
        title: title || "Dhikr",
        arabic: dhikr.arabic,
        transliteration: transliteration,
        translation: translation,
        category: dhikr.category,
        audio_url: dhikr.audio_url,
        target_policy: goal.target_policy,
        goal_type: goal_type(goal),
        status: status(goal),
        due_today?: Eligibility.due?(goal, date),
        start_date: goal.start_date,
        end_date: goal.end_date,
        duration_days: goal.duration_days,
        today_count: Enum.sum(Enum.map(slot_views, & &1.today_count)),
        count: Enum.sum(Enum.map(slot_views, & &1.count)),
        target_count: Enum.sum(Enum.map(slot_views, & &1.target_count)),
        minimum_count: goal.minimum_count,
        maximum_count: goal.maximum_count,
        cap_behavior: goal.cap_behavior,
        slots: slot_views,
        web_countable?: Enum.any?(slot_views, & &1.web_countable?),
        entity_version: entity.version,
        entity_incarnation: entity.incarnation
      }
    end)
  end

  defp load_slots([]), do: %{}

  defp load_slots(goal_ids) do
    Repo.all(
      from slot in GoalSlot,
        where: slot.goal_id in ^goal_ids and is_nil(slot.deleted_at) and is_nil(slot.archived_at),
        order_by: [asc: slot.sort_order, asc: slot.inserted_at]
    )
    |> Enum.group_by(& &1.goal_id)
  end

  defp load_projections(_user_id, []), do: []

  defp load_projections(user_id, goal_ids) do
    Repo.all(
      from projection in CountProjection,
        where: projection.user_id == ^user_id and projection.goal_id in ^goal_ids
    )
  end

  defp load_contribution_counts(user_id, date) do
    from_date = Date.add(date, -104)

    Repo.all(
      from projection in CountProjection,
        join: entity in EntityRecord,
        on:
          entity.user_id == projection.user_id and entity.entity_type == "goal" and
            entity.entity_id == projection.goal_id and
            entity.incarnation == projection.entity_incarnation and entity.state == "active",
        where:
          projection.user_id == ^user_id and projection.local_date >= ^from_date and
            projection.local_date <= ^date and projection.count > 0,
        group_by: projection.local_date,
        order_by: [asc: projection.local_date],
        select: {projection.local_date, sum(projection.count)}
    )
  end

  defp current_streak([], _date), do: 0

  defp current_streak(contribution_counts, date) do
    dates = MapSet.new(contribution_counts, &elem(&1, 0))
    start_date = if MapSet.member?(dates, date), do: date, else: Date.add(date, -1)

    Stream.iterate(start_date, &Date.add(&1, -1))
    |> Enum.take_while(&MapSet.member?(dates, &1))
    |> length()
  end

  defp projection_count(projections, goal_id, slot_id, incarnation, date) do
    case Enum.find(
           projections,
           &(&1.goal_id == goal_id and &1.slot_id == slot_id and
               &1.entity_incarnation == incarnation and &1.local_date == date)
         ) do
      nil -> 0
      projection -> projection.count
    end
  end

  defp total_projection_count(projections, goal_id, slot_id, incarnation) do
    projections
    |> Enum.filter(
      &(&1.goal_id == goal_id and &1.slot_id == slot_id and
          &1.entity_incarnation == incarnation)
    )
    |> Enum.sum_by(& &1.count)
  end

  defp progress(_count, target) when target <= 0, do: 0.0
  defp progress(count, target), do: min(count / target, 1.0)

  defp block_reason(:allowed), do: nil
  defp block_reason({:blocked, reason}), do: reason

  defp goal_type(%Goal{target_policy: "cumulative_total"}), do: :one_time
  defp goal_type(%Goal{target_policy: "none"}), do: :tracker
  defp goal_type(%Goal{timing_type: timing}) when timing != "anytime", do: :advanced
  defp goal_type(%Goal{recurrence_frequency: "daily"}), do: :daily
  defp goal_type(_goal), do: :advanced

  defp status(%Goal{completed_at: completed_at}) when not is_nil(completed_at), do: :completed
  defp status(%Goal{is_active: true}), do: :active
  defp status(_goal), do: :paused

  defp dhikr_query(user_id) do
    from dhikr in Dhikr,
      left_join: english in DhikrTranslation,
      on: english.dhikr_id == dhikr.id and english.locale == "en",
      left_join: und in DhikrTranslation,
      on: und.dhikr_id == dhikr.id and und.locale == "und",
      where:
        is_nil(dhikr.deleted_at) and
          (is_nil(dhikr.user_id) or dhikr.user_id == ^user_id),
      order_by: [asc: dhikr.sort_order, asc: dhikr.inserted_at],
      select: %{
        id: dhikr.id,
        title: fragment("COALESCE(?, ?, ?)", english.title, und.title, dhikr.catalog_key),
        arabic: dhikr.arabic,
        transliteration: fragment("COALESCE(?, ?)", english.transliteration, und.transliteration),
        translation: fragment("COALESCE(?, ?)", english.translation, und.translation),
        audio_url: dhikr.audio_url,
        audio_file_name: dhikr.audio_file_name,
        category: dhikr.category,
        benefits: dhikr.benefits,
        is_custom: dhikr.is_custom
      }
  end

  defp format_dhikr(dhikr), do: Map.update!(dhikr, :title, &(&1 || "Dhikr"))

  defp escape_like(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  defp value(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))

  defp cast_slot_id(nil), do: nil

  defp cast_slot_id(slot_id) do
    case Ecto.UUID.cast(slot_id) do
      {:ok, slot_id} -> slot_id
      :error -> nil
    end
  end
end
