defmodule Awrad.Goals.Goal do
  @moduledoc """
  A goal as the rules see it: schedule, active period, pauses, count policy,
  sessions, requirement and completion policy (`CONTEXT.md`, goal language).

  Targets come from `count_policy`, or from each session's own count policy
  when the goal has sessions. Cumulative and period totals use the target as
  the total; days per period uses it as the daily target.
  """

  alias Awrad.Goals.ActivePeriod
  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.PausedRange
  alias Awrad.Goals.Session

  @typedoc "A day of the week, by name (never a number)."
  @type weekday :: :monday | :tuesday | :wednesday | :thursday | :friday | :saturday | :sunday

  @typedoc "The account's week start, an input to every week-based rule."
  @type week_start :: :saturday | :sunday | :monday

  @type period :: :week | :month

  @typedoc """
  Which days the goal is due (Gregorian):

  - `:every_day`;
  - `{:weekdays, days}`;
  - `{:every_n_days, n, anchor}`: an `anchor` of `nil` means the start date;
  - `{:month_days, days}`: a day past the month's end falls on its last day;
  - `{:specific_dates, dates}`;
  - `:one_time`: due every day of the active period.
  """
  @type schedule ::
          :every_day
          | {:weekdays, [weekday(), ...]}
          | {:every_n_days, pos_integer(), Date.t() | nil}
          | {:month_days, [1..31, ...]}
          | {:specific_dates, [Date.t(), ...]}
          | :one_time

  @type requirement ::
          :per_due_date
          | :cumulative_total
          | :tracker
          | {:period_total, period()}
          | {:days_per_period, period(), 1..31}

  @type completion :: :never | :when_target_reached | :when_duration_ended

  @enforce_keys [
    :schedule,
    :active_period,
    :paused,
    :count_policy,
    :sessions,
    :requirement,
    :completion
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          schedule: schedule(),
          active_period: ActivePeriod.t(),
          paused: [PausedRange.t()],
          count_policy: CountPolicy.t(),
          sessions: [Session.t()],
          requirement: requirement(),
          completion: completion()
        }
end
