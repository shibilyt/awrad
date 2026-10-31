defmodule Awrad.Goals.Rules.Validity do
  @moduledoc false
  # Rule: which goals and timelines are invalid (fixtures/goal_validity.json).
  # Errors are sorted alphabetically. `Goal.new/1` and `Timeline.new/1` are
  # the only callers: the other rules assume a valid goal.

  alias Awrad.Goals.ActivePeriod
  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.Goal
  alias Awrad.Goals.MakeUp
  alias Awrad.Goals.Session
  alias Awrad.Goals.Timeline
  alias Awrad.Goals.Version

  @spec goal_errors(Goal.t()) :: [Goal.error()]
  def goal_errors(%Goal{} = goal) do
    [
      policy_errors(goal),
      session_errors(goal),
      [
        {:end_date_and_duration, both_ends?(goal.active_period)},
        {:make_up_not_allowed, goal.make_up.window != :off and not make_up_allowed?(goal)},
        {:streak_pace_not_allowed,
         goal.count_policy.streak_threshold == :daily_pace and not total_with_end?(goal)}
      ]
    ]
    |> Enum.concat()
    |> codes()
  end

  @spec timeline_errors(Timeline.t()) :: [Timeline.error()]
  def timeline_errors(%Timeline{versions: [first | _] = versions} = timeline) do
    version_errors =
      Enum.flat_map(versions, fn %Version{settings: settings} ->
        settings |> Goal.from_settings(timeline.paused, timeline.excused) |> goal_errors()
      end)

    froms = Enum.map(versions, & &1.from)

    [
      {:versions_out_of_order, not strictly_increasing?(froms)},
      {:first_version_not_created_on, first.from != timeline.created_on},
      {:structural_change, Enum.any?(versions, &(structure(&1) != structure(first)))}
    ]
    |> codes()
    |> Enum.concat(version_errors)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp policy_errors(%Goal{sessions: [], count_policy: policy} = goal) do
    [
      {:streak_threshold_value_required, CountPolicy.streak_threshold_unset?(policy)},
      {:target_required, not tracker?(goal) and is_nil(policy.target)}
    ]
  end

  defp policy_errors(%Goal{count_policy: policy}),
    do: [{:sessions_with_minimum_or_cap, policy.minimum != nil or policy.maximum != nil}]

  defp session_errors(%Goal{sessions: sessions} = goal) do
    ids = Enum.map(sessions, & &1.id)

    [
      {:session_target_required, not tracker?(goal) and Enum.any?(sessions, &is_nil(&1.target))},
      {:session_id_mismatch, Enum.any?(sessions, &(&1.id != Session.id_for(&1.kind)))},
      {:session_window_empty, Enum.any?(sessions, &empty_window?/1)},
      {:session_duplicate, Enum.uniq(ids) != ids}
    ]
  end

  defp empty_window?(%Session{kind: {:between, from, from}}), do: true
  defp empty_window?(%Session{}), do: false

  defp both_ends?(%ActivePeriod{end_date: end_date, duration_days: days}),
    do: end_date != nil and days != nil

  # Make-up is for daily goals, and for totals whose streak counts at a daily
  # amount, filled to that amount.
  defp make_up_allowed?(%Goal{requirement: :per_due_date}), do: true

  defp make_up_allowed?(%Goal{
         requirement: :cumulative_total,
         count_policy: %CountPolicy{streak_threshold: {:amount, _amount}},
         make_up: %MakeUp{fill: :streak}
       }),
       do: true

  defp make_up_allowed?(%Goal{}), do: false

  defp total_with_end?(%Goal{requirement: :cumulative_total, active_period: period}),
    do: period.end_date != nil or period.duration_days != nil

  defp total_with_end?(%Goal{}), do: false

  defp tracker?(%Goal{requirement: requirement}), do: requirement == :tracker

  defp strictly_increasing?(dates) do
    dates
    |> Enum.zip(Enum.drop(dates, 1))
    |> Enum.all?(fn {earlier, later} -> Date.before?(earlier, later) end)
  end

  # The structural fields every version shares: the schedule kind (and a
  # yearly schedule's calendar), the requirement type (and its period), and
  # the start date.
  defp structure(%Version{settings: settings}) do
    {schedule_kind(settings.schedule), requirement_kind(settings.requirement),
     settings.active_period.start_date}
  end

  defp schedule_kind({:yearly, calendar, _ranges}), do: {:yearly, calendar}
  defp schedule_kind(schedule) when is_atom(schedule), do: schedule
  defp schedule_kind(schedule), do: elem(schedule, 0)

  defp requirement_kind({:days_per_period, period, _days}), do: {:days_per_period, period}
  defp requirement_kind(requirement), do: requirement

  defp codes(checks), do: for({code, true} <- checks, do: code) |> Enum.sort()
end
