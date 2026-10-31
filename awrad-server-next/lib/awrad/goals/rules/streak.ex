defmodule Awrad.Goals.Rules.Streak do
  @moduledoc false
  # Rule: the current streak and its unit (fixtures/goal_streak.json, README
  # "Streaks"), from the version in force on the evaluated date.
  #
  # Walks back over the unit: due days (by status, with make-up), weeks or
  # months (PeriodWalk), or occasions. A kept unit adds one; an open one
  # (today, a day pending make-up, the current period or occasion) neither
  # breaks nor adds; anything else ends it.

  alias Awrad.Goals.DayStatus
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.DayStatuses
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.PeriodWalk
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Goals.Rules.Versions
  alias Awrad.Goals.Streak
  alias Awrad.Goals.Timeline
  alias Awrad.Hijri.Corrections

  # How far ahead the current occasion looks for a due day still to come.
  @horizon 400

  @spec evaluate(Timeline.t(), Counts.index(), Date.t(), Goal.week_start(), Corrections.t()) ::
          Streak.t()
  def evaluate(%Timeline{} = timeline, index, date, week_start, corrections) do
    statuses = DayStatuses.statuses(timeline, index, date, corrections)
    {unit, weekday} = unit(Versions.resolve(timeline, date))

    %Streak{
      current: current(timeline, {index, statuses}, date, week_start, corrections),
      unit: unit,
      weekday: weekday,
      pending_make_up: for(%DayStatus{status: :pending, date: day} <- statuses, do: day)
    }
  end

  @doc "The streak unit of the goal in force (README \"Streak units\")."
  @spec unit(Goal.t()) :: {Streak.unit(), Goal.weekday() | nil}
  def unit(%Goal{requirement: {:period_total, period}}), do: {period_unit(period), nil}
  def unit(%Goal{requirement: {:days_per_period, period, _}}), do: {period_unit(period), nil}
  def unit(%Goal{schedule: {:yearly, _calendar, _ranges}}), do: {:occasion, nil}
  def unit(%Goal{schedule: {:weekdays, [weekday]}}), do: {:weekday, weekday}
  def unit(%Goal{}), do: {:day, nil}

  defp period_unit(:week), do: :week
  defp period_unit(_month), do: :month

  @doc """
  The current streak, given the day statuses up to `date`
  (`DayStatuses.statuses/4`).
  """
  @spec current(
          Timeline.t(),
          {Counts.index(), [DayStatus.t()]},
          Date.t(),
          Goal.week_start(),
          Corrections.t()
        ) :: non_neg_integer()
  def current(timeline, {index, statuses}, date, week_start, corrections) do
    units =
      case unit(Versions.resolve(timeline, date)) do
        {period, nil} when period in [:week, :month] ->
          timeline
          |> PeriodWalk.back(index, date, week_start, corrections)
          |> Stream.map(&{&1.met?, &1.in_progress?})

        {:occasion, nil} ->
          occasions(timeline, statuses, date, corrections)

        {_day, _weekday} ->
          statuses
          |> Enum.reverse()
          |> Enum.map(&{DayStatus.kept?(&1.status), DayStatus.open?(&1.status)})
      end

    count_kept(units)
  end

  # Newest first, `{kept?, open?}` per unit. An open unit is skipped, except a
  # kept period still in progress, which already adds.
  defp count_kept(units) do
    Enum.reduce_while(units, 0, fn
      {true, _open?}, streak -> {:cont, streak + 1}
      {false, true}, streak -> {:cont, streak}
      {false, false}, streak -> {:halt, streak}
    end)
  end

  @doc """
  A yearly goal's occasions, newest first, as `{kept?, open?}`: kept when
  every due day kept the streak. The newest is open (in progress) while the
  goal runs and it has a due day after `date`, or a day not settled yet; an
  open occasion adds only once complete.
  """
  @spec occasions(Timeline.t(), [DayStatus.t()], Date.t(), Corrections.t()) :: [
          {boolean(), boolean()}
        ]
  def occasions(timeline, statuses, date, corrections) do
    statuses
    |> Enum.reverse()
    |> Enum.chunk_by(&occasion(timeline, &1.date, corrections))
    |> Enum.with_index()
    |> Enum.map(fn {days, i} ->
      open? =
        i == 0 and running?(timeline, date) and in_progress?(timeline, days, date, corrections)

      kept? = Enum.all?(days, &DayStatus.kept?(&1.status))
      {kept? and not open?, open?}
    end)
  end

  defp occasion(timeline, day, corrections),
    do: Schedule.occasion(Versions.resolve(timeline, day), day, corrections)

  defp running?(timeline, date) do
    last = Periods.last_day(Versions.resolve(timeline, date).active_period)
    is_nil(last) or not Date.after?(date, last)
  end

  defp in_progress?(timeline, [%DayStatus{date: newest} | _] = days, date, corrections) do
    Enum.any?(days, &DayStatus.open?(&1.status)) or
      next_scheduled_in?(timeline, occasion(timeline, newest, corrections), date, corrections)
  end

  # Whether the next scheduled, unpaused day after `date` belongs to `key`.
  defp next_scheduled_in?(timeline, key, date, corrections) do
    date
    |> Date.add(1)
    |> Date.range(Date.add(date, @horizon), 1)
    |> Enum.reduce_while(false, fn day, false ->
      cond do
        not running?(timeline, day) ->
          {:halt, false}

        scheduled?(timeline, day, corrections) ->
          {:halt, occasion(timeline, day, corrections) == key}

        true ->
          {:cont, false}
      end
    end)
  end

  defp scheduled?(timeline, day, corrections) do
    goal = Versions.resolve(timeline, day)
    Schedule.in_schedule?(goal, day, corrections) and not Schedule.paused?(goal, day)
  end
end
