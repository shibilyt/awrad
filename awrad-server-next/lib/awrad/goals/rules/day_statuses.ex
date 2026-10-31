defmodule Awrad.Goals.Rules.DayStatuses do
  @moduledoc false
  # Rule: each due day's status with make-up (fixtures/make_up.json, README
  # "Make-up"). Make-up is derived from the counts, never stored.
  #
  # Every day of the active period (up to the evaluated date) that isn't
  # paused, excused or past the end gives what it has past its own needs: a
  # due day what's past its target, or its streak amount if higher; a day
  # that isn't due all its counts. That fills the missed days whose window
  # reaches it, oldest first, each up to its fill amount, session by session.

  alias Awrad.Goals.DayStatus
  alias Awrad.Goals.Goal
  alias Awrad.Goals.MakeUp
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.Pace
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Goals.Rules.Versions
  alias Awrad.Goals.Timeline
  alias Awrad.Hijri.Corrections

  # Worst first: with sessions, the day takes its worst session's status.
  @worst_first [:in_progress, :missed, :pending, :made_up, :minimum_only, :met]

  @max_window 3

  @spec statuses(Timeline.t(), Counts.index(), Date.t(), Corrections.t()) :: [DayStatus.t()]
  def statuses(%Timeline{} = timeline, index, date, corrections) do
    %Goal{active_period: period} = Versions.resolve(timeline, date)
    last_day = Periods.last_day(period)
    days = Date.range(period.start_date, Periods.earliest(date, last_day), 1)
    running? = is_nil(last_day) or not Date.after?(date, last_day)

    days
    |> Enum.flat_map(&due_day(timeline, index, &1, corrections))
    |> Map.new(&{&1.date, &1})
    |> then(&Enum.reduce(days, &1, fn day, due -> fill_from(timeline, index, day, due) end))
    |> Map.values()
    |> Enum.sort_by(& &1.date, Date)
    |> Enum.map(&day_status(&1, date, running?))
  end

  defp due_day(timeline, index, date, corrections) do
    goal = Versions.resolve(timeline, date)

    if Schedule.due?(goal, date, corrections) do
      counts = Counts.day(index, date)

      units =
        for {id, policy} <- Counts.units(goal) do
          target = Counts.daily_target(goal, policy)
          streak = Pace.streak_amount(timeline, index, policy, date, corrections)
          count = Counts.unit_count(goal, counts, id)

          %{
            id: id,
            target: target,
            streak: streak,
            count: count,
            filled: 0,
            fill: fill(goal, target, streak)
          }
        end

      [%{date: date, window: MakeUp.window_days(goal.make_up), units: units}]
    else
      []
    end
  end

  defp fill(%Goal{make_up: %MakeUp{fill: :streak}}, _target, streak), do: streak
  defp fill(%Goal{make_up: %MakeUp{fill: :target}}, target, streak), do: max(target || 0, streak)

  # Paused days, excused days and days outside the active period give nothing.
  defp fill_from(timeline, index, date, due) do
    goal = Versions.resolve(timeline, date)

    if Periods.in_active_period?(goal.active_period, date) and not Schedule.paused?(goal, date) and
         not Schedule.excused?(goal, date) do
      giver = {Map.get(due, date), Counts.day(index, date)}

      date
      |> missed_days_reaching(due)
      |> Enum.reduce({due, %{}}, fn missed, {filled, spare} ->
        {units, left} = Enum.map_reduce(filled[missed].units, spare, &fill_unit(&1, &2, giver))
        {Map.update!(filled, missed, &%{&1 | units: units}), left}
      end)
      |> elem(0)
    else
      due
    end
  end

  # The due days before `date` whose make-up window reaches it, oldest first.
  defp missed_days_reaching(date, due) do
    for back <- @max_window..1//-1,
        missed = Date.add(date, -back),
        %{window: window} <- [Map.get(due, missed)],
        back <= window,
        do: missed
  end

  # `spare` is what the giving day has left per unit, worked out when first needed.
  defp fill_unit(unit, spare, giver) do
    case unit.fill - unit.count - unit.filled do
      deficit when deficit > 0 ->
        known = Map.put_new_lazy(spare, unit.id, fn -> spare(giver, unit.id) end)
        give = min(deficit, known[unit.id])
        {%{unit | filled: unit.filled + give}, Map.update!(known, unit.id, &(&1 - give))}

      _kept ->
        {unit, spare}
    end
  end

  # What a day has past its own needs, for one unit.
  defp spare({nil = _not_due, counts}, nil), do: Counts.day_total(counts)
  defp spare({nil = _not_due, counts}, id), do: Map.get(counts, id, 0)

  defp spare({%{units: units}, _counts}, id) do
    case Enum.find(units, &(&1.id == id)) do
      nil -> 0
      unit -> max(0, unit.count - max(unit.target || 0, unit.streak))
    end
  end

  defp day_status(%{date: day, units: units} = due, date, running?) do
    statuses = Enum.map(units, &unit_status(&1, due, date, running?))

    %DayStatus{
      date: day,
      count: Counts.total(units, & &1.count),
      filled: Counts.total(units, & &1.filled),
      status: Enum.find(@worst_first, &(&1 in statuses))
    }
  end

  defp unit_status(unit, due, date, running?) do
    cond do
      unit.count >= unit.streak and (is_nil(unit.target) or unit.count >= unit.target) -> :met
      unit.filled > 0 and unit.count + unit.filled >= unit.fill -> :made_up
      unit.count >= unit.streak -> :minimum_only
      true -> unkept_status(due, date, running?)
    end
  end

  # Not kept: today is in progress; a day whose window is still open while
  # the goal runs is pending (decision 46); anything else is missed.
  defp unkept_status(%{date: date}, date, _running?), do: :in_progress

  defp unkept_status(%{date: day, window: window}, date, running?) do
    open? = window > 0 and not Date.after?(date, Date.add(day, window))
    if open? and running?, do: :pending, else: :missed
  end
end
