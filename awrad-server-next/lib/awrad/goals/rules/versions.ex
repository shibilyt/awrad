defmodule Awrad.Goals.Rules.Versions do
  @moduledoc false
  # Rules: dated versions (fixtures/goal_version_on_day.json and
  # goal_version_add.json), and resolving a timeline into the goal a rule
  # evaluates on one day (README "Dated versions").

  alias Awrad.Goals.ActivePeriod
  alias Awrad.Goals.Ended
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Settings
  alias Awrad.Goals.Timeline
  alias Awrad.Goals.Version

  @max_versions 100

  @typedoc "What rules that look across days accept."
  @type input :: Goal.t() | Timeline.t()

  @spec timeline(input()) :: Timeline.t()
  def timeline(%Timeline{} = timeline), do: timeline
  def timeline(%Goal{} = goal), do: Timeline.from_goal(goal)

  @doc "The index of the version in force on `date`: the latest starting on or before it, or the first."
  @spec index(Timeline.t(), Date.t()) :: non_neg_integer()
  def index(%Timeline{versions: versions}, date) do
    versions
    |> Enum.with_index()
    |> Enum.reduce(0, fn {%Version{from: from}, i}, found ->
      if Date.after?(from, date), do: found, else: i
    end)
  end

  @doc """
  The goal `timeline` is judged by on `date`: that version's settings with the
  timeline's pauses and excused days. Once ended, a version whose own last
  day is later than `ended.on` (or has none) ends on `ended.on` instead;
  `cap_ended?: false` keeps the version's own end (daily pace, attribution).
  """
  @spec resolve(Timeline.t(), Date.t(), boolean()) :: Goal.t()
  def resolve(%Timeline{} = timeline, date, cap_ended? \\ true) do
    %Version{settings: settings} = Enum.at(timeline.versions, index(timeline, date))
    goal = Goal.from_settings(settings, timeline.paused, timeline.excused)

    if cap_ended?, do: cap(goal, timeline.ended), else: goal
  end

  defp cap(goal, nil), do: goal

  defp cap(%Goal{active_period: period} = goal, %Ended{on: on}) do
    last = Periods.last_day(period)

    if is_nil(last) or Date.after?(last, on),
      do: %{goal | active_period: %ActivePeriod{period | end_date: on, duration_days: nil}},
      else: goal
  end

  @doc """
  Saves `settings` as a detail edit on `today` (fixtures/goal_version_add.json):
  unchanged settings add nothing; an edit on a version starting today (or
  later, from another device) replaces it, and removes it when it's back to
  the previous version's settings; otherwise a version from today is added.
  A 101st version folds the oldest into the next, which takes its `from`.
  """
  @spec add([Version.t(), ...], Date.t(), Settings.t()) :: [Version.t(), ...]
  def add(versions, today, %Settings{} = settings) do
    {earlier, [%Version{} = last]} = Enum.split(versions, -1)

    cond do
      last.settings == settings ->
        versions

      Date.after?(today, last.from) ->
        fold(versions ++ [%Version{from: today, settings: settings}])

      back_to_previous?(earlier, settings) ->
        earlier

      true ->
        earlier ++ [%Version{last | settings: settings}]
    end
  end

  defp back_to_previous?([_ | _] = earlier, settings), do: List.last(earlier).settings == settings
  defp back_to_previous?([], _settings), do: false

  defp fold([%Version{from: from}, %Version{} = next | rest] = versions)
       when length(versions) > @max_versions,
       do: [%Version{next | from: from} | rest]

  defp fold(versions), do: versions
end
