defmodule Awrad.Fixtures.GoalModel do
  @moduledoc """
  Maps the JSON of `contracts/goal-model/v1/goal-model.schema.json` to the
  `Awrad.Goals` structs. `Awrad.Fixtures.GoalModel.Encode` maps results back
  to the fixtures' `expect` shapes, so a test compares `encode(result) ==
  expect` exactly.
  """

  alias Awrad.Fixtures.HijriCalendar
  alias Awrad.Goals.ActivePeriod
  alias Awrad.Goals.CountEntry
  alias Awrad.Goals.CountLogEntry
  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.Ended
  alias Awrad.Goals.Goal
  alias Awrad.Goals.MakeUp
  alias Awrad.Goals.PausedRange
  alias Awrad.Goals.Session
  alias Awrad.Goals.Settings
  alias Awrad.Goals.Timeline
  alias Awrad.Goals.Version
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
    "maximum" => :maximum,
    "daily_pace" => :daily_pace
  }
  @completions %{
    "never" => :never,
    "when_target_reached" => :when_target_reached,
    "when_duration_ended" => :when_duration_ended
  }
  @windows %{"off" => :off, "next_day" => :next_day, "within_3_days" => :within_3_days}
  @fills %{"streak" => :streak, "target" => :target}
  @prayers %{
    "fajr" => :fajr,
    "dhuhr" => :dhuhr,
    "asr" => :asr,
    "maghrib" => :maghrib,
    "isha" => :isha
  }
  @end_reasons %{
    "user" => :user,
    "completed" => :completed,
    "date" => :date,
    "structural_edit" => :structural_edit,
    "dhikr_deleted" => :dhikr_deleted
  }
  @counts_modes %{"shared" => :shared, "dedicated" => :dedicated}
  @day_resets %{"midnight" => :midnight, "maghrib" => :maghrib}

  @doc """
  A schema `goal` (valid) as a `Goal`, built through `Goal.new/1`. Rule
  fixtures only contain valid goals, so an invalid one raises.
  """
  @spec goal(map()) :: Goal.t()
  def goal(json), do: json |> goal_shape() |> Goal.new() |> valid!()

  @doc """
  A schema `goal_shape` as `Goal.new/1` attributes, without validating it:
  for `goal_validity.json`, whose goals may be invalid.
  """
  @spec goal_shape(map()) :: Goal.attrs()
  def goal_shape(json) do
    json
    |> settings()
    |> Map.from_struct()
    |> Map.merge(%{paused: paused(json["paused"]), excused: dates(json["excused"])})
  end

  @doc """
  A schema `goal_timeline` or `goal_document` (valid) as a `Timeline`, built
  through `Timeline.new/1`. The document's dhikr, name and counts are left out.
  """
  @spec timeline(map()) :: Timeline.t()
  def timeline(json), do: json |> timeline_shape() |> Timeline.new() |> valid!()

  @doc "A schema `goal_document_shape` as `Timeline.new/1` attributes, without validating it."
  @spec timeline_shape(map()) :: Goal.attrs()
  def timeline_shape(json) do
    %{
      created_on: date(json["created_on"]),
      versions: versions(json["versions"]),
      paused: paused(json["paused"]),
      excused: dates(json["excused"]),
      ended: ended(json["ended"])
    }
  end

  @doc "A schema `goal_input`: a timeline when it has versions, otherwise a single goal."
  @spec goal_input(map()) :: Goal.t() | Timeline.t()
  def goal_input(%{"versions" => _} = json), do: timeline(json)
  def goal_input(json), do: goal(json)

  @spec versions([map()]) :: [Version.t()]
  def versions(json),
    do: Enum.map(json, &%Version{from: date(&1["from"]), settings: settings(&1)})

  @doc "A schema `goal_settings` (or any object holding its members) as `Settings`."
  @spec settings(map()) :: Settings.t()
  def settings(json) do
    %Settings{
      schedule: schedule(json["schedule"]),
      active_period: active_period(json["active_period"]),
      count_policy: count_policy(json["count_policy"]),
      sessions: Enum.map(json["sessions"], &session/1),
      requirement: requirement(json["requirement"]),
      completion: Map.fetch!(@completions, json["completion"]),
      make_up: %MakeUp{
        window: Map.fetch!(@windows, json["make_up"]["window"]),
        fill: Map.fetch!(@fills, json["make_up"]["fill"])
      }
    }
  end

  @spec counts([map()]) :: [CountEntry.t()]
  def counts(json) do
    for entry <- json do
      %CountEntry{date: date(entry["date"]), session: entry["session"], count: entry["count"]}
    end
  end

  @spec count_log([map()]) :: [CountLogEntry.t()]
  def count_log(json) do
    for entry <- json do
      %CountLogEntry{
        id: entry["id"],
        dhikr_id: entry["dhikr_id"],
        practice_day: date(entry["practice_day"]),
        session_id: entry["session_id"],
        goal_id: entry["goal_id"],
        amount: entry["amount"],
        counted_at: instant(entry["counted_at"])
      }
    end
  end

  @spec counts_mode(String.t()) :: :shared | :dedicated
  def counts_mode(name), do: Map.fetch!(@counts_modes, name)

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

  defp valid!({:ok, value}), do: value

  defp valid!({:error, errors}),
    do: raise(ArgumentError, "invalid fixture goal: #{inspect(errors)}")

  defp dates(json), do: Enum.map(json, &date/1)

  defp paused(json),
    do: Enum.map(json, &%PausedRange{from: date(&1["from"]), to: optional_date(&1["to"])})

  defp ended(nil), do: nil

  defp ended(json),
    do: %Ended{on: date(json["on"]), reason: Map.fetch!(@end_reasons, json["reason"])}

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

  defp count_policy(json) do
    %CountPolicy{
      minimum: json["minimum"],
      target: json["target"],
      maximum: json["maximum"],
      streak_threshold: streak_threshold(json["streak_threshold"])
    }
  end

  defp streak_threshold(%{"amount" => amount}), do: {:amount, amount}
  defp streak_threshold(name), do: Map.fetch!(@thresholds, name)

  defp session(json),
    do: %Session{id: json["id"], kind: session_kind(json), target: json["target"]}

  defp session_kind(%{"kind" => "anytime"}), do: :anytime

  defp session_kind(%{"kind" => "before_prayer", "prayer" => prayer}),
    do: {:before_prayer, Map.fetch!(@prayers, prayer)}

  defp session_kind(%{"kind" => "after_prayer", "prayer" => prayer}),
    do: {:after_prayer, Map.fetch!(@prayers, prayer)}

  defp session_kind(%{"kind" => "at_time", "time" => time}), do: {:at_time, time(time)}

  defp session_kind(%{"kind" => "between", "from" => from, "to" => to}),
    do: {:between, time(from), time(to)}

  defp time(hh_mm), do: Time.from_iso8601!(hh_mm <> ":00")

  defp requirement(%{"type" => "per_due_date"}), do: :per_due_date
  defp requirement(%{"type" => "cumulative_total"}), do: :cumulative_total
  defp requirement(%{"type" => "tracker"}), do: :tracker

  defp requirement(%{"type" => "period_total", "period" => period}),
    do: {:period_total, Map.fetch!(@periods, period)}

  defp requirement(%{"type" => "days_per_period", "period" => period, "days" => days}),
    do: {:days_per_period, Map.fetch!(@periods, period), days}
end
