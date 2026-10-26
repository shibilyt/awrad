defmodule Awrad.Goals.Goal do
  @moduledoc """
  A goal as the rules see it: schedule, active period, pauses, count policy,
  sessions, requirement and completion policy (`CONTEXT.md`, goal language).

  Targets come from `count_policy`, or from each session's own count policy
  when the goal has sessions. Cumulative and period totals use the target as
  the total; days per period uses it as the daily target.

  Build goals with `new/1`, which rejects invalid ones (`CONTEXT.md`, valid
  goal): every requirement but tracker needs a target, on the goal or on every
  session, and a streak threshold must point at a value that is set.
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

  @typedoc """
  Why a goal is invalid (fixtures/goal_validity.json):

  - `:target_required`: no sessions, not a tracker, and no target;
  - `:session_target_required`: sessions, not a tracker, and a session
    without a target;
  - `:streak_threshold_value_required`: a streak threshold of minimum, target
    or maximum whose value isn't set. Checked on the goal's own count policy
    without sessions, on every session's with them (the goal's own policy is
    unused then).
  """
  @type error :: :session_target_required | :streak_threshold_value_required | :target_required

  @typedoc "Every field of `t:t/0`, as a keyword list or map."
  @type attrs :: [{atom(), term()}] | %{optional(atom()) => term()}

  @doc """
  Builds a valid goal from all of its fields, or returns every reason it's
  invalid, sorted alphabetically.

  This is the only way to construct a goal: the rules assume a valid one and
  have no fallback for an invalid one. A missing or unknown field raises, like
  `struct!/2`.
  """
  @spec new(attrs()) :: {:ok, t()} | {:error, [error(), ...]}
  def new(attrs) do
    goal = struct!(__MODULE__, attrs)

    case errors(goal) do
      [] -> {:ok, goal}
      errors -> {:error, errors}
    end
  end

  defp errors(%__MODULE__{sessions: [], count_policy: policy} = goal) do
    [
      {:target_required, needs_target?(goal) and is_nil(policy.target)},
      {:streak_threshold_value_required, not CountPolicy.streak_threshold_set?(policy)}
    ]
    |> codes()
  end

  defp errors(%__MODULE__{sessions: sessions} = goal) do
    policies = Enum.map(sessions, fn %Session{count_policy: policy} -> policy end)

    [
      {:session_target_required, needs_target?(goal) and Enum.any?(policies, &is_nil(&1.target))},
      {:streak_threshold_value_required,
       not Enum.all?(policies, &CountPolicy.streak_threshold_set?/1)}
    ]
    |> codes()
  end

  defp needs_target?(%__MODULE__{requirement: requirement}), do: requirement != :tracker

  defp codes(checks), do: for({code, true} <- checks, do: code) |> Enum.sort()
end
