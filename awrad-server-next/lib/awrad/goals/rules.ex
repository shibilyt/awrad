defmodule Awrad.Goals.Rules do
  @moduledoc """
  The goal rules, one function per rule. Each is defined by its fixture file
  in `contracts/goal-model/v1/fixtures/` (README "Goal model v1") and
  implemented once, in its own module under `Awrad.Goals.Rules.*`:

  | Function | Rule (fixture) | Home |
  |---|---|---|
  | `effective_practice_day/4` | `effective_practice_day` | `Rules.EffectiveDay` |
  | `due?/3` | `goal_is_due` | `Rules.Schedule` |
  | `standing/5` | `requirement_standing` | `Rules.Requirement` |
  | `days_per_period/5` | `days_per_period` | `Rules.DaysPerPeriod` |
  | `completed?/3` | `goal_completion` | `Rules.Completion` |
  | `streak/5` | `goal_streak` | `Rules.Streak` |
  | `version_on/2` | `goal_version_on_day` | `Rules.Versions` |
  | `add_version/3` | `goal_version_add` | `Rules.Versions` |
  | `attribute_counts/2` | `count_attribution` | `Rules.Attribution` |
  | `day_statuses/5` | `make_up` | `Rules.DayStatuses` |
  | `excuse/5`, `unexcuse/3` | `excused_days` | `Rules.ExcusedDays` |
  | `consistency/5` | `consistency` | `Rules.Consistency` |
  | `daily_pace/4` | `daily_pace` | `Rules.Pace` |
  | `today_ring/5` | `today_ring` | `Rules.Ring` |
  | `place/4` | `goal_list_placement` | `Rules.Placement` |

  Validity (`goal_validity`) is checked when a goal or timeline is built, by
  `Awrad.Goals.Goal.new/1` and `Awrad.Goals.Timeline.new/1`, so no rule has a
  fallback for an invalid one. `goal_order_merge` is the phones' (they merge
  a conflicting goal order; the server only conflicts).

  Rules that look across days take a `t:goal_input/0`: a whole
  `Awrad.Goals.Timeline`, judged each day by the version in force that day,
  or a single `Awrad.Goals.Goal`, which stands for a timeline with one
  version from its start date that never ended.

  Dates are effective practice days; count entries are already bucketed by
  day (`attribute_counts/2` makes them from the count log). Progress only
  counts entries up to and including the evaluated date. Every `:not_due`
  answer has the evaluated day as its window. Rules that can read Hijri dates
  take the account's `Awrad.Hijri.Corrections` (`Corrections.none()` for
  none); outside the Hijri table, Hijri schedules and periods are never due.
  """

  alias Awrad.Goals.Consistency
  alias Awrad.Goals.CountEntry
  alias Awrad.Goals.CountLogEntry
  alias Awrad.Goals.DailyPace
  alias Awrad.Goals.DaysPerPeriodStanding
  alias Awrad.Goals.DayStatus
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Placement
  alias Awrad.Goals.Ring
  alias Awrad.Goals.Rules
  alias Awrad.Goals.Settings
  alias Awrad.Goals.Standing
  alias Awrad.Goals.Streak
  alias Awrad.Goals.Timeline
  alias Awrad.Goals.Version
  alias Awrad.Hijri.Corrections

  @typedoc "The account's day-end rule."
  @type day_reset :: :midnight | :maghrib

  @typedoc "A whole goal, or a single goal standing for one version that never ended."
  @type goal_input :: Goal.t() | Timeline.t()

  @typedoc "A goal for `attribute_counts/2`: its ID, dhikr, shared or dedicated counts, and its days."
  @type attributed_goal :: %{
          id: String.t(),
          dhikr_id: String.t(),
          counts: :shared | :dedicated,
          goal: goal_input()
        }

  @typedoc "A goal for `place/4`: its ID, its days and its counts."
  @type placed_goal :: %{id: String.t(), goal: goal_input(), counts: [CountEntry.t()]}

  @doc """
  The effective practice day for `instant` in the IANA `time_zone`.

  With a midnight reset, it's the local calendar date. With a Maghrib reset,
  it's the next calendar date from `maghrib` (that local day's Maghrib)
  onwards: the Maghrib instant itself belongs to the new day. Without a known
  Maghrib (`nil`), it falls back to midnight.
  """
  @spec effective_practice_day(DateTime.t(), String.t(), day_reset(), DateTime.t() | nil) ::
          {:ok, Date.t()} | {:error, :time_zone_not_found | :utc_only_time_zone_database}
  def effective_practice_day(instant, time_zone, day_reset, maghrib),
    do: Rules.EffectiveDay.resolve(instant, time_zone, day_reset, maghrib)

  @doc "Whether `goal` is due on `date`: inside its active period, on its schedule, not paused and not excused."
  @spec due?(Goal.t(), Date.t(), Corrections.t()) :: boolean()
  def due?(goal, date, corrections), do: Rules.Schedule.due?(goal, date, corrections)

  @doc """
  Where `goal` stands on `date` against its requirement.

  The window is the day for per-due-date and tracker goals, the active period
  so far for cumulative goals, and the week, month or Hijri month (clipped to
  the active period) for period totals. Outside the active period, on a day
  that isn't due for a per-day goal, or in a period without a due day, the
  status is `:not_due`. A days-per-period goal is evaluated here as a single
  day against its daily target; its period view is `days_per_period/5`.
  """
  @spec standing(Goal.t(), [CountEntry.t()], Date.t(), Goal.week_start(), Corrections.t()) ::
          Standing.t()
  def standing(goal, counts, date, week_start, corrections),
    do: Rules.Requirement.standing(goal, index(counts), date, week_start, corrections)

  @doc """
  A days-per-period goal's standing for the week, month or Hijri month
  containing `date`: qualifying days so far against the required days, less
  the period's excused days and capped by its due days. Only for goals whose
  requirement is `{:days_per_period, _, _}`.
  """
  @spec days_per_period(Goal.t(), [CountEntry.t()], Date.t(), Goal.week_start(), Corrections.t()) ::
          DaysPerPeriodStanding.t()
  def days_per_period(goal, counts, date, week_start, corrections),
    do: Rules.DaysPerPeriod.standing(goal, index(counts), date, week_start, corrections)

  @doc "Whether `goal` is completed on `date`, derived from its completion policy."
  @spec completed?(Goal.t(), [CountEntry.t()], Date.t()) :: boolean()
  def completed?(goal, counts, date), do: Rules.Completion.completed?(goal, index(counts), date)

  @doc """
  The current streak on `date`, its unit, and the days pending make-up. Due
  days (or weeks, months, occasions) that kept the streak add one; today, a
  day pending make-up and the current period or occasion never break it.
  """
  @spec streak(goal_input(), [CountEntry.t()], Date.t(), Goal.week_start(), Corrections.t()) ::
          Streak.t()
  def streak(goal, counts, date, week_start, corrections),
    do: Rules.Streak.evaluate(timeline(goal), index(counts), date, week_start, corrections)

  @doc """
  The version a timeline is judged by on `date` (its index, the latest
  starting on or before it, or the first), and the goal it resolves into:
  that version's settings with the timeline's pauses and excused days, ending
  on `ended.on` once ended if the version would run later.
  """
  @spec version_on(Timeline.t(), Date.t()) :: {non_neg_integer(), Goal.t()}
  def version_on(%Timeline{} = timeline, date),
    do: {Rules.Versions.index(timeline, date), Rules.Versions.resolve(timeline, date)}

  @doc """
  The versions after saving `settings` as a detail edit on `today`: from
  today, replacing a version from today (or removing it when it's back to
  the previous settings), adding nothing when unchanged, and folding the
  oldest version into the next past 100.
  """
  @spec add_version([Version.t(), ...], Date.t(), Settings.t()) :: [Version.t(), ...]
  def add_version(versions, today, settings), do: Rules.Versions.add(versions, today, settings)

  @doc "Each goal's count entries from the count log: per day and session, positive sums only."
  @spec attribute_counts([CountLogEntry.t()], [attributed_goal()]) :: [
          %{id: String.t(), counts: [CountEntry.t()]}
        ]
  def attribute_counts(log, goals), do: Rules.Attribution.attribute(log, goals)

  @doc """
  Each due day's status with make-up, from `from` up to `date` (or the goal's
  last day), oldest first.
  """
  @spec day_statuses(goal_input(), [CountEntry.t()], Date.t(), Date.t(), Corrections.t()) ::
          [DayStatus.t()]
  def day_statuses(goal, counts, from, date, corrections) do
    goal
    |> timeline()
    |> Rules.DayStatuses.statuses(index(counts), date, corrections)
    |> Enum.reject(&Date.before?(&1.date, from))
  end

  @doc """
  Whether `day` can be excused on `date`: the goal still runs, the day is
  past, not excused yet, judged by day, due, not kept, and fewer than 2 days
  of its month are excused already. The error is the first that fails.
  """
  @spec excuse(goal_input(), [CountEntry.t()], Date.t(), Date.t(), Corrections.t()) ::
          :ok | {:error, Rules.ExcusedDays.excuse_error()}
  def excuse(goal, counts, date, day, corrections),
    do: Rules.ExcusedDays.excuse(timeline(goal), index(counts), date, day, corrections)

  @doc "Whether `day` can be un-excused on `date`: the goal still runs and the day is excused."
  @spec unexcuse(goal_input(), Date.t(), Date.t()) ::
          :ok | {:error, :goal_finished | :not_excused}
  def unexcuse(goal, date, day), do: Rules.ExcusedDays.unexcuse(timeline(goal), date, day)

  @doc "The consistency tag on `date`, and whether a row shows the streak, the tag or nothing."
  @spec consistency(goal_input(), [CountEntry.t()], Date.t(), Goal.week_start(), Corrections.t()) ::
          Consistency.t()
  def consistency(goal, counts, date, week_start, corrections),
    do: Rules.Consistency.evaluate(timeline(goal), index(counts), date, week_start, corrections)

  @doc "The daily pace on `date` of a total goal with an end."
  @spec daily_pace(goal_input(), [CountEntry.t()], Date.t(), Corrections.t()) :: DailyPace.t()
  def daily_pace(goal, counts, date, corrections),
    do: Rules.Pace.daily(timeline(goal), index(counts), date, corrections)

  @doc "What the goal's ring fills toward on `date`."
  @spec today_ring(goal_input(), [CountEntry.t()], Date.t(), Goal.week_start(), Corrections.t()) ::
          Ring.t()
  def today_ring(goal, counts, date, week_start, corrections),
    do: Rules.Ring.today(timeline(goal), index(counts), date, week_start, corrections)

  @doc """
  The My Goals sections on `date`, each in order: the account's goal `order`
  (goal IDs), then the goals it doesn't name by creation day and ID.
  """
  @spec place([placed_goal()], [String.t()], Date.t(), Corrections.t()) :: Placement.t()
  def place(goals, order, date, corrections) do
    goals
    |> Enum.map(&%{&1 | counts: index(&1.counts)})
    |> Rules.Placement.place(order, date, corrections)
  end

  defp timeline(goal), do: Rules.Versions.timeline(goal)
  defp index(counts), do: Rules.Counts.index(counts)
end
