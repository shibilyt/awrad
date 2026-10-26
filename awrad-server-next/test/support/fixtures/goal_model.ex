defmodule Awrad.Fixtures.GoalModel do
  @moduledoc """
  Maps the JSON of `contracts/goal-model/v1/goal-model.schema.json` to the
  `Awrad.Goals` structs, and rule results back to the fixtures' `expect`
  shapes, so a test compares `encode(result) == expect` exactly.
  """

  alias Awrad.Fixtures.HijriCalendar
  alias Awrad.Goals.ActivePeriod
  alias Awrad.Goals.CountEntry
  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.DaysPerPeriodStanding
  alias Awrad.Goals.Goal
  alias Awrad.Goals.PausedRange
  alias Awrad.Goals.Session
  alias Awrad.Goals.SessionStanding
  alias Awrad.Goals.Standing
  alias Awrad.Hijri.Corrections

  @weekdays Map.new(
              ~w(monday tuesday wednesday thursday friday saturday sunday)a,
              &{Atom.to_string(&1), &1}
            )
  @week_starts %{"saturday" => :saturday, "sunday" => :sunday, "monday" => :monday}
  @periods %{"week" => :week, "month" => :month, "hijri_month" => :hijri_month}
  @calendars %{"gregorian" => :gregorian, "hijri" => :hijri}
  @thresholds %{
    "any_count" => :any_count,
    "minimum" => :minimum,
    "target" => :target,
    "maximum" => :maximum
  }
  @completions %{
    "never" => :never,
    "when_target_reached" => :when_target_reached,
    "when_duration_ended" => :when_duration_ended
  }
  @day_resets %{"midnight" => :midnight, "maghrib" => :maghrib}

  # JSON to domain

  @doc """
  A schema `goal` (valid) as a `Goal`, built through `Goal.new/1`. Rule
  fixtures only contain valid goals, so an invalid one raises.
  """
  @spec goal(map()) :: Goal.t()
  def goal(json) do
    case json |> goal_shape() |> Goal.new() do
      {:ok, goal} -> goal
      {:error, errors} -> raise ArgumentError, "invalid fixture goal: #{inspect(errors)}"
    end
  end

  @doc """
  A schema `goal_shape` as `Goal.new/1` attributes, without validating it:
  for `goal_validity.json`, whose goals may be invalid.
  """
  @spec goal_shape(map()) :: Goal.attrs()
  def goal_shape(json) do
    %{
      schedule: schedule(json["schedule"]),
      active_period: active_period(json["active_period"]),
      paused: Enum.map(json["paused"], &paused_range/1),
      count_policy: count_policy(json["count_policy"]),
      sessions: Enum.map(json["sessions"], &session/1),
      requirement: requirement(json["requirement"]),
      completion: Map.fetch!(@completions, json["completion"])
    }
  end

  @spec counts([map()]) :: [CountEntry.t()]
  def counts(json) do
    for entry <- json do
      %CountEntry{date: date(entry["date"]), session: entry["session"], count: entry["count"]}
    end
  end

  @spec date(String.t()) :: Date.t()
  def date(iso), do: Date.from_iso8601!(iso)

  @spec optional_date(String.t() | nil) :: Date.t() | nil
  def optional_date(nil), do: nil
  def optional_date(iso), do: date(iso)

  @doc "An RFC 3339 UTC instant; the schema allows omitting the seconds."
  @spec instant(String.t()) :: DateTime.t()
  def instant(iso) do
    iso = Regex.replace(~r/T(\d{2}:\d{2})Z$/, iso, "T\\1:00Z")
    {:ok, instant, 0} = DateTime.from_iso8601(iso)
    instant
  end

  @spec optional_instant(String.t() | nil) :: DateTime.t() | nil
  def optional_instant(nil), do: nil
  def optional_instant(iso), do: instant(iso)

  @doc """
  A case's optional `hijri_corrections` (absent means none), built through
  `Corrections.new/1`. Rule fixtures only contain valid sets, so an invalid
  one raises.
  """
  @spec hijri_corrections(map()) :: Corrections.t()
  def hijri_corrections(given),
    do: given |> Map.get("hijri_corrections", []) |> HijriCalendar.corrections!()

  @spec week_start(String.t()) :: Goal.week_start()
  def week_start(name), do: Map.fetch!(@week_starts, name)

  @spec day_reset(String.t()) :: :midnight | :maghrib
  def day_reset(name), do: Map.fetch!(@day_resets, name)

  defp schedule(%{"kind" => "every_day"}), do: :every_day
  defp schedule(%{"kind" => "one_time"}), do: :one_time

  defp schedule(%{"kind" => "weekdays", "weekdays" => days}),
    do: {:weekdays, Enum.map(days, &Map.fetch!(@weekdays, &1))}

  defp schedule(%{"kind" => "every_n_days", "every" => every, "anchor_date" => anchor}),
    do: {:every_n_days, every, optional_date(anchor)}

  defp schedule(%{"kind" => "month_days", "days" => days}), do: {:month_days, days}

  defp schedule(%{"kind" => "specific_dates", "dates" => dates}),
    do: {:specific_dates, Enum.map(dates, &date/1)}

  defp schedule(%{"kind" => "hijri_month_days", "days" => days}), do: {:hijri_month_days, days}

  defp schedule(%{"kind" => "yearly", "calendar" => calendar, "ranges" => ranges}),
    do: {:yearly, Map.fetch!(@calendars, calendar), Enum.map(ranges, &yearly_range/1)}

  defp yearly_range(%{"start" => from, "end" => to}), do: {month_day(from), month_day(to)}

  defp month_day(%{"month" => month, "day" => day}), do: {month, day}

  defp active_period(json) do
    %ActivePeriod{
      start_date: date(json["start_date"]),
      end_date: optional_date(json["end_date"]),
      duration_days: json["duration_days"]
    }
  end

  defp paused_range(json),
    do: %PausedRange{from: date(json["from"]), to: optional_date(json["to"])}

  defp count_policy(json) do
    %CountPolicy{
      minimum: json["minimum"],
      target: json["target"],
      maximum: json["maximum"],
      streak_threshold: Map.fetch!(@thresholds, json["streak_threshold"])
    }
  end

  defp session(json),
    do: %Session{id: json["id"], count_policy: count_policy(json["count_policy"])}

  defp requirement(%{"type" => "per_due_date"}), do: :per_due_date
  defp requirement(%{"type" => "cumulative_total"}), do: :cumulative_total
  defp requirement(%{"type" => "tracker"}), do: :tracker

  defp requirement(%{"type" => "period_total", "period" => period}),
    do: {:period_total, Map.fetch!(@periods, period)}

  defp requirement(%{"type" => "days_per_period", "period" => period, "days" => days}),
    do: {:days_per_period, Map.fetch!(@periods, period), days}

  # Domain to the fixtures' expect shapes

  @spec encode(Standing.t() | DaysPerPeriodStanding.t()) :: map()
  def encode(%Standing{} = standing) do
    %{
      "status" => Atom.to_string(standing.status),
      "window" => window(standing.window),
      "progress" => standing.progress,
      "target" => standing.target,
      "sessions" => Enum.map(standing.sessions, &session_standing/1)
    }
  end

  def encode(%DaysPerPeriodStanding{} = standing) do
    %{
      "status" => Atom.to_string(standing.status),
      "window" => window(standing.window),
      "qualifying_days" => standing.qualifying_days,
      "required_days" => standing.required_days
    }
  end

  @doc "A `Goal.new/1` result as the `goal_validity` expect shape."
  @spec encode_validity({:ok, Goal.t()} | {:error, [Goal.error()]}) :: map()
  def encode_validity({:ok, %Goal{}}), do: %{"valid" => true, "errors" => []}

  def encode_validity({:error, errors}),
    do: %{"valid" => false, "errors" => Enum.map(errors, &Atom.to_string/1)}

  defp session_standing(%SessionStanding{} = session) do
    %{
      "id" => session.id,
      "progress" => session.progress,
      "target" => session.target,
      "status" => Atom.to_string(session.status)
    }
  end

  defp window(%Date.Range{first: first, last: last}),
    do: %{"from" => Date.to_iso8601(first), "to" => Date.to_iso8601(last)}
end
