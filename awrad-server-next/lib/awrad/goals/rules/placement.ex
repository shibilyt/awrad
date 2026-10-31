defmodule Awrad.Goals.Rules.Placement do
  @moduledoc false
  # Rule: My Goals sections and their order (fixtures/goal_list_placement.json,
  # README "Daily pace, rings and lists"). The first match wins: History,
  # Paused, Tracking, Today, Upcoming.

  alias Awrad.Goals.Ended
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Placement
  alias Awrad.Goals.Rules.Completion
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.DayStatuses
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Goals.Rules.Versions
  alias Awrad.Goals.Timeline
  alias Awrad.Hijri.Corrections

  # How far ahead a goal looks for its next scheduled or due day.
  @horizon 400

  @type item :: %{id: String.t(), goal: Versions.input(), counts: Counts.index()}

  @spec place([item()], [String.t()], Date.t(), Corrections.t()) :: Placement.t()
  def place(items, order, date, corrections) do
    positions = order |> Enum.with_index() |> Map.new()

    placed =
      Enum.group_by(items, &section(&1, date, corrections), fn %{id: id, goal: goal} ->
        {Map.get(positions, id, length(order)), Versions.timeline(goal).created_on, id}
      end)

    %Placement{
      today: ids(placed, :today),
      tracking: ids(placed, :tracking),
      paused: ids(placed, :paused),
      upcoming: upcoming(placed),
      history: history(placed)
    }
  end

  defp ids(placed, section) do
    placed
    |> Map.get(section, [])
    |> Enum.sort_by(&order_key/1)
    |> Enum.map(&elem(&1, 2))
  end

  defp upcoming(placed) do
    placed
    |> Enum.flat_map(fn
      {{:upcoming, next}, keys} -> Enum.map(keys, &{next, &1})
      _other -> []
    end)
    |> Enum.sort_by(fn {next, key} ->
      {is_nil(next), next && Date.to_iso8601(next), order_key(key)}
    end)
    |> Enum.map(fn {next, {_, _, id}} -> %{id: id, next_due: next} end)
  end

  defp history(placed) do
    placed
    |> Enum.flat_map(fn
      {{:history, finished, on}, keys} -> Enum.map(keys, &{finished, on, &1})
      _other -> []
    end)
    |> Enum.sort_by(fn {_, on, key} -> {-Date.to_gregorian_days(on), order_key(key)} end)
    |> Enum.map(fn {finished, on, {_, _, id}} -> %{id: id, finished: finished, on: on} end)
  end

  # Named in the goal order first, then by creation day and ID.
  defp order_key({position, created_on, id}), do: {position, Date.to_iso8601(created_on), id}

  defp section(%{goal: input, counts: index}, date, corrections) do
    timeline = Versions.timeline(input)
    goal = Versions.resolve(timeline, date)

    cond do
      finished = finished(timeline, index, date, corrections) -> finished
      Schedule.paused?(goal, date) -> :paused
      goal.requirement == :tracker -> :tracking
      today?(timeline, goal, {index, date}, corrections) -> :today
      true -> {:upcoming, next_due(timeline, goal, date, corrections)}
    end
  end

  # Due today, or with a day pending make-up (decision 46).
  defp today?(timeline, goal, {index, date}, corrections) do
    Schedule.due?(goal, date, corrections) or
      timeline
      |> DayStatuses.statuses(index, date, corrections)
      |> Enum.any?(&(&1.status == :pending))
  end

  defp next_due(timeline, goal, date, corrections) do
    date
    |> Date.add(1)
    |> Date.range(horizon(goal, date), 1)
    |> Enum.find(&Schedule.due?(Versions.resolve(timeline, &1), &1, corrections))
  end

  defp horizon(%Goal{active_period: period}, date),
    do: Periods.earliest(Date.add(date, @horizon), Periods.last_day(period))

  # History: ended in the document, completed by its policy, past its last
  # day, or no scheduled day left in the next 400 days (ignoring pauses).
  defp finished(
         %Timeline{ended: %Ended{on: on, reason: :completed}},
         _index,
         _date,
         _corrections
       ),
       do: {:history, :completed, on}

  defp finished(%Timeline{ended: %Ended{on: on}}, _index, _date, _corrections),
    do: {:history, :ended, on}

  defp finished(%Timeline{} = timeline, index, date, corrections) do
    goal = Versions.resolve(timeline, date)
    last = Periods.last_day(goal.active_period)

    cond do
      Completion.completed?(goal, index, date) ->
        {:history, :completed, completed_on(goal, index, date)}

      last != nil and Date.after?(date, last) ->
        {:history, :ended, last}

      scheduled_ahead?(timeline, goal, date, corrections) ->
        nil

      true ->
        {:history, :ended, last_scheduled(timeline, goal, date, corrections)}
    end
  end

  defp completed_on(%Goal{completion: :when_duration_ended} = goal, _index, _date),
    do: Periods.last_day(goal.active_period)

  defp completed_on(%Goal{} = goal, index, date) do
    goal.active_period.start_date
    |> Date.range(date, 1)
    |> Enum.find(&Completion.completed?(goal, index, &1))
  end

  defp scheduled_ahead?(timeline, goal, date, corrections) do
    date
    |> Date.range(horizon(goal, date), 1)
    |> Enum.any?(&Schedule.in_schedule?(Versions.resolve(timeline, &1), &1, corrections))
  end

  defp last_scheduled(timeline, %Goal{active_period: %{start_date: start}}, date, corrections) do
    date
    |> Date.add(-1)
    |> Date.range(start, -1)
    |> Enum.find(start, &Schedule.in_schedule?(Versions.resolve(timeline, &1), &1, corrections))
  end
end
