defmodule Awrad.Goals.Rules.Requirement do
  @moduledoc false
  # Rule: requirement standing (fixtures/requirement_standing.json).

  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Goals.Session
  alias Awrad.Goals.SessionStanding
  alias Awrad.Goals.Standing
  alias Awrad.Hijri.Corrections

  @spec standing(Goal.t(), Counts.index(), Date.t(), Goal.week_start(), Corrections.t()) ::
          Standing.t()
  def standing(%Goal{} = goal, index, date, week_start, corrections) do
    goal = without_tracker_target(goal)
    window = window(goal, date, week_start, corrections)
    due? = window != nil and due_in?(goal, window, date, corrections)
    # Every `:not_due` answer has the evaluated day as its window, so its
    # progress is that day's count inside the active period, even for a
    # period goal whose whole week or month has no due day.
    window = if due?, do: window, else: Periods.day(date)
    {progress, sessions} = evaluate(goal, index, window, date)

    %Standing{
      status: status(goal, due?, progress, sessions),
      window: window,
      progress: progress,
      target: if(goal.sessions == [], do: goal.count_policy.target),
      sessions: sessions
    }
  end

  @doc "Whether the goal's requirement is met over `window`, counting entries up to `date`."
  @spec window_met?(Goal.t(), Counts.index(), Date.Range.t(), Date.t()) :: boolean()
  def window_met?(goal, index, window, date) do
    goal = without_tracker_target(goal)
    {progress, sessions} = evaluate(goal, index, window, date)
    met?(goal, progress, sessions)
  end

  # A tracker has no target: any count is progress.
  defp without_tracker_target(
         %Goal{requirement: :tracker, count_policy: %CountPolicy{} = policy} = goal
       ),
       do: %{goal | count_policy: %{policy | target: nil}}

  defp without_tracker_target(goal), do: goal

  # `nil` when there's no window to be due in: outside the active period, or
  # a day outside the Hijri table for a Hijri-month total.
  defp window(%Goal{active_period: period} = goal, date, week_start, corrections) do
    cond do
      not Periods.in_active_period?(period, date) -> nil
      goal.requirement == :cumulative_total -> Date.range(period.start_date, date, 1)
      true -> period_window(goal.requirement, period, date, week_start, corrections)
    end
  end

  defp period_window({:period_total, unit}, period, date, week_start, corrections),
    do: Periods.window(period, unit, date, week_start, corrections)

  defp period_window(_per_day, _period, date, _week_start, _corrections), do: Periods.day(date)

  # Progress counts the window's days up to and including `date`, inside the active period.
  defp evaluate(%Goal{active_period: period} = goal, index, window, date) do
    days = window |> Periods.through(date) |> Enum.filter(&Periods.in_active_period?(period, &1))
    sessions = Enum.map(goal.sessions, &session_standing(&1, index, days))
    {Counts.sum(index, days, &Counts.goal_total(goal, &1)), sessions}
  end

  defp session_standing(%Session{id: id, count_policy: policy}, index, days) do
    progress = Counts.sum(index, days, &Map.get(&1, id, 0))
    status = if Counts.meets?(progress, policy, :target), do: :met, else: :not_met
    %SessionStanding{id: id, progress: progress, target: policy.target, status: status}
  end

  defp status(_goal, false = _due?, _progress, _sessions), do: :not_due

  defp status(goal, true, progress, sessions),
    do: if(met?(goal, progress, sessions), do: :met, else: :not_met)

  # Given a window (so inside the active period): per-day goals need the day
  # itself to be due; period goals need a due day in the window; cumulative
  # goals need nothing more.
  defp due_in?(%Goal{requirement: :cumulative_total}, _window, _date, _corrections), do: true

  defp due_in?(%Goal{requirement: {:period_total, _unit}} = goal, window, _date, corrections),
    do: Enum.any?(window, &Schedule.due?(goal, &1, corrections))

  defp due_in?(goal, _window, date, corrections), do: Schedule.due?(goal, date, corrections)

  defp met?(%Goal{sessions: []} = goal, progress, _sessions),
    do: Counts.meets?(progress, goal.count_policy, :target)

  defp met?(_goal, _progress, sessions), do: Enum.all?(sessions, &(&1.status == :met))
end
