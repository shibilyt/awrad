defmodule Awrad.Goals.Rules do
  @moduledoc """
  The goal rules, one function per rule. Each is defined by its fixture file
  in `contracts/goal-model/v1/fixtures/` and implemented once, in its own
  module under `Awrad.Goals.Rules.*`:

  | Function | Rule (fixture) | Home |
  |---|---|---|
  | `effective_practice_day/4` | `effective_practice_day` | `Rules.EffectiveDay` |
  | `due?/2` | `goal_is_due` | `Rules.Schedule` |
  | `standing/4` | `requirement_standing` | `Rules.Requirement` |
  | `days_per_period/4` | `days_per_period` | `Rules.DaysPerPeriod` |
  | `completed?/3` | `goal_completion` | `Rules.Completion` |
  | `streak/4` | `goal_streak` | `Rules.Streak` |

  Dates are effective practice days; count entries are already bucketed by
  day. Progress only counts entries up to and including the evaluated date.
  All calendar arithmetic is Gregorian (`Date`, ISO calendar).
  """

  alias Awrad.Goals.CountEntry
  alias Awrad.Goals.DaysPerPeriodStanding
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Completion
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.DaysPerPeriod
  alias Awrad.Goals.Rules.EffectiveDay
  alias Awrad.Goals.Rules.Requirement
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Goals.Rules.Streak
  alias Awrad.Goals.Standing

  @typedoc "The account's day-end rule."
  @type day_reset :: :midnight | :maghrib

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
    do: EffectiveDay.resolve(instant, time_zone, day_reset, maghrib)

  @doc "Whether `goal` is due on `date`: inside its active period, not paused, and on its schedule."
  @spec due?(Goal.t(), Date.t()) :: boolean()
  def due?(goal, date), do: Schedule.due?(goal, date)

  @doc """
  Where `goal` stands on `date` against its requirement.

  The window is the day for per-due-date and tracker goals, the active period
  so far for cumulative goals, and the week or month (clipped to the active
  period) for period totals. Outside the active period, or on an unscheduled
  day for a per-day goal, the status is `:not_due`. A days-per-period goal is
  evaluated here as a single day against its daily target; its period view is
  `days_per_period/4`.
  """
  @spec standing(Goal.t(), [CountEntry.t()], Date.t(), Goal.week_start()) :: Standing.t()
  def standing(goal, counts, date, week_start),
    do: Requirement.standing(goal, Counts.index(counts), date, week_start)

  @doc """
  A days-per-period goal's standing for the week or month containing `date`:
  qualifying days so far against the required days, capped by the window's
  due days. Only for goals whose requirement is `{:days_per_period, _, _}`.
  """
  @spec days_per_period(Goal.t(), [CountEntry.t()], Date.t(), Goal.week_start()) ::
          DaysPerPeriodStanding.t()
  def days_per_period(goal, counts, date, week_start),
    do: DaysPerPeriod.standing(goal, Counts.index(counts), date, week_start)

  @doc "Whether `goal` is completed on `date`, derived from its completion policy."
  @spec completed?(Goal.t(), [CountEntry.t()], Date.t()) :: boolean()
  def completed?(goal, counts, date), do: Completion.completed?(goal, Counts.index(counts), date)

  @doc """
  The current streak on `date`: consecutive due days (per-due-date,
  cumulative, tracker) meeting the streak threshold, or consecutive weeks or
  months (period total, days per period) meeting the requirement. The
  in-progress day or period never breaks it; it only adds once met.
  """
  @spec streak(Goal.t(), [CountEntry.t()], Date.t(), Goal.week_start()) :: non_neg_integer()
  def streak(goal, counts, date, week_start),
    do: Streak.current(goal, Counts.index(counts), date, week_start)
end
