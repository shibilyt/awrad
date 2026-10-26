defmodule Awrad.Goals.Rules do
  @moduledoc """
  The goal rules, one function per rule. Each is defined by its fixture file
  in `contracts/goal-model/v1/fixtures/` and implemented once, in its own
  module under `Awrad.Goals.Rules.*`:

  | Function | Rule (fixture) | Home |
  |---|---|---|
  | `effective_practice_day/4` | `effective_practice_day` | `Rules.EffectiveDay` |
  | `due?/3` | `goal_is_due` | `Rules.Schedule` |
  | `standing/5` | `requirement_standing` | `Rules.Requirement` |
  | `days_per_period/5` | `days_per_period` | `Rules.DaysPerPeriod` |
  | `completed?/3` | `goal_completion` | `Rules.Completion` |
  | `streak/5` | `goal_streak` | `Rules.Streak` |

  Every rule takes a valid goal. Validity (`goal_validity`) is checked when a
  goal is built, by `Awrad.Goals.Goal.new/1`, so no rule has a fallback for
  an invalid one. Every `:not_due` answer has the evaluated day as its window.

  Dates are effective practice days; count entries are already bucketed by
  day. Progress only counts entries up to and including the evaluated date.
  Dates are Gregorian (`Date`, ISO calendar). Rules that can read Hijri dates
  (Hijri schedules, Hijri-month periods) take the account's
  `Awrad.Hijri.Corrections` (`Corrections.none()` for none); outside the Hijri
  table those schedules and periods are never due.
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
  alias Awrad.Hijri.Corrections

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
  @spec due?(Goal.t(), Date.t(), Corrections.t()) :: boolean()
  def due?(goal, date, corrections), do: Schedule.due?(goal, date, corrections)

  @doc """
  Where `goal` stands on `date` against its requirement.

  The window is the day for per-due-date and tracker goals, the active period
  so far for cumulative goals, and the week, month or Hijri month (clipped to
  the active period) for period totals. Outside the active period, on an
  unscheduled day for a per-day goal, or outside the Hijri table for a
  Hijri-month total, the status is `:not_due`. A days-per-period goal is
  evaluated here as a single day against its daily target; its period view is
  `days_per_period/5`.
  """
  @spec standing(Goal.t(), [CountEntry.t()], Date.t(), Goal.week_start(), Corrections.t()) ::
          Standing.t()
  def standing(goal, counts, date, week_start, corrections),
    do: Requirement.standing(goal, Counts.index(counts), date, week_start, corrections)

  @doc """
  A days-per-period goal's standing for the week, month or Hijri month
  containing `date`: qualifying days so far against the required days, capped
  by the window's due days. Only for goals whose requirement is
  `{:days_per_period, _, _}`.
  """
  @spec days_per_period(
          Goal.t(),
          [CountEntry.t()],
          Date.t(),
          Goal.week_start(),
          Corrections.t()
        ) :: DaysPerPeriodStanding.t()
  def days_per_period(goal, counts, date, week_start, corrections),
    do: DaysPerPeriod.standing(goal, Counts.index(counts), date, week_start, corrections)

  @doc "Whether `goal` is completed on `date`, derived from its completion policy."
  @spec completed?(Goal.t(), [CountEntry.t()], Date.t()) :: boolean()
  def completed?(goal, counts, date), do: Completion.completed?(goal, Counts.index(counts), date)

  @doc """
  The current streak on `date`: consecutive due days (per-due-date,
  cumulative, tracker) meeting the streak threshold, or consecutive weeks,
  months or Hijri months (period total, days per period) meeting the
  requirement. The in-progress day or period never breaks it; it only adds
  once met.
  """
  @spec streak(Goal.t(), [CountEntry.t()], Date.t(), Goal.week_start(), Corrections.t()) ::
          non_neg_integer()
  def streak(goal, counts, date, week_start, corrections),
    do: Streak.current(goal, Counts.index(counts), date, week_start, corrections)
end
