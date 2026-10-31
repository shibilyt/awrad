defmodule Awrad.Goals.Rules.Validity do
  @moduledoc false
  # Rule: which goals and timelines are invalid (fixtures/goal_validity.json),
  # and where each problem is: a path into the goal or document, in the
  # schema's member names (`["versions", 1, "sessions", 0, "id"]`), so the
  # change queue can report field errors (sync/v1 README, "Goal rules as
  # field errors"). `Goal.new/1` and `Timeline.new/1` give the codes alone;
  # `Timeline.validate/1` gives the paths.

  alias Awrad.Goals.ActivePeriod
  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.Goal
  alias Awrad.Goals.MakeUp
  alias Awrad.Goals.Session
  alias Awrad.Goals.Timeline
  alias Awrad.Goals.Version

  @type path :: [String.t() | non_neg_integer()]
  @type problem :: {Timeline.error(), path()}

  @spec goal_errors(Goal.t()) :: [Goal.error()]
  def goal_errors(%Goal{} = goal), do: goal |> goal_problems() |> codes()

  @doc "Every problem of a single goal, with its path in the goal."
  @spec goal_problems(Goal.t()) :: [problem()]
  def goal_problems(%Goal{} = goal) do
    policy_problems(goal) ++
      session_problems(goal) ++
      period_problems(goal.active_period) ++
      make_up_problems(goal) ++ pace_problems(goal)
  end

  @doc """
  Every problem of a timeline: each version's (with the timeline's pauses and
  excused days), under `["versions", n]`, then the document's own.
  """
  @spec timeline_problems(Timeline.t()) :: [problem()]
  def timeline_problems(%Timeline{versions: [first | _] = versions} = timeline) do
    indexed = Enum.with_index(versions)

    version_problems =
      for {%Version{settings: settings}, n} <- indexed,
          {code, path} <-
            settings |> Goal.from_settings(timeline.paused, timeline.excused) |> goal_problems(),
          do: {code, ["versions", n | path]}

    out_of_order =
      for {{%Version{from: earlier}, _}, {%Version{from: later}, n}} <-
            Enum.zip(indexed, Enum.drop(indexed, 1)),
          not Date.before?(earlier, later),
          do: {:versions_out_of_order, ["versions", n, "from"]}

    structural =
      for {version, n} <- indexed,
          structure(version) != structure(first),
          do: {:structural_change, ["versions", n]}

    first_day =
      if first.from == timeline.created_on,
        do: [],
        else: [{:first_version_not_created_on, ["versions", 0, "from"]}]

    version_problems ++ out_of_order ++ structural ++ first_day
  end

  defp policy_problems(%Goal{sessions: [], count_policy: policy} = goal) do
    unset =
      if CountPolicy.streak_threshold_unset?(policy),
        do: [{:streak_threshold_value_required, ["count_policy", "streak_threshold"]}],
        else: []

    target =
      if not tracker?(goal) and is_nil(policy.target),
        do: [{:target_required, ["count_policy", "target"]}],
        else: []

    unset ++ target
  end

  # Sessions have no place for a minimum or cap: each one set is a problem.
  defp policy_problems(%Goal{count_policy: policy}) do
    for {member, value} <- [{"minimum", policy.minimum}, {"maximum", policy.maximum}],
        value != nil,
        do: {:sessions_with_minimum_or_cap, ["count_policy", member]}
  end

  defp session_problems(%Goal{sessions: sessions} = goal) do
    indexed = Enum.with_index(sessions)

    per_session =
      for {%Session{} = session, m} <- indexed,
          {code, true, member} <- [
            {:session_target_required, not tracker?(goal) and is_nil(session.target), "target"},
            {:session_id_mismatch, session.id != Session.id_for(session.kind), "id"},
            {:session_window_empty, empty_window?(session), "to"}
          ],
          do: {code, ["sessions", m, member]}

    duplicates =
      for {%Session{id: id}, m} <- indexed,
          Enum.any?(Enum.take(sessions, m), &(&1.id == id)),
          do: {:session_duplicate, ["sessions", m, "id"]}

    per_session ++ duplicates
  end

  defp empty_window?(%Session{kind: {:between, from, from}}), do: true
  defp empty_window?(%Session{}), do: false

  defp period_problems(%ActivePeriod{end_date: end_date, duration_days: days})
       when end_date != nil and days != nil,
       do: [{:end_date_and_duration, ["active_period", "duration_days"]}]

  defp period_problems(%ActivePeriod{}), do: []

  defp make_up_problems(%Goal{make_up: %MakeUp{window: :off}}), do: []

  defp make_up_problems(%Goal{} = goal) do
    if make_up_allowed?(goal), do: [], else: [{:make_up_not_allowed, ["make_up", "window"]}]
  end

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

  defp pace_problems(%Goal{count_policy: %CountPolicy{streak_threshold: :daily_pace}} = goal) do
    if total_with_end?(goal),
      do: [],
      else: [{:streak_pace_not_allowed, ["count_policy", "streak_threshold"]}]
  end

  defp pace_problems(%Goal{}), do: []

  defp total_with_end?(%Goal{requirement: :cumulative_total, active_period: period}),
    do: period.end_date != nil or period.duration_days != nil

  defp total_with_end?(%Goal{}), do: false

  defp tracker?(%Goal{requirement: requirement}), do: requirement == :tracker

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

  defp codes(problems), do: problems |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()
end
