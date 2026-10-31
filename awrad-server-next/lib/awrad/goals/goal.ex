defmodule Awrad.Goals.Goal do
  @moduledoc """
  A goal as a rule evaluates it on one day (`goal` in the schema): one
  version's settings (`Awrad.Goals.Settings`) plus the goal's pauses and
  excused days (`CONTEXT.md`, goal language). A whole goal, with every dated
  version, is an `Awrad.Goals.Timeline`.

  Targets come from `count_policy`, or from each session's own target when the
  goal has sessions. Cumulative and period totals use the target as the total;
  days per period uses it as the daily target.

  Build goals with `new/1`, which rejects invalid ones (`goal_validity`).
  """

  alias Awrad.Goals.ActivePeriod
  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.MakeUp
  alias Awrad.Goals.PausedRange
  alias Awrad.Goals.Rules.Validity
  alias Awrad.Goals.Session
  alias Awrad.Goals.Settings

  @typedoc "A day of the week, by name (never a number)."
  @type weekday :: :monday | :tuesday | :wednesday | :thursday | :friday | :saturday | :sunday

  @typedoc "The account's week start, an input to every week-based rule."
  @type week_start :: :saturday | :sunday | :monday

  @typedoc "A week, a month, or a Hijri month (adjusted by the account's corrections)."
  @type period :: :week | :month | :hijri_month

  @typedoc """
  A `{month, day}` of a yearly range. Gregorian: the schema rules out
  impossible days (30 February), and 29 February falls on the 28th in a
  common year. Hijri: day 30 falls on the 29th in a 29-day month.
  """
  @type month_day :: {1..12, 1..31}

  @typedoc "An inclusive yearly range. When `to` comes before `from`, it runs over the year end."
  @type yearly_range :: {from :: month_day(), to :: month_day()}

  @typedoc """
  Which days the goal is due:

  - `:every_day`;
  - `{:weekdays, days}`;
  - `{:every_n_days, n, anchor}`: an `anchor` of `nil` means the start date;
  - `{:month_days, days}`: a day past the month's end falls on its last day;
  - `{:specific_dates, dates}`;
  - `:one_time`: due every day of the active period;
  - `{:hijri_month_days, days}`: days of every Hijri month, day 30 falling on
    the 29th in a 29-day month;
  - `{:yearly, calendar, ranges}`: Gregorian or Hijri month-day ranges every
    year.

  Hijri schedules read the Hijri date with the account's corrections, and
  are never due outside the Hijri table.
  """
  @type schedule ::
          :every_day
          | {:weekdays, [weekday(), ...]}
          | {:every_n_days, pos_integer(), Date.t() | nil}
          | {:month_days, [1..31, ...]}
          | {:specific_dates, [Date.t(), ...]}
          | :one_time
          | {:hijri_month_days, [1..30, ...]}
          | {:yearly, :gregorian | :hijri, [yearly_range(), ...]}

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
    :excused,
    :count_policy,
    :sessions,
    :requirement,
    :completion,
    :make_up
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          schedule: schedule(),
          active_period: ActivePeriod.t(),
          paused: [PausedRange.t()],
          excused: [Date.t()],
          count_policy: CountPolicy.t(),
          sessions: [Session.t()],
          requirement: requirement(),
          completion: completion(),
          make_up: MakeUp.t()
        }

  @typedoc """
  Why a goal is invalid (fixtures/goal_validity.json, README "Validity"):

  - `:target_required`: no sessions, not a tracker, and no target;
  - `:session_target_required`: a session without a target, not a tracker;
  - `:streak_threshold_value_required`: the streak threshold names a minimum,
    target or maximum that isn't set (goals without sessions);
  - `:streak_pace_not_allowed`: `:daily_pace` on anything but a total with an end;
  - `:end_date_and_duration`: both an end date and a number of days;
  - `:make_up_not_allowed`: a make-up window on a goal that isn't per due
    date, or a total counting at `{:amount, n}` with `fill: :streak`;
  - `:sessions_with_minimum_or_cap`: sessions together with a minimum or cap;
  - `:session_id_mismatch`: a session ID not derived from its kind;
  - `:session_duplicate`: two sessions with one ID;
  - `:session_window_empty`: a `between` window from a time to the same time.
  """
  @type error ::
          :end_date_and_duration
          | :make_up_not_allowed
          | :session_duplicate
          | :session_id_mismatch
          | :session_target_required
          | :session_window_empty
          | :sessions_with_minimum_or_cap
          | :streak_pace_not_allowed
          | :streak_threshold_value_required
          | :target_required

  @typedoc "Every field of `t:t/0`, as a keyword list or map."
  @type attrs :: [{atom(), term()}] | %{optional(atom()) => term()}

  @doc """
  Builds a valid goal from all of its fields, or returns every reason it's
  invalid, sorted alphabetically.

  This is the only way to construct a goal from outside: the rules assume a
  valid one and have no fallback for an invalid one. A missing or unknown
  field raises, like `struct!/2`.
  """
  @spec new(attrs()) :: {:ok, t()} | {:error, [error(), ...]}
  def new(attrs) do
    goal = struct!(__MODULE__, attrs)

    case Validity.goal_errors(goal) do
      [] -> {:ok, goal}
      errors -> {:error, errors}
    end
  end

  @doc "The goal one version's settings describe, with the goal's pauses and excused days."
  @spec from_settings(Settings.t(), [PausedRange.t()], [Date.t()]) :: t()
  def from_settings(%Settings{} = settings, paused, excused) do
    %__MODULE__{
      schedule: settings.schedule,
      active_period: settings.active_period,
      paused: paused,
      excused: excused,
      count_policy: settings.count_policy,
      sessions: settings.sessions,
      requirement: settings.requirement,
      completion: settings.completion,
      make_up: settings.make_up
    }
  end

  @doc "The versioned part of a goal."
  @spec settings(t()) :: Settings.t()
  def settings(%__MODULE__{} = goal) do
    %Settings{
      schedule: goal.schedule,
      active_period: goal.active_period,
      count_policy: goal.count_policy,
      sessions: goal.sessions,
      requirement: goal.requirement,
      completion: goal.completion,
      make_up: goal.make_up
    }
  end
end
