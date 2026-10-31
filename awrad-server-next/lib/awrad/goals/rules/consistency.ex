defmodule Awrad.Goals.Rules.Consistency do
  @moduledoc false
  # Rule: the consistency tag and what a row shows (fixtures/consistency.json,
  # README "Consistency"). Open units (today, a day pending make-up, the
  # current period) count only once kept or met.

  alias Awrad.Goals.Consistency
  alias Awrad.Goals.DayStatus
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.DayStatuses
  alias Awrad.Goals.Rules.PeriodWalk
  alias Awrad.Goals.Rules.Streak
  alias Awrad.Goals.Rules.Versions
  alias Awrad.Goals.Timeline
  alias Awrad.Hijri.Corrections

  @spec evaluate(Timeline.t(), Counts.index(), Date.t(), Goal.week_start(), Corrections.t()) ::
          Consistency.t()
  def evaluate(%Timeline{} = timeline, index, date, week_start, corrections) do
    statuses = DayStatuses.statuses(timeline, index, date, corrections)
    {basis, results} = results(timeline, {index, statuses}, date, week_start, corrections)
    out_of = length(results)
    met = Enum.count(results, & &1)
    tag = if out_of >= minimum(basis), do: tag(met, out_of)
    streak = Streak.current(timeline, {index, statuses}, date, week_start, corrections)

    %Consistency{basis: basis, met: met, out_of: out_of, tag: tag, show: show(streak, tag)}
  end

  # The settled units, newest first, as met or not: up to 12 periods or 30 due days.
  defp results(timeline, {index, statuses}, date, week_start, corrections) do
    case Streak.unit(Versions.resolve(timeline, date)) do
      {period, nil} when period in [:week, :month] ->
        periods =
          timeline
          |> PeriodWalk.back(index, date, week_start, corrections)
          |> Stream.reject(&(&1.in_progress? and not &1.met?))
          |> Stream.map(& &1.met?)
          |> Enum.take(12)

        {:periods, periods}

      {_day, _weekday} ->
        days =
          statuses
          |> Enum.reverse()
          |> Enum.reject(&DayStatus.open?(&1.status))
          |> Enum.take(30)
          |> Enum.map(&DayStatus.kept?(&1.status))

        {:due_days, days}
    end
  end

  defp minimum(:periods), do: 4
  defp minimum(:due_days), do: 7

  defp tag(met, out_of) when met * 10 >= out_of * 9, do: :devoted
  defp tag(met, out_of) when met * 10 >= out_of * 8, do: :steady
  defp tag(_met, _out_of), do: nil

  defp show(streak, _tag) when streak >= 3, do: :streak
  defp show(_streak, tag) when tag != nil, do: :consistency
  defp show(streak, nil) when streak >= 1, do: :streak
  defp show(_streak, nil), do: :none
end
